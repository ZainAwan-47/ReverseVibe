import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import 'audio_playback_seek_bar.dart';

class Phase6PlaybackCard extends StatelessWidget {
  const Phase6PlaybackCard({
    required this.title,
    required this.clip,
    required this.isPlaying,
    required this.position,
    required this.onToggle,
    required this.onSeek,
    required this.keyPrefix,
    this.canSeek = true,
    super.key,
  });

  final String title;
  final AudioClip clip;
  final bool isPlaying;
  final Duration position;
  final VoidCallback onToggle;
  final Future<void> Function(Duration position) onSeek;
  final String keyPrefix;
  final bool canSeek;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: ValueKey('$keyPrefix-playback-toggle'),
              tooltip: isPlaying ? 'Pause audio' : 'Play audio',
              onPressed: onToggle,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  AudioPlaybackSeekBar(
                    duration: clip.duration,
                    position: position,
                    onSeek: onSeek,
                    keyPrefix: keyPrefix,
                    enabled: canSeek,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.secondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
