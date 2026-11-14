import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reverse_vibe/features/audio/domain/models/audio_clip.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

import '../../../../navigation/app_router.dart';
import '../controllers/player_a_recording_controller.dart';

class PlayerARecordingScreen extends StatefulWidget {
  const PlayerARecordingScreen({super.key, this.controller});

  final PlayerARecordingController? controller;

  @override
  State<PlayerARecordingScreen> createState() => _PlayerARecordingScreenState();
}

class _PlayerARecordingScreenState extends State<PlayerARecordingScreen> {
  late final PlayerARecordingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PlayerARecordingController.production();
  }

  @override
  void dispose() {
    unawaited(
      _controller.close().catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'ReverseVibe recording',
            context: ErrorDescription('while releasing recording resources'),
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
        final status = _controller.status;
        final recording = status == PlayerARecordingStatus.recording;
        final stopping = status == PlayerARecordingStatus.stopping;
        final permissionDenied =
            status == PlayerARecordingStatus.permissionDenied;
        final permissionPermanentlyDenied =
            status == PlayerARecordingStatus.permissionPermanentlyDenied;
        final clip = _controller.clip;
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
                              'Record the original',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Capture a voice, phrase, song, or any sound. '
                              'Your recording stays on this device.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 32),
                            _RecordingControl(
                              recording: recording,
                              stopping: stopping || _controller.isBusy,
                              elapsed: _controller.elapsed,
                              onPressed: recording
                                  ? _controller.stopRecording
                                  : _controller.startRecording,
                            ),
                            const SizedBox(height: 24),
                            if (permissionDenied || permissionPermanentlyDenied)
                              _PermissionNotice(
                                permanentlyDenied: permissionPermanentlyDenied,
                                onTryAgain: _controller.startRecording,
                                onOpenSettings: () => unawaited(
                                  _controller.openPermissionSettings(),
                                ),
                              )
                            else if (_controller.errorMessage
                                case final message?)
                              _ErrorNotice(message: message),
                            if (clip != null) ...[
                              const SizedBox(height: 24),
                              _PlaybackCard(
                                duration: clip.duration,
                                position: _controller.playbackPosition,
                                remaining: _controller.playbackRemaining,
                                isPlaying: _controller.isPlaying,
                                waveform: _controller.playbackWaveform,
                                waveformProgress:
                                    _controller.playbackWaveformProgress,
                                onToggle: () =>
                                    unawaited(_controller.togglePlayback()),
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final reRecordButton = OutlinedButton.icon(
                                    key: const ValueKey('recording-re-record'),
                                    onPressed: _controller.isBusy
                                        ? null
                                        : _controller.startRecording,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Re-record'),
                                  );
                                  final confirmButton = FilledButton.icon(
                                    key: const ValueKey('recording-confirm'),
                                    onPressed: _controller.isBusy
                                        ? null
                                        : () => _confirmRecording(clip),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Use recording'),
                                  );

                                  if (constraints.maxWidth < 360) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        reRecordButton,
                                        const SizedBox(height: 8),
                                        confirmButton,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: reRecordButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: confirmButton),
                                    ],
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              'Up to ${_controller.maxDuration.inSeconds} seconds',
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
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

  Future<void> _confirmRecording(AudioClip clip) async {
    try {
      await _controller.stopPlayback();
      if (!mounted) {
        return;
      }
      await Navigator.of(
        context,
      ).pushReplacementNamed(AppRouter.originalReady, arguments: clip);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare the recording: $error')),
        );
      }
    }
  }
}

class _RecordingControl extends StatelessWidget {
  const _RecordingControl({
    required this.recording,
    required this.stopping,
    required this.elapsed,
    required this.onPressed,
  });

  final bool recording;
  final bool stopping;
  final Duration elapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = stopping
        ? 'Preparing audio'
        : recording
        ? 'Recording in progress'
        : 'Ready to record';

    return Column(
      children: [
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.14),
            border: Border.all(
              color: recording ? AppColors.error : AppColors.border,
              width: 1.5,
            ),
          ),
          child: stopping
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : IconButton(
                  key: ValueKey(
                    recording ? 'recording-stop' : 'recording-start',
                  ),
                  tooltip: recording ? 'Stop recording' : 'Start recording',
                  onPressed: onPressed,
                  iconSize: 44,
                  color: recording ? AppColors.error : AppColors.secondary,
                  icon: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  ),
                ),
        ),
        const SizedBox(height: 18),
        Text(
          _formatDuration(elapsed),
          key: const ValueKey('recording-duration'),
          style: textTheme.headlineMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (recording)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                ),
              ),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: recording ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.duration,
    required this.position,
    required this.remaining,
    required this.isPlaying,
    required this.waveform,
    required this.waveformProgress,
    required this.onToggle,
  });

  final Duration duration;
  final Duration position;
  final Duration remaining;
  final bool isPlaying;
  final List<double> waveform;
  final double waveformProgress;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _PlaybackWaveformControl(
              waveform: waveform,
              progress: waveformProgress,
              isPlaying: isPlaying,
              onPressed: onToggle,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original recording', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: duration.inMicroseconds == 0
                        ? 0
                        : (position.inMicroseconds / duration.inMicroseconds)
                              .clamp(0, 1)
                              .toDouble(),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: AppColors.border,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatRemainingDuration(duration),
                        style: textTheme.bodySmall,
                      ),
                      Text(
                        _formatRemainingDuration(remaining),
                        key: const ValueKey('recording-playback-remaining'),
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

class _PlaybackWaveformControl extends StatelessWidget {
  const _PlaybackWaveformControl({
    required this.waveform,
    required this.progress,
    required this.isPlaying,
    required this.onPressed,
  });

  final List<double> waveform;
  final double progress;
  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Original recording playback waveform',
      child: SizedBox(
        width: 76,
        height: 76,
        child: CustomPaint(
          key: const ValueKey('recording-playback-visualizer'),
          painter: _PlaybackWaveformPainter(
            waveform: waveform,
            progress: progress,
            isPlaying: isPlaying,
          ),
          child: Center(
            child: IconButton.filledTonal(
              key: const ValueKey('recording-playback-toggle'),
              tooltip: isPlaying ? 'Pause recording' : 'Play recording',
              onPressed: onPressed,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackWaveformPainter extends CustomPainter {
  const _PlaybackWaveformPainter({
    required this.waveform,
    required this.progress,
    required this.isPlaying,
  });

  final List<double> waveform;
  final double progress;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var index = 0; index < waveform.length; index++) {
      final level = waveform[index].clamp(0, 1).toDouble();
      final angle = index * math.pi * 2 / waveform.length - math.pi / 2;
      final innerRadius = 27.0;
      final outerRadius = innerRadius + 2 + level * 8;
      final played = isPlaying && index / waveform.length <= progress;
      paint.color = played ? AppColors.secondary : AppColors.border;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * innerRadius,
          center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlaybackWaveformPainter oldDelegate) =>
      oldDelegate.waveform != waveform ||
      oldDelegate.progress != progress ||
      oldDelegate.isPlaying != isPlaying;
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
                        'Player A’s sound.'
                  : 'Allow microphone access to record the original sound.',
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
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
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
