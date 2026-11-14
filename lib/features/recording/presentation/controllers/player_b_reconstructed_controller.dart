import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/audio/domain/wav_audio_reverser.dart';
import 'package:reverse_vibe/features/recording/domain/player_a_recording_audio.dart';

import '../../data/in_memory_player_a_recording_audio.dart';
import '../../domain/player_b_imitation_result.dart';

class PlayerBReconstructedController extends ChangeNotifier {
  PlayerBReconstructedController({required this.result, required this.audio}) {
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
  }

  factory PlayerBReconstructedController.production(
    PlayerBImitationResult result,
  ) {
    return PlayerBReconstructedController(
      result: result,
      audio: InMemoryPlayerARecordingAudio(),
    );
  }

  final PlayerBImitationResult result;
  final PlayerARecordingAudio audio;

  AudioClip? _reconstructedClip;
  AudioClip? get reconstructedClip => _reconstructedClip;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isPreparing = true;
  bool get isPreparing => _isPreparing;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _hasListenedToReconstructed = false;
  bool get hasListenedToReconstructed => _hasListenedToReconstructed;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _closed = false;
  AudioClip? _activeClip;
  Duration _playbackPosition = Duration.zero;
  Duration get playbackPosition => _playbackPosition;

  StreamSubscription<bool>? _playbackSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;

  bool isClipPlaying(AudioClip clip) =>
      _isPlaying && identical(_activeClip, clip);

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

  double playbackProgressFor(AudioClip clip) {
    if (!identical(_activeClip, clip) || clip.duration <= Duration.zero) {
      return 0;
    }
    return (_playbackPosition.inMicroseconds / clip.duration.inMicroseconds)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> prepare() async {
    if (_closed || !_isPreparing) {
      return;
    }
    try {
      _reconstructedClip = WavAudioReverser.reverse(result.imitationClip);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Could not reverse the confirmed imitation: $error';
    } finally {
      _isPreparing = false;
      _notify();
    }
  }

  Future<void> togglePlayback(AudioClip clip) async {
    if (_closed || _isBusy || _isPreparing || _reconstructedClip == null) {
      return;
    }
    final sameClip = identical(_activeClip, clip);
    try {
      if (_isPlaying && sameClip) {
        await audio.pausePlayback();
      } else if (sameClip &&
          _playbackPosition > Duration.zero &&
          _playbackPosition < clip.duration) {
        await audio.resumePlayback();
      } else {
        _isBusy = true;
        if (_isPlaying && !sameClip) {
          await audio.stopPlayback();
        }
        _activeClip = clip;
        _playbackPosition = Duration.zero;
        _errorMessage = null;
        _notify();
        await audio.play(clip);
      }
    } catch (error) {
      _isPlaying = false;
      _errorMessage = 'Playback failed: $error';
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> stopPlayback() async {
    if (_closed) {
      return;
    }
    if (_activeClip != null || _isPlaying) {
      await audio.stopPlayback();
    }
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
    await _playbackSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _completionSubscription?.cancel();
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
    if (identical(_activeClip, _reconstructedClip)) {
      _hasListenedToReconstructed = true;
    }
    _playbackPosition = _activeClip?.duration ?? Duration.zero;
    _isPlaying = false;
    _notify();
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }
}
