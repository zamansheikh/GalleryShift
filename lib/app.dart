import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';

class GalleryShiftApp extends StatefulWidget {
  const GalleryShiftApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<GalleryShiftApp> createState() => _GalleryShiftAppState();
}

class _GalleryShiftAppState extends State<GalleryShiftApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: widget.controller.onResume,
      onInactive: widget.controller.flush,
    );
    widget.controller.bootstrap();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'GalleryShift',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayFor(Theme.of(context).brightness),
          child: child!,
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final Widget page;
    if (app.permission == null) {
      page = ColoredBox(
        key: const ValueKey('splash'),
        color: Palette.of(context).bg,
      );
    } else if (!app.hasAccess) {
      page = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      page = const HomeScreen(key: ValueKey('home'));
    }
    return AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.emphasized,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      ),
      child: page,
    );
  }
}
