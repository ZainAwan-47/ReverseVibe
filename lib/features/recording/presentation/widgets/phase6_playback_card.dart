import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

class Phase6PlaybackCard extends StatelessWidget {
  const Phase6PlaybackCard({
    required this.title,
    required this.clip,
    required this.isPlaying,
    required this.progress,
    required this.remaining,
    required this.onToggle,
    required this.keyPrefix,
    super.key,
  });

  final String title;
  final AudioClip clip;
  final bool isPlaying;
  final double progress;
  final Duration remaining;
  final VoidCallback onToggle;
  final String keyPrefix;

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
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: AppColors.border,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatRemainingDuration(clip.duration),
                        style: textTheme.bodySmall,
                      ),
                      Text(
                        _formatRemainingDuration(remaining),
                        key: ValueKey('$keyPrefix-playback-remaining'),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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

String _formatRemainingDuration(Duration duration) {
  final wholeSeconds = duration.inMicroseconds <= 0
      ? 0
      : (duration.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
            Duration.microsecondsPerSecond;
  final minutes = (wholeSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (wholeSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
