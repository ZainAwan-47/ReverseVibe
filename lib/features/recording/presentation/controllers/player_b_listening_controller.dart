import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/audio/domain/wav_audio_reverser.dart';

import '../../data/in_memory_player_a_recording_audio.dart';
import '../../data/permission_handler_microphone_gateway.dart';
import '../../domain/microphone_permission_gateway.dart';
import '../../domain/player_a_recording_audio.dart';

enum PlayerBStatus {
  preparing,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  recording,
  stopping,
  recorded,
}

class PlayerBListeningController extends ChangeNotifier {
  PlayerBListeningController({
    required this.originalClip,
    required this.audio,
    required this.permissionGateway,
    this.maxDuration = const Duration(seconds: 60),
  }) {
    _playbackSubscription = audio.playbackState.listen(
      _handlePlaybackState,
      onError: (Object error, StackTrace stackTrace) {
        _errorMessage = 'Playback failed. Try playing the recording again.';
        _notify();
      },
    );
    _positionSubscription = audio.playbackPosition.listen(
      _handlePlaybackPosition,
      onError: (Object error, StackTrace stackTrace) {
        _errorMessage = 'Could not read the playback position.';
        _notify();
      },
    );
    _completionSubscription = audio.playbackComplete.listen(
      (_) => _handlePlaybackComplete(),
      onError: (Object error, StackTrace stackTrace) {
        _errorMessage = 'Could not detect the end of playback.';
        _notify();
      },
    );
    _amplitudeSubscription = audio.recordingAmplitude.listen(
      _handleAmplitude,
      onError: (Object error, StackTrace stackTrace) {
        _errorMessage = 'Live microphone levels are unavailable.';
        _notify();
      },
    );
    _recordingInterruptedSubscription = audio.recordingInterrupted.listen((_) {
      if (isRecording) {
        unawaited(stopRecording());
      }
    });
  }

  factory PlayerBListeningController.production(AudioClip originalClip) {
    return PlayerBListeningController(
      originalClip: originalClip,
      audio: InMemoryPlayerARecordingAudio(),
      permissionGateway: PermissionHandlerMicrophoneGateway(),
    );
  }

  final AudioClip originalClip;
  final PlayerARecordingAudio audio;
  final MicrophonePermissionGateway permissionGateway;
  final Duration maxDuration;

  PlayerBStatus _status = PlayerBStatus.preparing;
  PlayerBStatus get status => _status;

  AudioClip? _reversedClip;
  AudioClip? get reversedClip => _reversedClip;

  AudioClip? _imitation;
  AudioClip? get imitation => _imitation;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _closed = false;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  double _latestAmplitude = 0;
  double _amplitude = 0;
  double get amplitude => _amplitude;
  final List<double> _amplitudeHistory = [];
  List<double> get amplitudeHistory => List.unmodifiable(_amplitudeHistory);

  AudioClip? _activeClip;
  Duration _playbackPosition = Duration.zero;
  Duration get playbackPosition => _playbackPosition;

  Duration playbackPositionFor(AudioClip clip) =>
      identical(_activeClip, clip) ? _playbackPosition : Duration.zero;

  Duration playbackRemainingFor(AudioClip clip) {
    final position = playbackPositionFor(clip);
    return Duration(
      microseconds: (clip.duration.inMicroseconds - position.inMicroseconds)
          .clamp(0, clip.duration.inMicroseconds)
          .toInt(),
    );
  }

  bool isClipPlaying(AudioClip clip) =>
      _isPlaying && identical(_activeClip, clip);

  double playbackProgressFor(AudioClip clip) {
    if (!identical(_activeClip, clip) || clip.duration == Duration.zero) {
      return 0;
    }
    return (_playbackPosition.inMicroseconds / clip.duration.inMicroseconds)
        .clamp(0, 1)
        .toDouble();
  }

  Timer? _recordingTimer;
  Stopwatch? _recordingStopwatch;
  StreamSubscription<bool>? _playbackSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;
  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<void>? _recordingInterruptedSubscription;

  bool get isRecording => _status == PlayerBStatus.recording;

  Future<void> prepare() async {
    if (_closed || _reversedClip != null) {
      return;
    }
    _status = PlayerBStatus.preparing;
    _errorMessage = null;
    _notify();
    try {
      _reversedClip = WavAudioReverser.reverse(originalClip);
      _status = PlayerBStatus.ready;
    } catch (error) {
      _status = PlayerBStatus.ready;
      _errorMessage = 'Could not prepare the reversed recording: $error';
    }
    _notify();
  }

