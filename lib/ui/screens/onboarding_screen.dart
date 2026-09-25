import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;

  Future<void> _request() async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    await app.requestAccess();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);
    final denied =
        app.askedForAccess &&
        (app.permission == PermissionState.denied ||
            app.permission == PermissionState.restricted);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          // Soft colour glows behind the illustration.
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: p.accent, size: 360),
          ),
          Positioned(
            top: 60,
            right: -120,
            child: _Glow(color: p.accentAlt, size: 320),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                children: [
                  const Expanded(
                    flex: 11,
                    child: Center(child: _CardsIllustration()),
                  ),
                  Expanded(
                    flex: 10,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            denied
                                ? 'Photo access\nis turned off'
                                : 'Swipe your\ngallery clean.',
                            style: AppText.display(color: p.text)
                                .copyWith(fontSize: 38),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            denied
                                ? 'GalleryShift needs access to your photos to show them to you. Turn it on in Settings, then come back.'
                                : 'One photo at a time. Swipe right to keep it, left to let it go. Nothing is deleted until you say so.',
                            style: AppText.body(color: p.textDim)
                                .copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 22),
                          if (!denied) ...[
                            _Feature(
                              icon: Icons.swipe_rounded,
                              color: p.accent,
                              text: 'Fast, one-handed decisions',
                            ),
                            _Feature(
                              icon: Icons.verified_user_rounded,
                              color: p.keep,
                              text: 'You review the bin before anything goes',
                            ),
                            _Feature(
                              icon: Icons.lock_rounded,
                              color: p.accentAlt,
                              text: 'Private: photos never leave your phone',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: denied ? 'Open Settings' : 'Get started',
                    icon: denied
                        ? Icons.settings_rounded
                        : Icons.arrow_forward_rounded,
                    busy: _busy,
                    onTap: denied ? app.repo.openSettings : _request,
                  ),
                  if (denied) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy ? null : _request,
                      child: Text(
                        'Ask again',
                        style: AppText.label(color: p.textDim),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppText.label(color: p.text).copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three stacked "photos"; the top one sways left and right, showing the
/// DELETE and KEEP stamps in turn.
class _CardsIllustration extends StatefulWidget {
  const _CardsIllustration();

  @override
  State<_CardsIllustration> createState() => _CardsIllustrationState();
}

class _CardsIllustrationState extends State<_CardsIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final h = math.min(c.maxHeight * 0.92, 340.0);
        final w = h * 0.72;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // -1..1 sway, lingering at each side.
            final s = math.sin(_c.value * math.pi * 2);
            final sway = s.sign * math.pow(s.abs(), 0.6).toDouble();
            return SizedBox(
              width: w * 1.5,
              height: h,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 28),
                    child: Transform.scale(
                      scale: 0.88,
                      child: _FakePhoto(
                        width: w,
                        height: h,
                        colors: const [Color(0xFF2B5876), Color(0xFF4E4376)],
                        icon: Icons.landscape_rounded,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, 14),
                    child: Transform.scale(
                      scale: 0.94,
                      child: _FakePhoto(
                        width: w,
                        height: h,
                        colors: const [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
                        icon: Icons.pets_rounded,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(sway * w * 0.22, 0),
                    child: Transform.rotate(
                      angle: sway * 0.16,
                      child: Stack(
                        children: [
                          _FakePhoto(
                            width: w,
                            height: h,
                            colors: [p.accent, p.accentAlt],
                            icon: Icons.wb_sunny_rounded,
                          ),
                          Positioned(
                            top: 22,
                            left: 18,
                            child: Opacity(
                              opacity: sway.clamp(0.0, 1.0),
                              child: _MiniStamp(
                                label: 'KEEP',
                                color: p.keep,
                                angle: -0.22,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 22,
                            right: 18,
                            child: Opacity(
                              opacity: (-sway).clamp(0.0, 1.0),
                              child: _MiniStamp(
                                label: 'DELETE',
                                color: p.delete,
                                angle: 0.22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FakePhoto extends StatelessWidget {
  const _FakePhoto({
    required this.width,
    required this.height,
    required this.colors,
    required this.icon,
  });

  final double width;
  final double height;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              icon,
              size: width * 0.34,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: width * 0.42,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: width * 0.26,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStamp extends StatelessWidget {
  const _MiniStamp({
    required this.label,
    required this.color,
    required this.angle,
  });
  final String label;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: AppText.w(18, FontWeight.w800, spacing: 1.5, color: color),
        ),
      ),
    );
  }
}
