import 'models/audio_clip.dart';

/// Contract for temporary audio operations; implementations must not persist clips.
abstract interface class AudioEngine {
  Future<AudioClip> record({required Duration maxDuration});

  Future<AudioClip> reverse(AudioClip clip);

  Future<void> play(AudioClip clip);

  Future<void> stopPlayback();

  Future<void> clearTemporaryAudio();

  Future<void> dispose();
}
