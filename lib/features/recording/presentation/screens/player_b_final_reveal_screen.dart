import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_reconstructed_controller.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';
import '../widgets/phase6_playback_card.dart';

class PlayerBFinalRevealScreen extends StatefulWidget {
  const PlayerBFinalRevealScreen({required this.controller, super.key});

  final PlayerBReconstructedController controller;

  @override
  State<PlayerBFinalRevealScreen> createState() =>
      _PlayerBFinalRevealScreenState();
}

class _PlayerBFinalRevealScreenState extends State<PlayerBFinalRevealScreen> {
  PlayerBReconstructedController get _controller => widget.controller;
  bool _leaving = false;
  bool _allowPop = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.hasChallengeAudio) {
          return const SizedBox.shrink();
        }
        final reconstructed = _controller.reconstructedClip;
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
                'FINAL REVEAL',
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'The original sound',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Player A’s original is revealed. Play each sound '
                          'to compare it with Player B’s reconstruction.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 28),
                        Phase6PlaybackCard(
                          key: const ValueKey('player-a-original-comparison'),
                          title: 'Player A’s original recording',
                          clip: _controller.result.originalClip,
                          isPlaying: _controller.isClipPlaying(
                            _controller.result.originalClip,
                          ),
                          position: _controller.playbackPositionFor(
                            _controller.result.originalClip,
                          ),
                          onToggle: () => unawaited(
                            _controller.togglePlayback(
                              _controller.result.originalClip,
                            ),
                          ),
                          onSeek: (position) => _controller.seekPlayback(
                            _controller.result.originalClip,
                            position,
                          ),
                          keyPrefix: 'player-a-original',
                          canSeek: !_controller.isBusy,
                        ),
                        const SizedBox(height: 14),
                        if (reconstructed != null)
                          Phase6PlaybackCard(
                            key: const ValueKey(
                              'player-b-reconstructed-comparison',
                            ),
                            title: 'Player B’s reconstructed sound',
                            clip: reconstructed,
                            isPlaying: _controller.isClipPlaying(reconstructed),
                            position: _controller.playbackPositionFor(
                              reconstructed,
                            ),
                            onToggle: () => unawaited(
                              _controller.togglePlayback(reconstructed),
                            ),
                            onSeek: (position) => _controller.seekPlayback(
                              reconstructed,
                              position,
                            ),
                            keyPrefix: 'player-b-reconstructed',
                            canSeek: !_controller.isBusy,
                          ),
                        if (_controller.errorMessage case final message?)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                message,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const ValueKey('restart-challenge'),
                          onPressed: _leaving
                              ? null
                              : () => unawaited(_restart()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Restart'),
                        ),
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

  Future<void> _restart() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    try {
      await _controller.stopPlayback();
      if (mounted) {
        _controller.clearChallenge();
        unawaited(
          _controller.close(clearChallenge: true).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'ReverseVibe challenge restart',
                context: ErrorDescription('while releasing playback resources'),
              ),
            );
          }),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.playerARecording,
          (route) => route.settings.name == AppRouter.home,
        );
      }
    } catch (error) {
      _leaving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restart the challenge: $error')),
        );
      }
    }
  }
}
