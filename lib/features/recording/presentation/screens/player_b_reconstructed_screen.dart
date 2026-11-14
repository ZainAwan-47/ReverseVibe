import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_reconstructed_controller.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';
import '../widgets/phase6_playback_card.dart';

class PlayerBReconstructedScreen extends StatefulWidget {
  const PlayerBReconstructedScreen({required this.controller, super.key});

  final PlayerBReconstructedController controller;

  @override
  State<PlayerBReconstructedScreen> createState() =>
      _PlayerBReconstructedScreenState();
}

class _PlayerBReconstructedScreenState
    extends State<PlayerBReconstructedScreen> {
  PlayerBReconstructedController get _controller => widget.controller;
  bool _leaving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.prepare());
  }

  @override
  void dispose() {
    unawaited(
      _controller.close().catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'ReverseVibe reconstructed audio',
            context: ErrorDescription('while releasing playback resources'),
          ),
        );
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final clip = _controller.reconstructedClip;
        final textTheme = Theme.of(context).textTheme;
        return PopScope<Object?>(
          canPop: !_controller.isPlaying || _allowPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              unawaited(_leave());
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => unawaited(_leave()),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Text(
                'PLAYER B',
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
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your reconstructed result',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This is Player B’s imitation, played backwards — '
                          'the sound you believe reconstructs the original.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        if (_controller.isPreparing)
                          const _PreparingNotice()
                        else if (_controller.errorMessage case final message?)
                          _ErrorNotice(message: message)
                        else if (clip case final reconstructed?)
                          Phase6PlaybackCard(
                            title: 'Player B’s reconstructed sound',
                            clip: reconstructed,
                            isPlaying: _controller.isClipPlaying(reconstructed),
                            progress: _controller.playbackProgressFor(
                              reconstructed,
                            ),
                            remaining: _controller.playbackRemainingFor(
                              reconstructed,
                            ),
                            onToggle: () => unawaited(
                              _controller.togglePlayback(reconstructed),
                            ),
                            keyPrefix: 'player-b-reconstructed',
                          ),
                        if (clip != null) ...[
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            key: const ValueKey('ask-player-a-confirmation'),
                            onPressed:
                                _controller.isBusy ||
                                    !_controller.hasListenedToReconstructed
                                ? null
                                : () => unawaited(_askPlayerA()),
                            icon: const Icon(Icons.question_answer_outlined),
                            label: Text(
                              _controller.hasListenedToReconstructed
                                  ? 'Ask Player A to confirm'
                                  : 'Listen through to continue',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _askPlayerA() async {
    try {
      await _controller.stopPlayback();
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamed(AppRouter.playerAConfirmation, arguments: _controller);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue to confirmation: $error')),
        );
      }
    }
  }

  Future<void> _leave() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    try {
      await _controller.stopPlayback();
      if (mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (error) {
      _leaving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop playback: $error')),
        );
      }
    }
  }
}

class _PreparingNotice extends StatelessWidget {
  const _PreparingNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('Reversing the confirmed imitation…')),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}
