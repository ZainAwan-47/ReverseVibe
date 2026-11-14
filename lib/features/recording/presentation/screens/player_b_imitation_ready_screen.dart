import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../domain/player_b_imitation_result.dart';

class PlayerBImitationReadyScreen extends StatelessWidget {
  const PlayerBImitationReadyScreen({required this.result, super.key});

  final PlayerBImitationResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'NEXT STAGE',
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.secondary,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.secondary,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Imitation confirmed',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your take is safely held in temporary memory. '
                    'The next stage will reverse it.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  _ClipSummary(
                    title: 'Player A original',
                    duration: result.originalClip.duration,
                  ),
                  const SizedBox(height: 10),
                  _ClipSummary(
                    title: 'Reversed sound',
                    duration: result.reversedClip.duration,
                  ),
                  const SizedBox(height: 10),
                  _ClipSummary(
                    title: 'Confirmed imitation',
                    duration: result.imitationClip.duration,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('return-to-player-b'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Return to Player B'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipSummary extends StatelessWidget {
  const _ClipSummary({required this.title, required this.duration});

  final String title;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = duration.inMicroseconds <= 0
        ? 0
        : (duration.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
              Duration.microsecondsPerSecond;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq_rounded, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('$minutes:$seconds'),
          ],
        ),
      ),
    );
  }
}
