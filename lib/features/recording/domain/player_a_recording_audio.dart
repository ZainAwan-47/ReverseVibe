import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';

abstract interface class PlayerARecordingAudio {
  Stream<bool> get playbackState;

  Stream<Duration> get playbackPosition;

  Stream<void> get playbackComplete;

  Stream<double> get recordingAmplitude;

  Stream<void> get recordingInterrupted;

  Future<void> startRecording();

  Future<AudioClip> stopRecording();

  Future<void> play(AudioClip clip);

  Future<void> seek(AudioClip clip, Duration position);

  Future<void> pausePlayback();

  Future<void> resumePlayback();

  Future<void> stopPlayback();

  Future<void> dispose();
}
