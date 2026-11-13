import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../navigation/app_router.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/brand_mark.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 460),
                      curve: Curves.easeOutCubic,
                      child: _HomeContent(textTheme: textTheme),
                      builder: (context, progress, child) {
                        return Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, (1 - progress) * 12),
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandHeader(textTheme: textTheme),
          const SizedBox(height: 44),
          Text(
            'THE SOUND GUESSING GAME',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Say it.\n'),
                TextSpan(
                  text: 'Flip it.\n',
                  style: TextStyle(color: AppColors.secondary),
                ),
                const TextSpan(text: 'Guess it.'),
              ],
            ),
            style: textTheme.headlineLarge?.copyWith(
              fontSize: 44,
              height: 1.05,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Hear a voice, song, or sound played backwards, '
            'then guess what it was.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          const _ExperienceCard(),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _showChallengeNotice(context),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('Start Challenge'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.howToPlay),
            icon: const Icon(Icons.menu_book_outlined, size: 19),
            label: const Text('How to Play'),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No setup. Just pass the phone and play.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showChallengeNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.hourglass_top_rounded,
          color: AppColors.secondary,
          size: 28,
        ),
        title: const Text('Challenge mode is coming soon'),
        content: const Text(
          'Recording and audio playback are not available yet. '
          'For now, explore how the game will work.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SOUND GUESSING GAME',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'One sound, a new perspective',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record it. Hear it reversed. Guess together.',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
