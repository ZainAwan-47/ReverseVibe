import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_vibe/app/app.dart';
import 'package:reverse_vibe/features/splash/presentation/screens/splash_screen.dart';
import 'package:reverse_vibe/navigation/app_router.dart';
import 'package:reverse_vibe/theme/app_theme.dart';

void main() {
  testWidgets('logo components assemble with a deliberate animation', (
    WidgetTester tester,
  ) async {
    final observer = _RouteReplacementObserver();
    await tester.pumpWidget(_testApp(observer: observer));

    expect(find.byKey(const ValueKey('splash-logo-mark')), findsOneWidget);
    expect(find.text('ReverseVibe'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('splash-logo-bar-2'))).height,
      0,
    );
    expect(observer.splashToHomeReplacements, 0);

    await tester.pump(const Duration(milliseconds: 450));
    final middleBarHeight = tester
        .getSize(find.byKey(const ValueKey('splash-logo-bar-2')))
        .height;
    expect(middleBarHeight, greaterThan(0));
    expect(middleBarHeight, lessThan(36));

    await tester.pump(const Duration(milliseconds: 450));
    expect(
      tester.getSize(find.byKey(const ValueKey('splash-logo-bar-2'))).height,
      36,
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find.byKey(const ValueKey('splash-logo-scale')),
          )
          .scale
          .value,
      1,
    );
    expect(observer.splashToHomeReplacements, 0);
    expect(find.text('Start Challenge'), findsNothing);
  });

  testWidgets('wordmark slides into place after logo assembly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(SplashScreen.logoAssemblyDuration);

    final wordmarkSlide = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('splash-wordmark-slide')),
    );
    expect(wordmarkSlide.position.value, const Offset(-0.22, 0));
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-wordmark-fade')),
          )
          .opacity
          .value,
      0,
    );
    expect(find.text('LISTEN. REVERSE. RECREATE.'), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-slogan-fade')),
          )
          .opacity
          .value,
      0,
    );

    await tester.pump(const Duration(milliseconds: 450));
    final sloganOpacity = tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('splash-slogan-fade')),
        )
        .opacity
        .value;
    expect(sloganOpacity, greaterThan(0));
    expect(sloganOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const ValueKey('splash-wordmark-slide')),
          )
          .position
          .value,
      Offset.zero,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-wordmark-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-slogan-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(find.text('HEAR IT BACKWARDS. GUESS IT FORWARDS.'), findsNothing);
  });

  testWidgets('branding holds before replacing the splash route exactly once', (
    WidgetTester tester,
  ) async {
    final observer = _RouteReplacementObserver();
    await tester.pumpWidget(_testApp(observer: observer));
    await tester.pump(SplashScreen.logoAssemblyDuration);
    await tester.pump(SplashScreen.wordmarkDuration);

    expect(find.byKey(const ValueKey('splash-logo-mark')), findsOneWidget);
    expect(find.text('ReverseVibe'), findsOneWidget);
    _expectSloganVisiblyBeneathWordmark(tester);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-slogan-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-logo-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<ScaleTransition>(
            find.byKey(const ValueKey('splash-logo-scale')),
          )
          .scale
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-wordmark-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const ValueKey('splash-wordmark-slide')),
          )
          .position
          .value,
      Offset.zero,
    );
    expect(observer.splashToHomeReplacements, 0);

    await tester.pump(
      SplashScreen.brandingHoldDuration - const Duration(milliseconds: 1),
    );
    expect(find.byKey(const ValueKey('splash-logo-mark')), findsOneWidget);
    expect(find.text('ReverseVibe'), findsOneWidget);
    _expectSloganVisiblyBeneathWordmark(tester);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-slogan-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-logo-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('splash-wordmark-fade')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const ValueKey('splash-wordmark-slide')),
          )
          .position
          .value,
      Offset.zero,
    );
    expect(observer.splashToHomeReplacements, 0);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(observer.splashToHomeReplacements, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start Challenge'), findsOneWidget);
    expect(find.text('LISTEN. REVERSE. RECREATE.'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(observer.splashToHomeReplacements, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen offers the challenge and instructions', (
    WidgetTester tester,
  ) async {
    await _pumpAppToHome(tester);

    expect(find.text('ReverseVibe'), findsOneWidget);
    expect(find.text('Start Challenge'), findsOneWidget);
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Say it.\nFlip it.\nGuess it.'), findsOneWidget);
  });

  testWidgets('instructions show all steps and back returns home', (
    WidgetTester tester,
  ) async {
    await _pumpAppToHome(tester);

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

  testWidgets('home and instructions fit a compact phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReverseVibeApp());
    expect(tester.takeException(), isNull, reason: 'splash screen layout');
    await tester.pump(SplashScreen.logoAssemblyDuration);
    await tester.pump(SplashScreen.wordmarkDuration);
    await tester.pump(SplashScreen.brandingHoldDuration);
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

Future<void> _pumpAppToHome(WidgetTester tester) async {
  await tester.pumpWidget(const ReverseVibeApp());
  await tester.pump(SplashScreen.logoAssemblyDuration);
  await tester.pump(SplashScreen.wordmarkDuration);
  await tester.pump(SplashScreen.brandingHoldDuration);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void _expectSloganVisiblyBeneathWordmark(WidgetTester tester) {
  final wordmarkRect = tester.getRect(
    find.byKey(const ValueKey('splash-wordmark')),
  );
  final sloganRect = tester.getRect(
    find.byKey(const ValueKey('splash-slogan')),
  );
  final sloganOpacity = tester
      .widget<FadeTransition>(find.byKey(const ValueKey('splash-slogan-fade')))
      .opacity
      .value;

  expect(sloganRect.top, greaterThan(wordmarkRect.bottom));
  expect(sloganRect.center.dx, closeTo(wordmarkRect.center.dx, 1));
  expect(sloganRect.width, greaterThan(0));
  expect(sloganRect.height, greaterThan(0));
  expect(sloganOpacity, greaterThanOrEqualTo(0.99));
}

Widget _testApp({NavigatorObserver? observer}) {
  return MaterialApp(
    theme: AppTheme.dark,
    initialRoute: AppRouter.splash,
    onGenerateRoute: AppRouter.onGenerateRoute,
    navigatorObservers: [?observer],
  );
}

class _RouteReplacementObserver extends NavigatorObserver {
  int splashToHomeReplacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute?.settings.name == AppRouter.splash &&
        newRoute?.settings.name == AppRouter.home) {
      splashToHomeReplacements++;
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
