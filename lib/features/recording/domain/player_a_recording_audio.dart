import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';

abstract interface class PlayerARecordingAudio {
  Stream<bool> get playbackState;

  Future<void> startRecording();

  Future<AudioClip> stopRecording();

  Future<void> play(AudioClip clip);

  Future<void> pausePlayback();

  Future<void> stopPlayback();

  Future<void> dispose();
}
