import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/app/app.dart';

void main() {
  testWidgets('home screen offers the challenge and instructions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReverseVibeApp());
    await tester.pumpAndSettle();

    expect(find.text('ReverseVibe'), findsOneWidget);
    expect(find.text('Start Challenge'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Say it.\nFlip it.\nGuess it.'), findsOneWidget);
  });

  testWidgets('instructions show all steps and back returns home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReverseVibeApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    for (final step in [
      'Record the Original',
      'Reverse the Sound',
      'Listen & Replay',
      'Make Your Imitation',
      'Reverse Your Imitation',
      'Reconstruct the Original',
      'Reveal & Compare',
    ]) {
      expect(find.text(step), findsOneWidget);
    }

    for (final description in [
      'Player A records an original voice, phrase, song, or any sound.',
      "ReverseVibe reverses Player A's original recording.",
      'Player B listens to the reversed recording and can replay it as many '
          'times as needed.',
      'Player B records their own attempt to reproduce the sound they heard.',
      "ReverseVibe reverses Player B's imitation recording.",
      'Player B listens to the reversed imitation and asks Player A, '
          '"Is this what you said?"',
      'Player A confirms the guess, and the original recording is played for '
          'comparison.',
    ]) {
      expect(find.text(description), findsOneWidget);
    }

    expect(find.text('Switch roles and play again.'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Start Challenge'), findsOneWidget);
  });

  testWidgets('challenge action explains that audio features are not ready', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReverseVibeApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Challenge'));
    await tester.tap(find.text('Start Challenge'));
    await tester.pumpAndSettle();

    expect(find.text('Challenge mode is coming soon'), findsOneWidget);
    expect(find.textContaining('not available yet'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge mode is coming soon'), findsNothing);
  });

  testWidgets('home and instructions fit a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReverseVibeApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'home screen layout');

    await tester.ensureVisible(find.text('How to Play'));
    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'instructions layout');
    await tester.ensureVisible(find.text('Reveal & Compare'));

    expect(find.text('Reveal & Compare'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
