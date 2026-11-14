import 'package:flutter/material.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/how_to_play_screen.dart';
import '../features/recording/presentation/screens/original_ready_screen.dart';
import '../features/recording/presentation/screens/player_a_recording_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/audio/domain/models/audio_clip.dart';

abstract final class AppRouter {
  static const splash = '/splash';
  static const home = '/';
  static const howToPlay = '/how-to-play';
  static const playerARecording = '/record-player-a';
  static const originalReady = '/original-ready';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final Widget page;
    switch (settings.name) {
      case splash:
        page = const SplashScreen();
      case home:
        page = const HomeScreen();
      case howToPlay:
        page = const HowToPlayScreen();
      case playerARecording:
        page = const PlayerARecordingScreen();
      case originalReady:
        final clip = settings.arguments;
        if (clip is! AudioClip) {
          return null;
        }
        page = OriginalReadyScreen(clip: clip);
      default:
        return null;
    }

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
