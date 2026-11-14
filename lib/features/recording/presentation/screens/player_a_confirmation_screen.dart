import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_reconstructed_controller.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';

class PlayerAConfirmationScreen extends StatelessWidget {
  const PlayerAConfirmationScreen({required this.controller, super.key});

  final PlayerBReconstructedController controller;

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
          'PLAYER A',
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
                      Icons.hearing_rounded,
                      color: AppColors.secondary,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Player A, please listen',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Player B’s reconstructed sound is ready. '
                    'The original stays hidden until you confirm.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Is this what you said?',
                    key: const ValueKey('player-a-confirmation-question'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('player-a-confirm-reveal'),
                    onPressed: controller.reconstructedClip == null
                        ? null
                        : () => unawaited(_revealOriginal(context)),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Confirm and reveal original'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _revealOriginal(BuildContext context) async {
    try {
      await controller.stopPlayback();
      if (!context.mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamed(AppRouter.playerBFinalReveal, arguments: controller);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare the reveal: $error')),
        );
      }
    }
  }
}
