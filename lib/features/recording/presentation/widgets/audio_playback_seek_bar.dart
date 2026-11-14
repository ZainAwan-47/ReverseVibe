import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reverse_vibe/theme/app_colors.dart';

class AudioPlaybackSeekBar extends StatefulWidget {
  const AudioPlaybackSeekBar({
    required this.duration,
    required this.position,
    required this.onSeek,
    required this.keyPrefix,
    this.enabled = true,
    super.key,
  });

  final Duration duration;
  final Duration position;
  final Future<void> Function(Duration position) onSeek;
  final String keyPrefix;
  final bool enabled;

  @override
  State<AudioPlaybackSeekBar> createState() => _AudioPlaybackSeekBarState();
}

class _AudioPlaybackSeekBarState extends State<AudioPlaybackSeekBar> {
  Duration? _previewPosition;
  bool _isDragging = false;

  Duration get _displayedPosition => _previewPosition ?? widget.position;

  bool get _canSeek => widget.enabled && widget.duration > Duration.zero;

  double get _sliderValue {
    if (widget.duration <= Duration.zero) {
      return 0;
    }
    return (_displayedPosition.inMicroseconds / widget.duration.inMicroseconds)
        .clamp(0, 1)
        .toDouble();
  }

  Duration _durationAt(double value) => Duration(
    microseconds: (widget.duration.inMicroseconds * value)
        .round()
        .clamp(0, widget.duration.inMicroseconds)
        .toInt(),
  );

  @override
  void didUpdateWidget(covariant AudioPlaybackSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration && !_isDragging) {
      _previewPosition = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = Duration(
      microseconds: _displayedPosition.inMicroseconds
          .clamp(0, widget.duration.inMicroseconds)
          .toInt(),
    );
    final remaining = Duration(
      microseconds: (widget.duration.inMicroseconds - position.inMicroseconds)
          .clamp(0, widget.duration.inMicroseconds)
          .toInt(),
    );

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: SliderTheme(
            data: theme.sliderTheme.copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.secondary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.secondary,
              overlayColor: AppColors.secondary.withValues(alpha: 0.18),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              key: ValueKey('${widget.keyPrefix}-playback-seekbar'),
              min: 0,
              max: 1,
              value: _sliderValue,
              onChangeStart: _canSeek
                  ? (value) => setState(() {
                      _isDragging = true;
                      _previewPosition = _durationAt(value);
                    })
                  : null,
              onChanged: _canSeek
                  ? (value) => setState(() {
                      _isDragging = true;
                      _previewPosition = _durationAt(value);
                    })
                  : null,
              onChangeEnd: _canSeek ? _finishSeek : null,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              key: ValueKey('${widget.keyPrefix}-playback-elapsed'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _formatDuration(remaining, roundUp: true),
              key: ValueKey('${widget.keyPrefix}-playback-remaining'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _finishSeek(double value) {
    final position = _durationAt(value);
    setState(() {
      _isDragging = false;
      _previewPosition = position;
    });
    unawaited(_applySeek(position));
  }

  Future<void> _applySeek(Duration position) async {
    try {
      await widget.onSeek(position);
    } finally {
      if (mounted) {
        setState(() => _previewPosition = null);
      }
    }
  }
}

String _formatDuration(Duration duration, {bool roundUp = false}) {
  final micros = duration.inMicroseconds;
  final seconds = micros <= 0
      ? 0
      : roundUp
      ? (micros + Duration.microsecondsPerSecond - 1) ~/
            Duration.microsecondsPerSecond
      : micros ~/ Duration.microsecondsPerSecond;
  final minutesText = (seconds ~/ 60).toString().padLeft(2, '0');
  final secondsText = (seconds % 60).toString().padLeft(2, '0');
  return '$minutesText:$secondsText';
}
