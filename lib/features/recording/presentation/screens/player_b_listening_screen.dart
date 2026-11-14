import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/features/recording/presentation/controllers/player_b_listening_controller.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';
import '../../domain/player_b_imitation_result.dart';

class PlayerBListeningScreen extends StatefulWidget {
  const PlayerBListeningScreen({
    required this.originalClip,
    super.key,
    this.controller,
  });

  final AudioClip originalClip;
  final PlayerBListeningController? controller;

  @override
  State<PlayerBListeningScreen> createState() => _PlayerBListeningScreenState();
}

class _PlayerBListeningScreenState extends State<PlayerBListeningScreen> {
  late final PlayerBListeningController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        PlayerBListeningController.production(widget.originalClip);
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
            library: 'ReverseVibe Player B',
            context: ErrorDescription('while releasing Player B audio'),
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
        final textTheme = Theme.of(context).textTheme;
        final reversedClip = _controller.reversedClip;
        final imitation = _controller.imitation;
        final recording = _controller.isRecording;
        final stopping = _controller.status == PlayerBStatus.stopping;
        final permissionDenied =
            _controller.status == PlayerBStatus.permissionDenied;
        final permissionPermanentlyDenied =
            _controller.status == PlayerBStatus.permissionPermanentlyDenied;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Listen closely',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Listen to Player A’s sound played backwards, '
                              'then recreate what you heard. Replay it as '
                              'often as you need.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            if (_controller.status == PlayerBStatus.preparing)
                              const _PreparingCard()
                            else if (reversedClip != null) ...[
                              _PlaybackCard(
                                title: 'Player A’s sound, reversed',
                                clip: reversedClip,
                                isPlaying: _controller.isClipPlaying(
                                  reversedClip,
                                ),
                                progress: _controller.playbackProgressFor(
                                  reversedClip,
                                ),
                                remaining: _controller.playbackRemainingFor(
                                  reversedClip,
                                ),
                                onToggle: () => unawaited(
                                  _controller.togglePlayback(reversedClip),
                                ),
                                keyPrefix: 'player-b-reversed',
                              ),
                              const SizedBox(height: 20),
                              _recordingSection(
                                context,
                                recording: recording,
                                stopping: stopping,
                                imitation: imitation,
                              ),
                            ],
                            if (permissionDenied || permissionPermanentlyDenied)
                              _PermissionNotice(
                                permanentlyDenied: permissionPermanentlyDenied,
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
        );
      },
    );
  }

  Widget _recordingSection(
    BuildContext context, {
    required bool recording,
    required bool stopping,
    required AudioClip? imitation,
  }) {
    final textTheme = Theme.of(context).textTheme;
    if (recording || stopping) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                stopping ? 'Saving your take' : 'Make your imitation',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              _VoiceVisualizer(
                levels: _controller.amplitudeHistory,
                active: recording,
              ),
              const SizedBox(height: 16),
              Text(
                _formatDuration(_controller.elapsed),
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
                        onPressed: _controller.stopRecording,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 30),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Up to ${_controller.maxDuration.inSeconds} seconds',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (imitation == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _SectionIcon(icon: Icons.record_voice_over_rounded),
              const SizedBox(height: 14),
              Text('Your turn to recreate it', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'When you’re ready, record your best imitation.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('player-b-recording-start'),
                onPressed: _controller.isBusy
                    ? null
                    : _controller.startRecording,
                icon: const Icon(Icons.mic_none_rounded),
                label: const Text('Record imitation'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlaybackCard(
          title: 'Your imitation',
          clip: imitation,
          isPlaying: _controller.isClipPlaying(imitation),
          progress: _controller.playbackProgressFor(imitation),
          remaining: _controller.playbackRemainingFor(imitation),
          onToggle: () => unawaited(_controller.togglePlayback(imitation)),
          keyPrefix: 'player-b-imitation',
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('player-b-recording-discard'),
          onPressed: _controller.isBusy ? null : _controller.discardRecording,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Discard take'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('player-b-recording-again'),
          onPressed: _controller.isBusy
              ? null
              : () => unawaited(_controller.recordAnotherTake()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Record another take'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('player-b-recording-confirm'),
          onPressed: _controller.isBusy
              ? null
              : () => _confirmImitation(imitation),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirm imitation'),
        ),
      ],
    );
  }

  Future<void> _confirmImitation(AudioClip imitation) async {
    try {
      await _controller.stopPlayback();
      if (!mounted || _controller.reversedClip == null) {
        return;
      }
      final result = PlayerBImitationResult(
        originalClip: widget.originalClip,
        reversedClip: _controller.reversedClip!,
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

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.title,
    required this.clip,
    required this.isPlaying,
    required this.progress,
    required this.remaining,
    required this.onToggle,
    required this.keyPrefix,
  });

  final String title;
  final AudioClip clip;
  final bool isPlaying;
  final double progress;
  final Duration remaining;
  final VoidCallback onToggle;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconButton.filledTonal(
              key: ValueKey('$keyPrefix-playback-toggle'),
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
                  Text(title, style: textTheme.titleMedium),
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
                        key: ValueKey('$keyPrefix-playback-remaining'),
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
            const SizedBox(width: 10),
            const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.secondary,
              size: 22,
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

class _PreparingCard extends StatelessWidget {
  const _PreparingCard();

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
            Expanded(child: Text('Preparing the reversed sound…')),
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
