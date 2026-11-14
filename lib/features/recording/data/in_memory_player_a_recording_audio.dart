import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/audio/domain/pcm16_audio_meter.dart';

import '../domain/player_a_recording_audio.dart';

class InMemoryPlayerARecordingAudio implements PlayerARecordingAudio {
  InMemoryPlayerARecordingAudio({AudioRecorder? recorder, AudioPlayer? player})
    : _recorder = recorder ?? AudioRecorder(),
      _player = player ?? AudioPlayer(),
      _recordingAmplitudeController = StreamController<double>.broadcast(
        sync: true,
      ),
      _recordingInterruptedController = StreamController<void>.broadcast(
        sync: true,
      );

  static const _sampleRate = 44100;
  static const _channelCount = 1;
  static const _bitsPerSample = 16;
  static const _bytesPerSample = _bitsPerSample ~/ 8;

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  final StreamController<double> _recordingAmplitudeController;
  final StreamController<void> _recordingInterruptedController;
  BytesBuilder? _pcmBuffer;
  StreamSubscription<Uint8List>? _recordingSubscription;
  Completer<void>? _streamClosed;
  Object? _streamError;
  bool _stoppingRecording = false;
  bool _disposed = false;

  @override
  Stream<bool> get playbackState =>
      _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  @override
  Stream<Duration> get playbackPosition => _player.onPositionChanged;

  @override
  Stream<void> get playbackComplete => _player.onPlayerComplete;

  @override
  Stream<double> get recordingAmplitude => _recordingAmplitudeController.stream;

  @override
  Stream<void> get recordingInterrupted =>
      _recordingInterruptedController.stream;

  @override
  Future<void> startRecording() async {
    _ensureNotDisposed();
    if (_recordingSubscription != null) {
      throw StateError('A recording is already in progress.');
    }

    await stopPlayback();
    final buffer = BytesBuilder(copy: false);
    final streamClosed = Completer<void>();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channelCount,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _pcmBuffer = buffer;
    _streamClosed = streamClosed;
    _streamError = null;
    _recordingSubscription = stream.listen(
      (chunk) {
        buffer.add(chunk);
        if (!_recordingAmplitudeController.isClosed) {
          _recordingAmplitudeController.add(
            Pcm16AudioMeter.normalizedRms(chunk),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _streamError = error;
        _signalRecordingInterruption();
        if (!streamClosed.isCompleted) {
          streamClosed.complete();
        }
      },
      onDone: () {
        if (!_stoppingRecording) {
          _streamError ??= StateError('Audio capture was interrupted.');
          _signalRecordingInterruption();
        }
        if (!streamClosed.isCompleted) {
          streamClosed.complete();
        }
      },
      cancelOnError: false,
    );
  }

  @override
  Future<AudioClip> stopRecording() async {
    _ensureNotDisposed();
    final buffer = _pcmBuffer;
    final streamClosed = _streamClosed;
    if (buffer == null || streamClosed == null) {
      throw StateError('There is no active recording.');
    }

    try {
      _stoppingRecording = true;
      await _recorder.stop();
      await streamClosed.future.timeout(const Duration(seconds: 3));
      if (_streamError case final error?) {
        throw StateError('Audio capture failed: $error');
      }

      final pcmBytes = buffer.takeBytes();
      final alignedLength = pcmBytes.length - (pcmBytes.length % 2);
      if (alignedLength == 0) {
        throw StateError('No audio was captured.');
      }
      final alignedPcm = Uint8List.sublistView(pcmBytes, 0, alignedLength);
      final duration = Duration(
        microseconds:
            alignedPcm.length *
            Duration.microsecondsPerSecond ~/
            (_sampleRate * _channelCount * _bytesPerSample),
      );
      if (duration <= Duration.zero) {
        throw StateError('The recording is too short to use.');
      }

      return AudioClip(
        data: _encodeWav(alignedPcm),
        duration: duration,
        mimeType: 'audio/wav',
        sampleRate: _sampleRate,
        channelCount: _channelCount,
      );
    } finally {
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      _pcmBuffer = null;
      _streamClosed = null;
      _streamError = null;
      _stoppingRecording = false;
    }
  }

  @override
  Future<void> play(AudioClip clip) async {
    _ensureNotDisposed();
    if (_recordingSubscription != null) {
      throw StateError('Stop recording before playback.');
    }

    await stopPlayback();
    await _player.play(BytesSource(clip.data, mimeType: clip.mimeType));
  }

  @override
  Future<void> pausePlayback() async {
    _ensureNotDisposed();
    await _player.pause();
  }

  @override
  Future<void> resumePlayback() async {
    _ensureNotDisposed();
    await _player.resume();
  }

  @override
  Future<void> stopPlayback() async {
    _ensureNotDisposed();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    try {
      if (_recordingSubscription != null) {
        _stoppingRecording = true;
        await _recorder.stop();
        await _streamClosed?.future.timeout(const Duration(seconds: 3));
      }
    } finally {
      _disposed = true;
      try {
        await _player.dispose();
      } finally {
        await _recordingSubscription?.cancel();
        await _recorder.dispose();
        await _recordingAmplitudeController.close();
        await _recordingInterruptedController.close();
        _pcmBuffer = null;
        _recordingSubscription = null;
        _streamClosed = null;
      }
    }
  }

  Uint8List _encodeWav(Uint8List pcm) {
    final wav = Uint8List(44 + pcm.length);
    final header = ByteData.sublistView(wav);
    wav.setRange(0, 4, ascii.encode('RIFF'));
    header.setUint32(4, 36 + pcm.length, Endian.little);
    wav.setRange(8, 12, ascii.encode('WAVE'));
    wav.setRange(12, 16, ascii.encode('fmt '));
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, _channelCount, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(
      28,
      _sampleRate * _channelCount * _bytesPerSample,
      Endian.little,
    );
    header.setUint16(32, _channelCount * _bytesPerSample, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    wav.setRange(36, 40, ascii.encode('data'));
    header.setUint32(40, pcm.length, Endian.little);
    wav.setRange(44, wav.length, pcm);
    return wav;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('The audio service has already been disposed.');
    }
  }

  void _signalRecordingInterruption() {
    if (!_stoppingRecording && !_recordingInterruptedController.isClosed) {
      _recordingInterruptedController.add(null);
    }
  }
}
