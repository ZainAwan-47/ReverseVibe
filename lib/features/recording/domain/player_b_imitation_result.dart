import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';

class PlayerBImitationResult {
  const PlayerBImitationResult({
    required this.originalClip,
    required this.reversedClip,
    required this.imitationClip,
  });

  final AudioClip originalClip;
  final AudioClip reversedClip;
  final AudioClip imitationClip;
}
