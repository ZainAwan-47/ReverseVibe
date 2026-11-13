import 'package:flutter/material.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/how_to_play_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

abstract final class AppRouter {
  static const splash = '/splash';
  static const home = '/';
  static const howToPlay = '/how-to-play';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final Widget page;
    switch (settings.name) {
      case splash:
        page = const SplashScreen();
      case home:
        page = const HomeScreen();
      case howToPlay:
        page = const HowToPlayScreen();
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
