import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../navigation/app_router.dart';
import '../../../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const logoAssemblyDuration = Duration(milliseconds: 900);
  static const wordmarkDuration = Duration(milliseconds: 600);
  static const brandingHoldDuration = Duration(milliseconds: 2500);
  static const _splashSequenceDuration = Duration(milliseconds: 4000);
  static const _logoEnd = 0.225;
  static const _wordmarkEnd = 0.375;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _barHeights = [11.0, 23.0, 36.0, 23.0, 11.0];

  late final AnimationController _controller;
  late final Animation<double> _tileOpacity;
  late final Animation<double> _tileScale;
  late final List<Animation<double>> _barProgress;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkPosition;
  late final Animation<double> _sloganOpacity;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen._splashSequenceDuration,
    );

    _tileOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.09, curve: Curves.easeOut),
    );
    _tileScale = Tween<double>(begin: 0.68, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0,
          SplashScreen._logoEnd,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    _barProgress = List<Animation<double>>.generate(_barHeights.length, (
      index,
    ) {
      final start = index * 0.07 * SplashScreen._logoEnd;
      final end = (index * 0.07 + 0.58) * SplashScreen._logoEnd;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        SplashScreen._logoEnd,
        SplashScreen._wordmarkEnd,
        curve: Curves.easeOut,
      ),
    );
    _wordmarkPosition =
        Tween<Offset>(begin: const Offset(-0.22, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(
              SplashScreen._logoEnd,
              SplashScreen._wordmarkEnd,
              curve: Curves.easeOutCubic,
            ),
          ),
        );
    _sloganOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.3,
        SplashScreen._wordmarkEnd,
        curve: Curves.easeOut,
      ),
    );

    _controller.addStatusListener(_handleAnimationStatus);
    _controller.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _navigateHome();
    }
  }

  void _navigateHome() {
    if (!mounted || _navigationStarted) {
      return;
    }

    _navigationStarted = true;
    Navigator.of(context).pushReplacementNamed(AppRouter.home);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final markSize = compact ? 64.0 : 72.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedBrandMark(
                          tileOpacity: _tileOpacity,
                          tileScale: _tileScale,
                          barProgress: _barProgress,
                          size: markSize,
                          barHeights: _barHeights
                              .map((height) => height * markSize / 72)
                              .toList(growable: false),
                        ),
                        SizedBox(width: compact ? 12 : 16),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FadeTransition(
                              key: const ValueKey('splash-wordmark-fade'),
                              opacity: _wordmarkOpacity,
                              child: SlideTransition(
                                key: const ValueKey('splash-wordmark-slide'),
                                position: _wordmarkPosition,
                                child: Text(
                                  AppConstants.appName,
                                  key: const ValueKey('splash-wordmark'),
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontSize: compact ? 24 : 28,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FadeTransition(
                              key: const ValueKey('splash-slogan-fade'),
                              opacity: _sloganOpacity,
                              child: Text(
                                'LISTEN. REVERSE. RECREATE.',
                                key: const ValueKey('splash-slogan'),
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium?.copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ],
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
  }
}

class _AnimatedBrandMark extends StatelessWidget {
  const _AnimatedBrandMark({
    required this.tileOpacity,
    required this.tileScale,
    required this.barProgress,
    required this.size,
    required this.barHeights,
  });

  final Animation<double> tileOpacity;
  final Animation<double> tileScale;
  final List<Animation<double>> barProgress;
  final double size;
  final List<double> barHeights;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey('splash-logo-fade'),
      opacity: tileOpacity,
      child: ScaleTransition(
        key: const ValueKey('splash-logo-scale'),
        scale: tileScale,
        child: Container(
          key: const ValueKey('splash-logo-mark'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.secondary, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(size * 0.32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List<Widget>.generate(barProgress.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedBuilder(
                  animation: barProgress[index],
                  builder: (context, child) {
                    return Container(
                      key: ValueKey('splash-logo-bar-$index'),
                      width: 4,
                      height: barHeights[index] * barProgress[index].value,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
