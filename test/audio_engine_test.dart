import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/audio/domain/audio_engine.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/audio/domain/pcm16_audio_meter.dart';
import 'package:reverse_vibe/features/audio/domain/wav_audio_reverser.dart';

void main() {
  test('AudioClip keeps temporary bytes isolated and exposes metadata', () {
    final source = Uint8List.fromList([1, 2, 3]);
    final clip = _createClip(data: source);
    source[0] = 9;

    expect(clip.data, [1, 2, 3]);
    expect(clip.duration, const Duration(seconds: 2));
    expect(clip.mimeType, 'audio/pcm');
    expect(clip.sampleRate, 48000);
    expect(clip.channelCount, 1);

    final exposedData = clip.data;
    exposedData[0] = 8;
    expect(clip.data, [1, 2, 3]);
  });

  test('AudioClip rejects empty bytes and invalid metadata', () {
    expect(() => _createClip(data: Uint8List(0)), throwsArgumentError);
    expect(() => _createClip(duration: Duration.zero), throwsArgumentError);
    expect(() => _createClip(mimeType: ' '), throwsArgumentError);
    expect(() => _createClip(sampleRate: 0), throwsArgumentError);
    expect(() => _createClip(channelCount: 0), throwsArgumentError);
  });

  test('WAV reversal reverses whole frames and preserves the source clip', () {
    final original = _wavClip(
      sampleRate: 8000,
      channelCount: 2,
      pcm: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
    );
    final originalBytes = original.data;

    final reversed = WavAudioReverser.reverse(original);

    expect(reversed.data.sublist(44), [9, 10, 11, 12, 5, 6, 7, 8, 1, 2, 3, 4]);
    expect(reversed.data.sublist(0, 44), originalBytes.sublist(0, 44));
    expect(original.data, originalBytes);
    expect(reversed.duration, original.duration);
    expect(reversed.duration, const Duration(microseconds: 375));
    expect(reversed.sampleRate, 8000);
    expect(reversed.channelCount, 2);
    expect(reversed.mimeType, 'audio/wav');
  });

  test(
    'WAV reversal rejects unsupported formats and inconsistent metadata',
    () {
      final clip = _wavClip(
        sampleRate: 8000,
        channelCount: 1,
        pcm: Uint8List.fromList([1, 2, 3, 4]),
      );
      final mismatched = AudioClip(
        data: clip.data,
        duration: clip.duration,
        mimeType: clip.mimeType,
        sampleRate: 16000,
        channelCount: 1,
      );

      expect(() => WavAudioReverser.reverse(mismatched), throwsFormatException);
      expect(
        () => WavAudioReverser.reverse(_createClip()),
        throwsFormatException,
      );
    },
  );

  test('PCM meter distinguishes silence, soft audio, and loud audio', () {
    Uint8List pcmFor(List<int> samples) {
      final bytes = Uint8List(samples.length * 2);
      final data = ByteData.sublistView(bytes);
      for (var index = 0; index < samples.length; index++) {
        data.setInt16(index * 2, samples[index], Endian.little);
      }
      return bytes;
    }

    expect(Pcm16AudioMeter.normalizedRms(pcmFor([0, 0])), 0);
    final soft = Pcm16AudioMeter.normalizedRms(pcmFor([1000, -1000]));
    final loud = Pcm16AudioMeter.normalizedRms(pcmFor([20000, -20000]));
    expect(soft, greaterThan(0));
    expect(loud, greaterThan(soft));
    expect(
      Pcm16AudioMeter.normalizedRms(pcmFor([32767, -32768])),
      closeTo(1, 0.0001),
    );
  });

  test('PCM waveform bins reflect actual sample intensity', () {
    final pcm = Uint8List(8);
    final samples = ByteData.sublistView(pcm);
    samples.setInt16(0, 0, Endian.little);
    samples.setInt16(2, 0, Endian.little);
    samples.setInt16(4, 12000, Endian.little);
    samples.setInt16(6, -12000, Endian.little);

    final waveform = Pcm16AudioMeter.waveform(pcm, binCount: 2);

    expect(waveform[0], 0);
    expect(waveform[1], greaterThan(waveform[0]));
    expect(Pcm16AudioMeter.waveform(Uint8List(0), binCount: 2), [0, 0]);
    expect(
      () => Pcm16AudioMeter.waveform(pcm, binCount: 0),
      throwsArgumentError,
    );
  });

  test('AudioEngine contract supports temporary clips and cleanup', () async {
    final original = _createClip(data: Uint8List.fromList([1, 2]));
    final reversedOriginal = _createClip(data: Uint8List.fromList([2, 1]));
    final imitation = _createClip(data: Uint8List.fromList([3, 4]));
    final reversedImitation = _createClip(data: Uint8List.fromList([4, 3]));
    final engine = _ContractTestAudioEngine(
      recordings: [original, imitation],
      reversals: [reversedOriginal, reversedImitation],
    );

    expect(engine, isA<AudioEngine>());
    expect(
      await engine.record(maxDuration: const Duration(seconds: 10)),
      same(original),
    );
    expect(await engine.reverse(original), same(reversedOriginal));
    await engine.play(reversedOriginal);

    expect(
      await engine.record(maxDuration: const Duration(seconds: 10)),
      same(imitation),
    );
    expect(await engine.reverse(imitation), same(reversedImitation));
    await engine.play(reversedImitation);
    await engine.play(original);
    await engine.stopPlayback();
    await engine.clearTemporaryAudio();
    await engine.dispose();

    expect(engine.playedClips, [reversedOriginal, reversedImitation, original]);
    expect(engine.playbackStopped, isTrue);
    expect(engine.temporaryAudioCleared, isTrue);
    expect(engine.disposed, isTrue);
  });
}

