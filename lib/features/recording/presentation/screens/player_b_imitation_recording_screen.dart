import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/recording/domain/player_b_imitation_result.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_listening_controller.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';

class PlayerBImitationRecordingScreen extends StatefulWidget {
  const PlayerBImitationRecordingScreen({required this.controller, super.key});

  final PlayerBListeningController controller;

  @override
  State<PlayerBImitationRecordingScreen> createState() =>
      _PlayerBImitationRecordingScreenState();
}

class _PlayerBImitationRecordingScreenState
    extends State<PlayerBImitationRecordingScreen> {
  PlayerBListeningController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final recording = _controller.isRecording;
        final stopping = _controller.status == PlayerBStatus.stopping;
        final imitation = _controller.imitation;
        final textTheme = Theme.of(context).textTheme;

        return PopScope<Object?>(
          canPop: !_controller.isBusy && !recording,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && recording) {
              unawaited(_leaveRecordingStage());
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _controller.isBusy
                    ? null
                    : () => unawaited(_leaveRecordingStage()),
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
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 44,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Make your imitation',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Recreate what you heard from memory. '
                                'Player A’s reference is hidden while you record.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              if (recording || stopping)
                                _RecordingPanel(
                                  controller: _controller,
                                  recording: recording,
                                  stopping: stopping,
                                )
                              else if (imitation == null)
                                _ReadyToRecordPanel(controller: _controller)
                              else
                                _ImitationReviewPanel(
                                  controller: _controller,
                                  imitation: imitation,
                                  onConfirm: () =>
                                      unawaited(_confirmImitation(imitation)),
                                ),
                              if (_controller.status ==
                                      PlayerBStatus.permissionDenied ||
                                  _controller.status ==
                                      PlayerBStatus.permissionPermanentlyDenied)
                                _PermissionNotice(
                                  permanentlyDenied:
                                      _controller.status ==
                                      PlayerBStatus.permissionPermanentlyDenied,
                                  onTryAgain: _controller.startRecording,
                                  onOpenSettings: () => unawaited(
                                    _controller.openPermissionSettings(),
                                  ),
                                ),
                              if (_controller.errorMessage case final message?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _ErrorNotice(message: message),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveRecordingStage() async {
    if (_controller.isBusy) {
      return;
    }
    if (_controller.isRecording) {
      await _controller.stopRecording();
    }
    await _controller.stopPlayback();
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmImitation(AudioClip imitation) async {
    try {
      await _controller.stopPlayback();
      final reversedClip = _controller.reversedClip;
      if (!mounted || reversedClip == null) {
        return;
      }
      final result = PlayerBImitationResult(
        originalClip: _controller.originalClip,
        reversedClip: reversedClip,
        imitationClip: imitation,
      );
      await Navigator.of(
        context,
      ).pushNamed(AppRouter.playerBImitationReady, arguments: result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm the imitation: $error')),
        );
      }
    }
  }
}

class _ReadyToRecordPanel extends StatelessWidget {
  const _ReadyToRecordPanel({required this.controller});

  final PlayerBListeningController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const _SectionIcon(icon: Icons.record_voice_over_rounded),
            const SizedBox(height: 16),
            Text('Ready when you are', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Your recording will stay in temporary memory. '
              'You can review and redo it before confirming.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('player-b-recording-start'),
              onPressed: controller.isBusy ? null : controller.startRecording,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('Start recording'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.controller,
    required this.recording,
    required this.stopping,
  });

  final PlayerBListeningController controller;
  final bool recording;
  final bool stopping;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              stopping ? 'Saving your take' : 'Recording your imitation',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _VoiceVisualizer(
              levels: controller.amplitudeHistory,
              active: recording,
            ),
            const SizedBox(height: 16),
            Text(
              _formatDuration(controller.elapsed),
              key: const ValueKey('player-b-recording-duration'),
              style: textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              recording
                  ? 'Speak naturally — your voice level is shown live'
                  : 'Preparing your recording',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 64,
              height: 64,
              child: stopping
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : IconButton.filled(
                      key: const ValueKey('player-b-recording-stop'),
                      tooltip: 'Stop recording',
                      onPressed: controller.stopRecording,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 30),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              'Up to ${controller.maxDuration.inSeconds} seconds',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImitationReviewPanel extends StatelessWidget {
  const _ImitationReviewPanel({
    required this.controller,
    required this.imitation,
    required this.onConfirm,
  });

  final PlayerBListeningController controller;
  final AudioClip imitation;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlaybackCard(
          clip: imitation,
          isPlaying: controller.isClipPlaying(imitation),
          progress: controller.playbackProgressFor(imitation),
          remaining: controller.playbackRemainingFor(imitation),
          onToggle: () => unawaited(controller.togglePlayback(imitation)),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('player-b-recording-discard'),
          onPressed: controller.isBusy ? null : controller.discardRecording,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Discard take'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('player-b-recording-again'),
          onPressed: controller.isBusy
              ? null
              : () => unawaited(controller.recordAnotherTake()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Record another take'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('player-b-recording-confirm'),
          onPressed: controller.isBusy ? null : onConfirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm imitation'),
        ),
        const SizedBox(height: 10),
        Text(
          'Review your take, then confirm when you are satisfied.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.clip,
    required this.isPlaying,
    required this.progress,
    required this.remaining,
    required this.onToggle,
  });

  final AudioClip clip;
  final bool isPlaying;
  final double progress;
  final Duration remaining;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: const ValueKey('player-b-imitation-playback-toggle'),
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
                  Text('Your imitation', style: textTheme.titleMedium),
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
                        key: const ValueKey(
                          'player-b-imitation-playback-remaining',
                        ),
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
          ],
        ),
      ),
    );
  }
}

