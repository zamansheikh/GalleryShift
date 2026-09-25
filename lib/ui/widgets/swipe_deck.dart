import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/deck.dart';
import '../../theme/app_theme.dart';

/// Drives a [SwipeDeck] from outside: button swipes, undo, and the drag
/// progress (-1 = fully toward delete, 1 = fully toward keep) so other
/// widgets can react while the user drags.
class SwipeDeckController {
  _SwipeDeckState? _state;
  final ValueNotifier<double> progress = ValueNotifier(0);

  bool get isAnimating => _state?._busy ?? false;

  Future<void> swipe(Decision decision) async =>
      _state?._flyOut(decision, velocity: Offset.zero, fromButton: true);

  /// Call right after putting the undone card back at the top: it flies in
  /// from the side it left.
  void returnCard(Decision leftAs) => _state?._flyIn(leftAs);

  Future<void> demo() async => _state?._demo();

  void dispose() => progress.dispose();
}

/// [depth] is 0 for the top card, 1 for the one behind it, and so on.
typedef CardBuilder = Widget Function(
  BuildContext context,
  AssetEntity asset,
  int depth,
);

class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.items,
    required this.index,
    required this.controller,
    required this.cardBuilder,
    required this.onDecided,
    this.onTap,
  });

  final List<AssetEntity> items;
  final int index;
  final SwipeDeckController controller;
  final CardBuilder cardBuilder;
  final void Function(AssetEntity asset, Decision decision) onDecided;
  final void Function(AssetEntity asset)? onTap;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onTick);

  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Curve _curve = Curves.linear;
  bool _grabbedTop = true;
  bool _busy = false;
  bool _pastThreshold = false;
  Size _size = Size.zero;

  double get _threshold => _size.width * 0.26;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _anim.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ animation

  void _onTick() {
    final t = _anim.value;
    // Springs overshoot past 1; lerp handles that, curves don't.
    final eased = _curve == Curves.linear
        ? t
        : _curve.transform(t.clamp(0.0, 1.0));
    _setOffset(Offset.lerp(_from, _to, eased)!);
  }

  void _setOffset(Offset o) {
    setState(() => _offset = o);
    final p = _threshold == 0 ? 0.0 : (o.dx / _threshold).clamp(-1.0, 1.0);
    widget.controller.progress.value = p;
  }

  Future<void> _animateTo(Offset target, Duration duration, Curve curve) {
    _from = _offset;
    _to = target;
    _curve = curve;
    _anim.value = 0;
    return _anim.animateTo(1, duration: duration, curve: Curves.linear);
  }

  Future<void> _springBack(Offset velocity) {
    _from = _offset;
    _to = Offset.zero;
    _curve = Curves.linear;
    final distance = _offset.distance;
    // Velocity along the path back to the centre, normalised to 0..1 units.
    final v = distance == 0
        ? 0.0
        : -(velocity.dx * _offset.dx + velocity.dy * _offset.dy) /
              (distance * distance);
    _anim.value = 0;
    return _anim.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 24),
        0,
        1,
        v,
      ),
    );
  }

  Future<void> _flyOut(
    Decision d, {
    required Offset velocity,
    bool fromButton = false,
  }) async {
    if (_busy || widget.index >= widget.items.length) return;
    _busy = true;
    final sign = d == Decision.keep ? 1.0 : -1.0;
    final target = Offset(
      sign * _size.width * 1.6,
      _offset.dy + (fromButton ? 40 : velocity.dy * 0.12),
    );
    final speed = velocity.dx.abs().clamp(900.0, 4000.0);
    final remaining = (target.dx - _offset.dx).abs();
    final ms = fromButton
        ? 360
        : (remaining / speed * 1000).clamp(160, 320).round();
    if (fromButton) _grabbedTop = true;
    HapticFeedback.mediumImpact();
    await _animateTo(
      target,
      Duration(milliseconds: ms),
      fromButton ? Curves.easeInCubic : Curves.easeOutCubic,
    );
    final asset = widget.items[widget.index];
    _offset = Offset.zero;
    _pastThreshold = false;
    widget.controller.progress.value = 0;
    _busy = false;
    widget.onDecided(asset, d);
  }

  Future<void> _flyIn(Decision leftAs) async {
    _anim.stop();
    final sign = leftAs == Decision.keep ? 1.0 : -1.0;
    _offset = Offset(sign * _size.width * 1.4, -30);
    _grabbedTop = true;
    _busy = true;
    await _animateTo(Offset.zero, Motion.slow, Curves.easeOutBack);
    _busy = false;
  }

  Future<void> _demo() async {
    if (_busy || widget.index >= widget.items.length) return;
    _busy = true;
    _grabbedTop = true;
    const d = Duration(milliseconds: 520);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await _animateTo(Offset(_threshold * 0.9, 0), d, Curves.easeInOutCubic);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await _animateTo(
      Offset(-_threshold * 0.9, 0),
      d * 1.4,
      Curves.easeInOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await _animateTo(Offset.zero, d, Curves.easeOutCubic);
    _busy = false;
  }

  // -------------------------------------------------------------- gestures

  void _onPanStart(DragStartDetails d) {
    if (_busy) return;
    _anim.stop();
    _grabbedTop = d.localPosition.dy < _size.height / 2;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_busy) return;
    _setOffset(_offset + d.delta);
    final past = _offset.dx.abs() >= _threshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_busy) return;
    final v = d.velocity.pixelsPerSecond;
    final dx = _offset.dx;
    final flungRight = v.dx > 900 && dx > 0;
    final flungLeft = v.dx < -900 && dx < 0;
    if (dx >= _threshold || flungRight) {
      _flyOut(Decision.keep, velocity: v);
    } else if (dx <= -_threshold || flungLeft) {
      _flyOut(Decision.delete, velocity: v);
    } else {
      _pastThreshold = false;
      _springBack(v);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final visible = <int>[
          for (var i = widget.index + 2; i >= widget.index; i--)
            if (i < widget.items.length) i,
        ];
        final progress = _threshold == 0
            ? 0.0
            : (_offset.dx.abs() / _threshold).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in visible)
              KeyedSubtree(
                key: ValueKey(widget.items[i].id),
                child: _positioned(context, i - widget.index, progress),
              ),
          ],
        );
      },
    );
  }

  /// Every card gets the same widget structure whatever its depth, so its
  /// state (a loaded image, a playing video) survives moving to the front.
  Widget _positioned(BuildContext context, int depth, double progress) {
    final asset = widget.items[widget.index + depth];
    final isTop = depth == 0;

    final Matrix4 transform;
    final Alignment origin;
    double opacity = 1;
    double dim = 0;
    double signed = 0;

    if (isTop) {
      final angle = _size.width == 0
          ? 0.0
          : (_offset.dx / _size.width) * 0.42 * (_grabbedTop ? 1 : -1);
      transform = Matrix4.translationValues(_offset.dx, _offset.dy, 0)
        ..rotateZ(angle.clamp(-math.pi / 8, math.pi / 8));
      origin = Alignment.center;
      signed = _threshold == 0
          ? 0.0
          : (_offset.dx / _threshold).clamp(-1.0, 1.0);
    } else {
      // Cards behind rise toward the front as the top card leaves.
      final d = depth - progress;
      final scale = 1 - 0.05 * d;
      transform = Matrix4.translationValues(0, 18.0 * d, 0)
        ..scaleByDouble(scale, scale, 1, 1);
      origin = Alignment.bottomCenter;
      // The third card peeks faintly and is fully opaque by the time it
      // becomes second, so the hand-off has no jump.
      opacity = depth == 2 ? 0.55 + 0.45 * progress : 1.0;
      // Dim what's underneath so only the top card reads as a photo.
      dim = (0.45 * d).clamp(0.0, 0.6);
    }

    return IgnorePointer(
      ignoring: !isTop,
      child: GestureDetector(
        onPanStart: isTop ? _onPanStart : null,
        onPanUpdate: isTop ? _onPanUpdate : null,
        onPanEnd: isTop ? _onPanEnd : null,
        onTap: isTop && widget.onTap != null
            ? () => widget.onTap!(asset)
            : null,
        child: Transform(
          transform: transform,
          alignment: origin,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                RepaintBoundary(
                  child: widget.cardBuilder(context, asset, depth),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: _DecisionOverlay(value: signed)),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: dim),
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The KEEP / DELETE stamp and edge glow over the top card.
class _DecisionOverlay extends StatelessWidget {
  const _DecisionOverlay({required this.value});

  /// -1..1; negative leans delete.
  final double value;

  @override
  Widget build(BuildContext context) {
    if (value == 0) return const SizedBox.shrink();
    final p = Palette.of(context);
    final keep = value > 0;
    final color = keep ? p.keep : p.delete;
    final strength = Curves.easeOut.transform(value.abs());

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: keep ? Alignment.centerLeft : Alignment.centerRight,
                  end: keep ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    color.withValues(alpha: 0.45 * strength),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.7],
                ),
                border: Border.all(
                  color: color.withValues(alpha: 0.9 * strength),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          Positioned(
            top: 44,
            left: keep ? 28 : null,
            right: keep ? null : 28,
            child: Opacity(
              opacity: strength,
              child: Transform.scale(
                scale: 0.8 + 0.2 * strength,
                child: Transform.rotate(
                  angle: keep ? -0.22 : 0.22,
                  child: _Stamp(label: keep ? 'KEEP' : 'DELETE', color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppText.w(
          30,
          FontWeight.w800,
          height: 1.1,
          spacing: 2,
          color: color,
        ),
      ),
    );
  }
}
