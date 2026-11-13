import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _steps = [
    _HowToPlayStep(
      number: '01',
      title: 'Record the Original',
      description:
          'Player A records an original voice, phrase, song, or any sound.',
      icon: Icons.mic_none_rounded,
    ),
    _HowToPlayStep(
      number: '02',
      title: 'Reverse the Sound',
      description: "ReverseVibe reverses Player A's original recording.",
      icon: Icons.swap_horiz_rounded,
    ),
    _HowToPlayStep(
      number: '03',
      title: 'Listen & Replay',
      description:
          'Player B listens to the reversed recording and can replay it as '
          'many times as needed.',
      icon: Icons.headphones_rounded,
    ),
    _HowToPlayStep(
      number: '04',
      title: 'Make Your Imitation',
      description:
          'Player B records their own attempt to reproduce the sound they '
          'heard.',
      icon: Icons.record_voice_over_rounded,
    ),
    _HowToPlayStep(
      number: '05',
      title: 'Reverse Your Imitation',
      description: "ReverseVibe reverses Player B's imitation recording.",
      icon: Icons.replay_rounded,
    ),
    _HowToPlayStep(
      number: '06',
      title: 'Reconstruct the Original',
      description:
          'Player B listens to the reversed imitation and asks Player A, '
          '"Is this what you said?"',
      icon: Icons.question_answer_outlined,
    ),
    _HowToPlayStep(
      number: '07',
      title: 'Reveal & Compare',
      description:
          'Player A confirms the guess, and the original recording is played '
          'for comparison.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

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
        title: Text('How to Play', style: textTheme.titleMedium),
        centerTitle: false,
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SEVEN STEPS, ONE SOUND.',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'How the game works',
                    style: textTheme.headlineMedium?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Player A records a sound for Player B to hear in reverse. '
                    'Player B imitates it, then hears that imitation reversed '
                    'to reconstruct and confirm the original.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  for (var index = 0; index < _steps.length; index++) ...[
                    _StepCard(
                      step: _steps[index],
                      isLast: index == _steps.length - 1,
                    ),
                    if (index != _steps.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToPlayStep {
  const _HowToPlayStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.isLast});

  final _HowToPlayStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: isLast ? AppColors.backgroundSecondary : AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isLast ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                step.number,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(step.icon, color: AppColors.secondary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(step.description, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
