import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../navigation/app_router.dart';

class ReverseVibeApp extends StatelessWidget {
  const ReverseVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRouter.home,
      routes: AppRouter.routes,
    );
  }
}
