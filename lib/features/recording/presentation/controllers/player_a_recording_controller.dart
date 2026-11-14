import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';

import '../../data/in_memory_player_a_recording_audio.dart';
import '../../data/permission_handler_microphone_gateway.dart';
import '../../domain/microphone_permission_gateway.dart';
import '../../domain/player_a_recording_audio.dart';

enum PlayerARecordingStatus {
  ready,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  recording,
  stopping,
  recorded,
  error,
}

class PlayerARecordingController extends ChangeNotifier {
  PlayerARecordingController({
    required this.audio,
    required this.permissionGateway,
    this.maxDuration = const Duration(seconds: 60),
  }) {
    _playbackSubscription = audio.playbackState.listen(
      _handlePlaybackState,
      onError: (Object error, StackTrace stackTrace) {
        _setError('Playback failed. Try playing the recording again.');
      },
    );
    _positionSubscription = audio.playbackPosition.listen(
      _handlePlaybackPosition,
      onError: (Object error, StackTrace stackTrace) {
        _setError('Could not read the recording playback position.');
      },
    );
    _completionSubscription = audio.playbackComplete.listen(
      (_) => _handlePlaybackComplete(),
      onError: (Object error, StackTrace stackTrace) {
        _setError('Could not detect the end of playback.');
      },
    );
    _recordingInterruptedSubscription = audio.recordingInterrupted.listen((_) {
      if (isRecording) {
        unawaited(stopRecording());
      }
    });
  }

  factory PlayerARecordingController.production() {
    return PlayerARecordingController(
      audio: InMemoryPlayerARecordingAudio(),
      permissionGateway: PermissionHandlerMicrophoneGateway(),
    );
  }

  final PlayerARecordingAudio audio;
  final MicrophonePermissionGateway permissionGateway;
  final Duration maxDuration;

  PlayerARecordingStatus _status = PlayerARecordingStatus.ready;
  PlayerARecordingStatus get status => _status;

  AudioClip? _clip;
  AudioClip? get clip => _clip;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Duration _playbackPosition = Duration.zero;
  Duration get playbackPosition => _playbackPosition;
  Duration get playbackRemaining {
    final clip = _clip;
    if (clip == null) {
      return Duration.zero;
    }
    return clip.duration - _playbackPosition;
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _closed = false;
  Timer? _recordingTimer;
  StreamSubscription<bool>? _playbackSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;
  StreamSubscription<void>? _recordingInterruptedSubscription;

  bool get isRecording => _status == PlayerARecordingStatus.recording;

  Future<void> startRecording() async {
    if (_closed || _isBusy || isRecording) {
      return;
    }

    _isBusy = true;
    _status = PlayerARecordingStatus.requestingPermission;
    _errorMessage = null;
    notifyListeners();

    try {
      final permission = await permissionGateway.request();
      if (_closed) {
        return;
      }
      if (permission == MicrophonePermissionResult.denied) {
        _status = PlayerARecordingStatus.permissionDenied;
        return;
      }
      if (permission == MicrophonePermissionResult.permanentlyDenied) {
        _status = PlayerARecordingStatus.permissionPermanentlyDenied;
        return;
      }

      await audio.stopPlayback();
      _clip = null;
      _elapsed = Duration.zero;
      _playbackPosition = Duration.zero;
      await audio.startRecording();
      if (_closed) {
        await audio.stopRecording();
        return;
      }
      _status = PlayerARecordingStatus.recording;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_closed || !isRecording) {
          return;
        }
        _elapsed += const Duration(seconds: 1);
        if (_elapsed >= maxDuration) {
          _elapsed = maxDuration;
          unawaited(stopRecording());
        } else {
          notifyListeners();
        }
      });
    } catch (error) {
      _setError(_recordingErrorMessage(error));
    } finally {
      _isBusy = false;
      if (!_closed) {
        notifyListeners();
      }
    }
  }

  Future<void> stopRecording() async {
    if (_closed || !isRecording || _isBusy) {
      return;
    }

    _isBusy = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _status = PlayerARecordingStatus.stopping;
    notifyListeners();

    try {
      final clip = await audio.stopRecording();
      if (clip.duration > maxDuration) {
        throw StateError('The recording exceeded its maximum duration.');
      }
      if (clip.data.length <= 44 || clip.duration <= Duration.zero) {
        throw StateError('No usable audio was captured.');
      }
      _clip = clip;
      _elapsed = clip.duration;
      _status = PlayerARecordingStatus.recorded;
      _errorMessage = null;
    } catch (error) {
      _clip = null;
      _setError(_recordingErrorMessage(error));
    } finally {
      _isBusy = false;
      if (!_closed) {
        notifyListeners();
      }
    }
  }

  Future<void> togglePlayback() async {
    if (_closed || _clip == null || _isBusy || isRecording) {
      return;
    }

    try {
      if (_isPlaying) {
        await audio.pausePlayback();
      } else if (_playbackPosition > Duration.zero &&
          _playbackPosition < _clip!.duration) {
        await audio.resumePlayback();
      } else {
        _errorMessage = null;
        _playbackPosition = Duration.zero;
        await audio.play(_clip!);
      }
    } catch (error) {
      _isPlaying = false;
      _setError('Playback failed: $error');
    }
  }

  Future<void> discardRecording() async {
    if (_closed || _isBusy || _clip == null) {
      return;
    }

    _isBusy = true;
    try {
      await audio.stopPlayback();
      _clip = null;
      _elapsed = Duration.zero;
      _playbackPosition = Duration.zero;
      _isPlaying = false;
      _errorMessage = null;
      _status = PlayerARecordingStatus.ready;
    } catch (error) {
      _setError('Could not stop playback: $error');
    } finally {
      _isBusy = false;
      if (!_closed) {
        notifyListeners();
      }
    }
  }

  Future<bool> openPermissionSettings() async {
    try {
      return await permissionGateway.openAppSettings();
    } catch (error) {
      _setError('Could not open app settings: $error');
      return false;
    }
  }

  Future<void> stopPlayback() async {
    await audio.stopPlayback();
    _playbackPosition = Duration.zero;
    _isPlaying = false;
    if (!_closed) {
      notifyListeners();
    }
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

  void _handlePlaybackState(bool isPlaying) {
    if (_closed) {
      return;
    }
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void _handlePlaybackPosition(Duration position) {
    if (_closed) {
      return;
    }
    final duration = _clip?.duration ?? Duration.zero;
    _playbackPosition = Duration(
      microseconds: position.inMicroseconds
          .clamp(0, duration.inMicroseconds)
          .toInt(),
    );
    notifyListeners();
  }

  void _handlePlaybackComplete() {
    if (_closed) {
      return;
    }
    _playbackPosition = _clip?.duration ?? Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  void _setError(String message) {
    if (_closed) {
      return;
    }
    _status = PlayerARecordingStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  String _recordingErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('no audio') || text.contains('too short')) {
      return 'No usable audio was captured. Record again and try speaking.';
    }
    if (text.contains('interrupted')) {
      return 'Recording was interrupted. Try recording again.';
    }
    return 'Recording failed: $error';
  }
}
