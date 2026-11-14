import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/features/recording/presentation/widgets/audio_playback_seek_bar.dart';

void main() {
  testWidgets('track taps seek forward and backward', (
    WidgetTester tester,
  ) async {
    final key = const ValueKey('test-playback-seekbar');
    await tester.pumpWidget(_app(keyPrefix: 'test'));

    final sliderRect = tester.getRect(find.byKey(key));
    await tester.tapAt(Offset(sliderRect.right - 20, sliderRect.center.dy));
    await tester.pumpAndSettle();
    var state = tester.state<_SeekBarHarnessState>(
      find.byType(_SeekBarHarness),
    );
    expect(state.seeks.single.inSeconds, greaterThanOrEqualTo(3));
    expect(_label(tester, 'test-playback-elapsed'), isNot('00:00'));

    final updatedRect = tester.getRect(find.byKey(key));
    await tester.tapAt(Offset(updatedRect.left + 20, updatedRect.center.dy));
    await tester.pumpAndSettle();
    state = tester.state<_SeekBarHarnessState>(find.byType(_SeekBarHarness));
    expect(state.seeks.last.inSeconds, lessThanOrEqualTo(1));
    expect(_label(tester, 'test-playback-remaining'), '00:04');
  });

  testWidgets('dragging the handle seeks forward and backward', (
    WidgetTester tester,
  ) async {
    const key = ValueKey('test-playback-seekbar');
    await tester.pumpWidget(_app(keyPrefix: 'test'));

    var rect = tester.getRect(find.byKey(key));
    final start = Offset(rect.left + 18, rect.center.dy);
    final forward = await tester.startGesture(start);
    await tester.pump();
    await forward.moveTo(Offset(rect.left + rect.width * 0.78, rect.center.dy));
    await tester.pump();
    await forward.up();
    await tester.pumpAndSettle();

    var state = tester.state<_SeekBarHarnessState>(
      find.byType(_SeekBarHarness),
    );
    final forwardPosition = state.seeks.single;
    expect(forwardPosition.inSeconds, greaterThanOrEqualTo(2));

    rect = tester.getRect(find.byKey(key));
    final currentSlider = tester.widget<Slider>(find.byKey(key));
    final thumbX = rect.left + 18 + currentSlider.value * (rect.width - 36);
    final backward = await tester.startGesture(Offset(thumbX, rect.center.dy));
    await tester.pump();
    await backward.moveTo(Offset(thumbX - rect.width * 0.35, rect.center.dy));
    await tester.pump();
    await backward.up();
    await tester.pumpAndSettle();

    state = tester.state<_SeekBarHarnessState>(find.byType(_SeekBarHarness));
    expect(state.seeks, hasLength(2));
    expect(state.seeks.last, lessThan(forwardPosition));
  });

  testWidgets(
    'drag preview resists position updates until release, then seeks once',
    (WidgetTester tester) async {
      const key = ValueKey('test-playback-seekbar');
      await tester.pumpWidget(_app(keyPrefix: 'test'));

      final rect = tester.getRect(find.byKey(key));
      final gesture = await tester.startGesture(
        Offset(rect.left + 20, rect.center.dy),
      );
      await tester.pump();
      await gesture.moveTo(
        Offset(rect.left + rect.width * 0.78, rect.center.dy),
      );
      await tester.pump();

      final preview = _label(tester, 'test-playback-elapsed');
      expect(preview, isNot('00:00'));
      tester
          .state<_SeekBarHarnessState>(find.byType(_SeekBarHarness))
          .emitPosition(Duration.zero);
      await tester.pump();
      expect(_label(tester, 'test-playback-elapsed'), preview);

      await gesture.up();
      await tester.pumpAndSettle();
      final state = tester.state<_SeekBarHarnessState>(
        find.byType(_SeekBarHarness),
      );
      expect(state.seeks, hasLength(1));
      expect(state.seeks.single.inSeconds, greaterThanOrEqualTo(2));
      expect(
        _label(tester, 'test-playback-elapsed'),
        _format(state.seeks.single),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('zero-duration clips disable seeking safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioPlaybackSeekBar(
            duration: Duration.zero,
            position: const Duration(seconds: 10),
            onSeek: (_) async {},
            keyPrefix: 'empty',
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('empty-playback-seekbar')),
    );
    expect(slider.onChanged, isNull);
    expect(_label(tester, 'empty-playback-elapsed'), '00:00');
    expect(_label(tester, 'empty-playback-remaining'), '00:00');
  });
}

Widget _app({required String keyPrefix}) => MaterialApp(
  home: Scaffold(body: _SeekBarHarness(keyPrefix: keyPrefix)),
);

String _label(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _format(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

class _SeekBarHarness extends StatefulWidget {
  const _SeekBarHarness({required this.keyPrefix});

  final String keyPrefix;

  @override
  State<_SeekBarHarness> createState() => _SeekBarHarnessState();
}

class _SeekBarHarnessState extends State<_SeekBarHarness> {
  final List<Duration> seeks = [];
  Duration position = Duration.zero;

  void emitPosition(Duration value) => setState(() => position = value);

  Future<void> seek(Duration value) async {
    seeks.add(value);
    setState(() => position = value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AudioPlaybackSeekBar(
        duration: const Duration(seconds: 4),
        position: position,
        onSeek: seek,
        keyPrefix: widget.keyPrefix,
      ),
    );
  }
}
