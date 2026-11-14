import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';

import '../../../../navigation/app_router.dart';
import '../../../../theme/app_colors.dart';

class OriginalReadyScreen extends StatelessWidget {
  const OriginalReadyScreen({required this.clip, super.key});

  final AudioClip clip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minutes = clip.duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (clip.duration.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'NEXT STEP',
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
                    'Original recording ready',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Player A’s sound is ready for the next gameplay step. '
                    'Reversing the audio will be available in a later phase.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Original sound',
                              style: textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '$minutes:$seconds',
                            style: textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(AppRouter.home, (_) => false),
                    child: const Text('Back to Home'),
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
