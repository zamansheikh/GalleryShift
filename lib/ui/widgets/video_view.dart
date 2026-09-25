import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_theme.dart';
import '../../util/format.dart';
import 'asset_card.dart';

/// Height the controls bar takes, for laying out what sits above it.
const double kVideoControlsHeight = 64;

Future<VideoPlayerController> openVideo(AssetEntity asset) async {
  // May download from iCloud first.
  final file = await asset.file;
  if (file == null) throw StateError('No file for ${asset.id}');
  final ctrl = VideoPlayerController.file(
    file,
    // Mix with other audio instead of taking audio focus. With focus
    // handling on, Android refuses to play at all during a phone call (the
    // call holds focus locked), and a muted autoplaying card would pause the
    // user's music.
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  await ctrl.initialize();
  await ctrl.setLooping(true);
  return ctrl;
}

// ===================================================================
// Inline player on a swipe card
// ===================================================================

/// Plays on the top card, preloads (paused) on the card behind it, and
/// releases the player further back.
class CardVideo extends StatefulWidget {
  const CardVideo({
    super.key,
    required this.asset,
    required this.depth,
    required this.fit,
    required this.focus,
    required this.muted,
    this.onFullscreen,
    this.overlay,
  });

  final AssetEntity asset;
  final int depth;
  final BoxFit fit;

  /// Drawn over the video but under the controls (the card's date and size).
  final Widget? overlay;

  /// False while something covers the deck (bin, full-screen viewer).
  final ValueListenable<bool> focus;
  final ValueNotifier<bool> muted;
  final void Function(Duration position)? onFullscreen;

  @override
  State<CardVideo> createState() => _CardVideoState();
}

class _CardVideoState extends State<CardVideo> {
  VideoPlayerController? _ctrl;
  bool _loading = false;
  bool _failed = false;
  bool _userPaused = false;
  bool _appVisible = true;
  late final AppLifecycleListener _lifecycle;

  bool get _isTop => widget.depth == 0;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_sync);
    widget.muted.addListener(_applyVolume);
    _lifecycle = AppLifecycleListener(
      onInactive: () {
        _appVisible = false;
        _sync();
      },
      onResume: () {
        _appVisible = true;
        _sync();
      },
    );
    _sync();
  }

  @override
  void didUpdateWidget(CardVideo old) {
    super.didUpdateWidget(old);
    if (old.focus != widget.focus) {
      old.focus.removeListener(_sync);
      widget.focus.addListener(_sync);
    }
    if (old.muted != widget.muted) {
      old.muted.removeListener(_applyVolume);
      widget.muted.addListener(_applyVolume);
    }
    // Coming back to the top (e.g. after undo) starts fresh.
    if (_isTop && old.depth != 0) _userPaused = false;
    _sync();
  }

  @override
  void dispose() {
    widget.focus.removeListener(_sync);
    widget.muted.removeListener(_applyVolume);
    _lifecycle.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    if (widget.depth >= 2) {
      // Pushed back by an undo: free the decoder.
      final c = _ctrl;
      if (c != null) {
        setState(() => _ctrl = null);
        await c.dispose();
      }
      return;
    }
    final c = _ctrl;
    if (c == null) {
      if (!_loading && !_failed) _load();
      return;
    }
    final shouldPlay =
        _isTop && widget.focus.value && _appVisible && !_userPaused;
    if (shouldPlay && !c.value.isPlaying) {
      await c.play();
    } else if (!shouldPlay && c.value.isPlaying) {
      await c.pause();
    }
  }

  Future<void> _load() async {
    _loading = true;
    try {
      final c = await openVideo(widget.asset);
      if (!mounted || widget.depth >= 2) {
        await c.dispose();
        return;
      }
      await c.setVolume(widget.muted.value ? 0 : 1);
      setState(() => _ctrl = c);
      await _sync();
    } catch (e) {
      debugPrint('Card video failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      _loading = false;
    }
  }

  void _applyVolume() => _ctrl?.setVolume(widget.muted.value ? 0 : 1);

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    _userPaused = c.value.isPlaying;
    c.value.isPlaying ? c.pause() : c.play();
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    widget.muted.value = !widget.muted.value;
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final ready = c != null && c.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          _FadeIn(
            child: SizedBox.expand(
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          ),
        ?widget.overlay,
        if (_isTop) ...[
          VideoGestureLayer(
            controller: c,
            onTogglePlay: _togglePlay,
            rippleBottom: kVideoControlsHeight + 24,
            badgeTop: 22,
          ),
          if (!ready && !_failed)
            const IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: 34,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          if (ready)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: VideoControlsBar(
                controller: c,
                onTogglePlay: _togglePlay,
                trailing: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.muted,
                    builder: (context, muted, _) => _BarIcon(
                      icon: muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      tooltip: muted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute,
                    ),
                  ),
                  if (widget.onFullscreen != null)
                    _BarIcon(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Full screen',
                      onTap: () => widget.onFullscreen!(c.value.position),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ===================================================================
// Full-screen player
// ===================================================================

/// Full-screen video: rounded frame, controls, gestures. Plays with sound.
class VideoView extends StatefulWidget {
  const VideoView({
    super.key,
    required this.asset,
    required this.topInset,
    required this.bottomInset,
    this.startAt = Duration.zero,
  });

  final AssetEntity asset;

  /// Space kept clear above and below for the viewer's header and buttons.
  final double topInset;
  final double bottomInset;
  final Duration startAt;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  VideoPlayerController? _ctrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await openVideo(widget.asset);
      if (!mounted) {
        await c.dispose();
        return;
      }
      if (widget.startAt > Duration.zero) await c.seekTo(widget.startAt);
      await c.play();
      setState(() => _ctrl = c);
    } catch (e) {
      debugPrint('Video load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final a = widget.asset;
    final w = a.orientatedWidth, h = a.orientatedHeight;
    final aspect = c != null && c.value.isInitialized
        ? c.value.aspectRatio
        : (w > 0 && h > 0 ? w / h : 9 / 16);
    final frameBottom = widget.bottomInset + kVideoControlsHeight + 20;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, widget.topInset, 12, frameBottom),
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: cardImageFor(a), fit: BoxFit.cover),
                    if (c != null) _FadeIn(child: VideoPlayer(c)),
                    if (c == null && !_failed)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    if (_failed)
                      ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: Text(
                            'Could not play this video',
                            style: AppText.label(color: Colors.white70),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        VideoGestureLayer(
          controller: c,
          onTogglePlay: _togglePlay,
          rippleTop: widget.topInset,
          rippleBottom: frameBottom,
          badgeTop: widget.topInset + 14,
        ),
        if (c != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: widget.bottomInset + 8,
            child: VideoControlsBar(controller: c, onTogglePlay: _togglePlay),
          ),
      ],
    );
  }
}

// ===================================================================
// Shared pieces
// ===================================================================

/// Tap to play/pause, double-tap a side to jump 10 s, long-press for 4×.
/// Also draws the feedback for each.
class VideoGestureLayer extends StatefulWidget {
  const VideoGestureLayer({
    super.key,
    required this.controller,
    required this.onTogglePlay,
    this.rippleTop = 0,
    this.rippleBottom = 0,
    this.badgeTop = 16,
  });

  final VideoPlayerController? controller;
  final VoidCallback onTogglePlay;
  final double rippleTop;
  final double rippleBottom;
  final double badgeTop;

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer> {
  static const _jump = Duration(seconds: 10);
  static const _fastSpeed = 4.0;

  double? _fastRate;
  bool _playingBeforeFast = false;

  int _jumpSide = 0; // -1 back, 1 forward, 0 none
  int _jumpSeconds = 0;
  int _jumpTick = 0;
  Timer? _jumpTimer;
  Offset? _doubleTapAt;

  IconData? _flashIcon;
  int _flashTick = 0;

  VideoPlayerController? get _c => widget.controller;

  @override
  void dispose() {
    _jumpTimer?.cancel();
    super.dispose();
  }

  void _tap() {
    final c = _c;
    if (c == null) return;
    HapticFeedback.selectionClick();
    final wasPlaying = c.value.isPlaying;
    widget.onTogglePlay();
    setState(() {
      _flashIcon = wasPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
      _flashTick++;
    });
  }

  void _doubleTap(double width) {
    final c = _c;
    final at = _doubleTapAt;
    if (c == null || at == null) return;
    final side = at.dx < width / 2 ? -1 : 1;
    HapticFeedback.lightImpact();
    setState(() {
      _jumpSeconds = (side == _jumpSide ? _jumpSeconds : 0) + _jump.inSeconds;
      _jumpSide = side;
      _jumpTick++;
    });
    final v = c.value;
    var target = v.position + (side < 0 ? -_jump : _jump);
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    c.seekTo(target);
    _jumpTimer?.cancel();
    _jumpTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _jumpSide = 0);
    });
  }

  Future<void> _startFast() async {
    final c = _c;
    if (c == null) return;
    HapticFeedback.mediumImpact();
    _playingBeforeFast = c.value.isPlaying;
    var rate = _fastSpeed;
    try {
      await c.setPlaybackSpeed(rate);
    } catch (_) {
      // Some iOS assets can't fast-forward beyond 2×.
      rate = 2.0;
      try {
        await c.setPlaybackSpeed(rate);
      } catch (_) {
        return;
      }
    }
    if (!c.value.isPlaying) await c.play();
    if (mounted) setState(() => _fastRate = rate);
  }

  Future<void> _endFast() async {
    final c = _c;
    if (c == null || _fastRate == null) return;
    setState(() => _fastRate = null);
    await c.setPlaybackSpeed(1.0);
    if (!_playingBeforeFast) await c.pause();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: () => _doubleTap(box.maxWidth),
            onLongPressStart: (_) => _startFast(),
            onLongPressEnd: (_) => _endFast(),
            onLongPressCancel: _endFast,
          ),
          if (_jumpSide != 0)
            Positioned(
              top: widget.rippleTop,
              bottom: widget.rippleBottom,
              left: _jumpSide > 0 ? null : 0,
              right: _jumpSide > 0 ? 0 : null,
              width: box.maxWidth * 0.42,
              child: _JumpFeedback(
                key: ValueKey(_jumpTick),
                forward: _jumpSide > 0,
                seconds: _jumpSeconds,
              ),
            ),
          if (_flashIcon != null)
            IgnorePointer(
              child: Center(
                child: _Flash(key: ValueKey(_flashTick), icon: _flashIcon!),
              ),
            ),
          if (c != null)
            IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) => AnimatedOpacity(
                  opacity: !v.isPlaying && _fastRate == null ? 1 : 0,
                  duration: Motion.fast,
                  child: const Center(
                    child: _RoundGlass(
                      size: 72,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: widget.badgeTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedScale(
                  scale: _fastRate != null ? 1 : 0.8,
                  duration: Motion.fast,
                  curve: Motion.emphasized,
                  child: AnimatedOpacity(
                    opacity: _fastRate != null ? 1 : 0,
                    duration: Motion.fast,
                    child: _Pill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_fastRate ?? _fastSpeed).toStringAsFixed(0)}×',
                            style: AppText.headline(color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.fast_forward_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Play/pause, seek bar with times, and optional trailing buttons.
///
/// A plain translucent fill rather than a backdrop blur: on a swipe card this
/// moves every frame.
class VideoControlsBar extends StatelessWidget {
  const VideoControlsBar({
    super.key,
    required this.controller,
    required this.onTogglePlay,
    this.trailing = const [],
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlay;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kVideoControlsHeight,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, v, _) => Row(
          children: [
            _BarIcon(
              icon: v.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              tooltip: v.isPlaying ? 'Pause' : 'Play',
              size: 30,
              onTap: () {
                HapticFeedback.selectionClick();
                onTogglePlay();
              },
            ),
            const SizedBox(width: 4),
            Expanded(child: SeekBar(controller: controller)),
            if (trailing.isNotEmpty) const SizedBox(width: 4),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 24,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: Colors.white,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draggable, tappable progress bar with time labels.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, required this.controller});
  final VideoPlayerController controller;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  /// 0..1 while the user drags; null otherwise.
  double? _drag;
  bool _wasPlaying = false;
  DateTime _lastSeek = DateTime.fromMillisecondsSinceEpoch(0);

  VideoPlayerController get _c => widget.controller;

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  Duration _at(double f) => _c.value.duration * f;

  void _start(double f) {
    _wasPlaying = _c.value.isPlaying;
    _c.pause();
    HapticFeedback.selectionClick();
    setState(() => _drag = f);
    _c.seekTo(_at(f));
  }

  void _update(double f) {
    setState(() => _drag = f);
    // Throttle: seeking on every pointer event floods the decoder.
    final now = DateTime.now();
    if (now.difference(_lastSeek) > const Duration(milliseconds: 70)) {
      _lastSeek = now;
      _c.seekTo(_at(f));
    }
  }

  void _tapSeek(double f) {
    HapticFeedback.lightImpact();
    _c.seekTo(_at(f));
  }

  Future<void> _end() async {
    final f = _drag;
    if (f == null) return;
    HapticFeedback.lightImpact();
    await _c.seekTo(_at(f));
    if (_wasPlaying) await _c.play();
    if (mounted) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = _c.value;
    final total = v.duration.inMilliseconds;
    final played =
        _drag ??
        (total == 0 ? 0.0 : v.position.inMilliseconds / total).clamp(0.0, 1.0);
    final buffered = total == 0 || v.buffered.isEmpty
        ? 0.0
        : (v.buffered.last.end.inMilliseconds / total).clamp(0.0, 1.0);
    final active = _drag != null;
    final shown = active ? _at(_drag!) : v.position;
    final barHeight = active ? 8.0 : 5.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) =>
                  _start(_fractionAt(d.localPosition.dx, width)),
              onHorizontalDragUpdate: (d) =>
                  _update(_fractionAt(d.localPosition.dx, width)),
              onHorizontalDragEnd: (_) => _end(),
              onHorizontalDragCancel: _end,
              onTapUp: (d) => _tapSeek(_fractionAt(d.localPosition.dx, width)),
              child: SizedBox(
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    _Track(
                      height: barHeight,
                      width: width,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    _Track(
                      height: barHeight,
                      width: width * buffered,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    _Track(
                      height: barHeight,
                      width: width * played,
                      gradient: p.accentGradient,
                    ),
                    Positioned(
                      left: (width * played) - (active ? 10 : 7),
                      child: AnimatedContainer(
                        duration: Motion.fast,
                        width: active ? 20 : 14,
                        height: active ? 20 : 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (active)
                      Positioned(
                        left: (width * played - 32).clamp(
                          -8.0,
                          math.max(-8.0, width - 56),
                        ),
                        bottom: 30,
                        child: _Pill(
                          dense: true,
                          child: Text(
                            formatDuration(shown),
                            style: AppText.label(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            Text(
              formatDuration(shown),
              style: AppText.w(11, FontWeight.w600, color: Colors.white),
            ),
            const Spacer(),
            Text(
              formatDuration(v.duration),
              style: AppText.w(11, FontWeight.w600, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.height,
    required this.width,
    this.color,
    this.gradient,
  });

  final double height;
  final double width;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.medium,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// Half-height ripple with "10 seconds" after a double-tap.
class _JumpFeedback extends StatelessWidget {
  const _JumpFeedback({
    super.key,
    required this.forward,
    required this.seconds,
  });

  final bool forward;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (context, t, _) {
          final fadeIn = (t / 0.15).clamp(0.0, 1.0);
          final fadeOut = t > 0.7 ? 1 - (t - 0.7) / 0.3 : 1.0;
          return Opacity(
            opacity: fadeIn * fadeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: forward ? const Radius.circular(400) : Radius.zero,
                right: forward ? Radius.zero : const Radius.circular(400),
              ),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Chevrons(forward: forward, t: t),
                    const SizedBox(height: 6),
                    Text(
                      '$seconds seconds',
                      style: AppText.label(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Three arrows lighting up in sequence, pointing the jump direction.
class _Chevrons extends StatelessWidget {
  const _Chevrons({required this.forward, required this.t});
  final bool forward;
  final double t;

  @override
  Widget build(BuildContext context) {
    // Built pointing forward and lit left to right; flipping the row for
    // rewind mirrors both, so the sweep runs right to left.
    final icons = List.generate(3, (i) {
      final phase = ((t * 3) - i * 0.35).clamp(0.0, 1.0);
      final o = 0.35 + 0.65 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
      return Opacity(
        opacity: o,
        child: const Icon(
          Icons.play_arrow_rounded,
          size: 22,
          color: Colors.white,
        ),
      );
    });
    return Transform.flip(
      flipX: !forward,
      child: Row(mainAxisSize: MainAxisSize.min, children: icons),
    );
  }
}

class _Flash extends StatelessWidget {
  const _Flash({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.4 * t, child: child),
      ),
      child: _RoundGlass(
        size: 72,
        child: Icon(icon, size: 40, color: Colors.white),
      ),
    );
  }
}

class _RoundGlass extends StatelessWidget {
  const _RoundGlass({required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.dense = false});
  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 16,
        vertical: dense ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}