AudioClip _wavClip({
  required int sampleRate,
  required int channelCount,
  required Uint8List pcm,
}) {
  final blockAlign = channelCount * 2;
  final frameCount = pcm.length ~/ blockAlign;
  final duration = Duration(
    microseconds: frameCount * Duration.microsecondsPerSecond ~/ sampleRate,
  );
  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, wav.length - 8, Endian.little);
  wav.setRange(8, 12, ascii.encode('WAVE'));
  wav.setRange(12, 16, ascii.encode('fmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channelCount, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * blockAlign, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);
  return AudioClip(
    data: wav,
    duration: duration,
    mimeType: 'audio/wav',
    sampleRate: sampleRate,
    channelCount: channelCount,
  );
}

AudioClip _createClip({
  Uint8List? data,
  Duration duration = const Duration(seconds: 2),
  String mimeType = 'audio/pcm',
  int sampleRate = 48000,
  int channelCount = 1,
}) {
  return AudioClip(
    data: data ?? Uint8List.fromList([1, 2, 3]),
    duration: duration,
    mimeType: mimeType,
    sampleRate: sampleRate,
    channelCount: channelCount,
  );
}

class _ContractTestAudioEngine implements AudioEngine {
  _ContractTestAudioEngine({required this.recordings, required this.reversals});

  final List<AudioClip> recordings;
  final List<AudioClip> reversals;
  final List<AudioClip> playedClips = [];
  int _recordingIndex = 0;
  int _reversalIndex = 0;
  bool playbackStopped = false;
  bool temporaryAudioCleared = false;
  bool disposed = false;

  @override
  Future<AudioClip> record({required Duration maxDuration}) async {
    return recordings[_recordingIndex++];
  }

  @override
  Future<AudioClip> reverse(AudioClip clip) async {
    return reversals[_reversalIndex++];
  }

  @override
  Future<void> play(AudioClip clip) async {
    playedClips.add(clip);
  }

  @override
  Future<void> stopPlayback() async {
    playbackStopped = true;
  }

  @override
  Future<void> clearTemporaryAudio() async {
    temporaryAudioCleared = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
