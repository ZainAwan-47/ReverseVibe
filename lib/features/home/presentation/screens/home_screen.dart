import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const BrandMark(),
                          const SizedBox(height: 24),
                          Text(
                            AppConstants.appName,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.secondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Hear it backwards.\nGuess it forwards.',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Turn a familiar tune, a spoken phrase, or any '
                            'sound into a delightfully unexpected guessing '
                            'game.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 40),
                          _GameFlowCard(textTheme: textTheme),
                          const SizedBox(height: 24),
                          Text(
                            'A little sound. A lot of confusion.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
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

class _GameFlowCard extends StatelessWidget {
  const _GameFlowCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _FlowStep(
              icon: Icons.mic_none_rounded,
              title: 'Make a sound',
              subtitle: 'Sing, speak, or get creative',
              textTheme: textTheme,
            ),
            const _FlowConnector(),
            _FlowStep(
              icon: Icons.swap_horiz_rounded,
              title: 'Turn it around',
              subtitle: 'Hear something unexpected',
              textTheme: textTheme,
            ),
            const _FlowConnector(),
            _FlowStep(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Guess the original',
              subtitle: 'The big reveal is the best part',
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textTheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.secondary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(subtitle, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 21),
          Container(width: 1, height: 14, color: AppColors.border),
        ],
      ),
    );
  }
}
