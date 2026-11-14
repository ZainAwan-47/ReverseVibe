import 'package:flutter/material.dart';

import '../../../../navigation/app_router.dart';
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
                    'Your confirmed take is held in temporary memory. '
                    'Next, it will be reversed so you can hear your '
                    'reconstructed result.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('player-b-reverse-imitation'),
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRouter.playerBReconstructed,
                      arguments: result,
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Reverse imitation'),
                  ),
                  const SizedBox(height: 12),
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