class _VoiceVisualizer extends StatelessWidget {
  const _VoiceVisualizer({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: active ? 'Live microphone audio level' : 'Microphone audio level',
      child: SizedBox(
        height: 58,
        width: double.infinity,
        child: CustomPaint(
          painter: _VoiceVisualizerPainter(levels),
          key: const ValueKey('player-b-live-visualizer'),
        ),
      ),
    );
  }
}

class _VoiceVisualizerPainter extends CustomPainter {
  const _VoiceVisualizerPainter(this.levels);

  final List<double> levels;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    const count = 36;
    final barWidth = math
        .max(1.0, (size.width - gap * (count - 1)) / count)
        .toDouble();
    final paint = Paint()
      ..color = AppColors.secondary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final offset = count - levels.length;
    for (var index = 0; index < count; index++) {
      final levelIndex = index - offset;
      final level = levelIndex < 0
          ? 0.0
          : levels[levelIndex].clamp(0, 1).toDouble();
      final normalized = math.sqrt(level);
      final barHeight = 3 + normalized * (size.height - 6);
      final x = barWidth / 2 + index * (barWidth + gap);
      final centerY = size.height / 2;
      paint.color = AppColors.secondary.withValues(
        alpha: 0.28 + normalized * 0.72,
      );
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceVisualizerPainter oldDelegate) =>
      !listEquals(levels, oldDelegate.levels);
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({
    required this.permanentlyDenied,
    required this.onTryAgain,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onTryAgain;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              permanentlyDenied
                  ? 'Microphone access is turned off'
                  : 'Microphone access is needed',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              permanentlyDenied
                  ? 'Enable microphone access in app settings to record '
                        'Player B’s imitation.'
                  : 'Allow microphone access to record your imitation.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (permanentlyDenied)
              OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('Open Settings'),
              )
            else
              OutlinedButton(
                onPressed: onTryAgain,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.secondary, size: 26),
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

String _formatDuration(Duration duration) {
  final safeSeconds = duration.inSeconds.clamp(0, 359999);
  final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
