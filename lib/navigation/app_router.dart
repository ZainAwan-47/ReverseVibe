import 'package:flutter/material.dart';

import '../features/home/presentation/screens/home_screen.dart';

abstract final class AppRouter {
  static const home = '/';

  static final routes = <String, WidgetBuilder>{
    home: (_) => const HomeScreen(),
  };
}
