import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../theme/app_theme.dart';

/// Shrinks slightly while pressed, with a light haptic on tap.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.fast,
          curve: Motion.ease,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.4,
            duration: Motion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A thumbnail of [asset] that fades in over a neutral placeholder.
class AssetThumb extends StatelessWidget {
  const AssetThumb({
    super.key,
    required this.asset,
    this.size = 300,
    this.fit = BoxFit.cover,
  });

  final AssetEntity asset;
  final int size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Image(
      image: AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: ThumbnailSize.square(size),
      ),
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: Motion.medium,
          curve: Motion.ease,
          child: child,
        );
      },
      errorBuilder: (_, _, _) => ColoredBox(
        color: p.surfaceHigh,
        child: Icon(Icons.broken_image_outlined, color: p.textFaint),
      ),
    );
  }
}

/// Circular progress with a gradient stroke.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 12,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: Motion.slow,
      curve: Motion.emphasized,
      builder: (context, v, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            track: p.stroke,
            colors: [p.accent, p.accentAlt, p.accent],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.colors,
  });

  final double value;
  final double stroke;
  final Color track;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.colors != colors;
}

/// Round icon button with frosted backdrop — for use over photos.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final button = Pressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.surface.withValues(alpha: 0.72),
              border: Border.all(color: p.stroke),
            ),
            child: Icon(icon, size: size * 0.46, color: p.text),
          ),
        ),
      ),
    );
    if (badge == null || badge == 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: -4,
          top: -4,
          child: IgnorePointer(child: CountBadge(count: badge!)),
        ),
      ],
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedSwitcher(
      duration: Motion.fast,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: Container(
        key: ValueKey(count),
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.delete,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.bg, width: 2),
        ),
        child: Text(
          count > 999 ? '999+' : '$count',
          style: AppText.w(10, FontWeight.w800, height: 1, color: Colors.white),
        ),
      ),
    );
  }
}

/// Full-width primary action with a gradient fill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Solid fill instead of the accent gradient.
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final glow = color ?? p.accent;
    return Pressable(
      onTap: busy ? null : onTap,
      scale: 0.97,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: color,
          gradient: color == null ? p.accentGradient : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(label, style: AppText.headline(color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

/// Secondary action: quiet surface fill.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: p.text, size: 19),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppText.headline(color: p.text)),
          ],
        ),
      ),
    );
  }
}