  Future<void> startRecording() async {
    if (_closed || _isBusy || isRecording || _reversedClip == null) {
      return;
    }
    _isBusy = true;
    _status = PlayerBStatus.ready;
    _errorMessage = null;
    _notify();

    try {
      final permission = await permissionGateway.request();
      if (_closed) {
        return;
      }
      if (permission == MicrophonePermissionResult.denied) {
        _status = PlayerBStatus.permissionDenied;
        return;
      }
      if (permission == MicrophonePermissionResult.permanentlyDenied) {
        _status = PlayerBStatus.permissionPermanentlyDenied;
        return;
      }

      await stopPlayback();
      await audio.startRecording();
      if (_closed) {
        await audio.stopRecording();
        return;
      }
      _imitation = null;
      _elapsed = Duration.zero;
      _amplitude = 0;
      _latestAmplitude = 0;
      _amplitudeHistory.clear();
      _recordingStopwatch = Stopwatch()..start();
      _status = PlayerBStatus.recording;
      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _updateRecording(),
      );
    } catch (error) {
      _status = PlayerBStatus.ready;
      _errorMessage = _recordingErrorMessage(error);
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> stopRecording() async {
    if (_closed || !isRecording || _isBusy) {
      return;
    }
    _isBusy = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch?.stop();
    _elapsed = _recordingStopwatch?.elapsed ?? _elapsed;
    _status = PlayerBStatus.stopping;
    _notify();

    try {
      final clip = await audio.stopRecording();
      if (clip.duration > maxDuration) {
        throw StateError('The recording exceeded its maximum duration.');
      }
      if (clip.data.length <= 44 || clip.duration <= Duration.zero) {
        throw StateError('No usable audio was captured.');
      }
      _imitation = clip;
      _elapsed = clip.duration;
      _status = PlayerBStatus.recorded;
      _errorMessage = null;
    } catch (error) {
      _imitation = null;
      _status = PlayerBStatus.ready;
      _errorMessage = _recordingErrorMessage(error);
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> togglePlayback(AudioClip clip) async {
    if (_closed || _isBusy || isRecording) {
      return;
    }
    try {
      if (_isPlaying && identical(_activeClip, clip)) {
        await audio.pausePlayback();
      } else if (identical(_activeClip, clip) &&
          _playbackPosition > Duration.zero &&
          _playbackPosition < clip.duration) {
        await audio.resumePlayback();
      } else {
        _activeClip = clip;
        _playbackPosition = Duration.zero;
        _errorMessage = null;
        _notify();
        await audio.play(clip);
      }
    } catch (error) {
      _isPlaying = false;
      _errorMessage = 'Playback failed: $error';
      _notify();
    }
  }

  Future<void> discardRecording() async {
    if (_closed || _isBusy || _imitation == null) {
      return;
    }
    _isBusy = true;
    try {
      await stopPlayback();
      _imitation = null;
      _elapsed = Duration.zero;
      _amplitude = 0;
      _latestAmplitude = 0;
      _amplitudeHistory.clear();
      _status = PlayerBStatus.ready;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Could not discard the recording: $error';
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> recordAnotherTake() async {
    if (_imitation != null) {
      await discardRecording();
    }
    await startRecording();
  }

  Future<bool> openPermissionSettings() async {
    try {
      return await permissionGateway.openAppSettings();
    } catch (error) {
      _errorMessage = 'Could not open app settings: $error';
      _notify();
      return false;
    }
  }

  Future<void> stopPlayback() async {
    await audio.stopPlayback();
    _activeClip = null;
    _playbackPosition = Duration.zero;
    _isPlaying = false;
    _notify();
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _playbackSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _completionSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    await _recordingInterruptedSubscription?.cancel();
    try {
      await audio.stopPlayback();
    } finally {
      try {
        await audio.dispose();
      } finally {
        super.dispose();
      }
    }
  }

  void _updateRecording() {
    if (_closed || !isRecording) {
      return;
    }
    _elapsed = _recordingStopwatch?.elapsed ?? Duration.zero;
    if (_elapsed >= maxDuration) {
      _elapsed = maxDuration;
      _notify();
      unawaited(stopRecording());
      return;
    }
    _amplitude = (_amplitude * 0.55 + _latestAmplitude * 0.45)
        .clamp(0, 1)
        .toDouble();
    _amplitudeHistory.add(_amplitude);
    if (_amplitudeHistory.length > 36) {
      _amplitudeHistory.removeAt(0);
    }
    _notify();
  }

  void _handleAmplitude(double amplitude) {
    if (_closed) {
      return;
    }
    _latestAmplitude = amplitude.clamp(0, 1).toDouble();
  }

  void _handlePlaybackState(bool isPlaying) {
    if (_closed) {
      return;
    }
    _isPlaying = isPlaying;
    _notify();
  }

  void _handlePlaybackPosition(Duration position) {
    if (_closed) {
      return;
    }
    final duration = _activeClip?.duration ?? Duration.zero;
    _playbackPosition = Duration(
      microseconds: position.inMicroseconds
          .clamp(0, duration.inMicroseconds)
          .toInt(),
    );
    _notify();
  }

  void _handlePlaybackComplete() {
    if (_closed) {
      return;
    }
    _playbackPosition = _activeClip?.duration ?? Duration.zero;
    _isPlaying = false;
    _notify();
  }

  String _recordingErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('no audio') || text.contains('too short')) {
      return 'No usable audio was captured. Record again and try speaking.';
    }
    if (text.contains('interrupted')) {
      return 'Recording was interrupted. Try recording your imitation again.';
    }
    return 'Recording failed: $error';
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }
}
