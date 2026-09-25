import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/deck.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/asset_card.dart';
import '../widgets/common.dart';

/// Full-screen look at one asset. Pops with a [Decision] when [showActions]
/// is set and the user picks one.
class ViewerScreen extends StatelessWidget {
  const ViewerScreen({
    super.key,
    required this.asset,
    this.showActions = false,
  });

  final AssetEntity asset;
  final bool showActions;

  static Route<Decision> route(AssetEntity asset, {bool showActions = false}) {
    return PageRouteBuilder<Decision>(
      opaque: false,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.fast,
      pageBuilder: (_, _, _) =>
          ViewerScreen(asset: asset, showActions: showActions),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Motion.ease),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: Motion.emphasized)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final isVideo = asset.type == AssetType.video;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            isVideo ? _VideoView(asset: asset) : _PhotoView(asset: asset),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Theme(
                        data: AppTheme.build(Brightness.dark),
                        child: GlassIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatDate(asset.createDateTime),
                              style: AppText.headline(color: Colors.white),
                            ),
                            Text(
                              _time(asset.createDateTime),
                              style: AppText.caption(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showActions)
              Positioned(
                left: 24,
                right: 24,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Delete',
                            icon: Icons.delete_rounded,
                            color: p.delete,
                            onTap: () =>
                                Navigator.of(context).pop(Decision.delete),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Keep',
                            icon: Icons.check_rounded,
                            color: p.keep,
                            onTap: () =>
                                Navigator.of(context).pop(Decision.keep),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.asset});
  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    final w = asset.orientatedWidth, h = asset.orientatedHeight;
    // A large thumbnail rather than the original: originals can be HEIC or
    // RAW, which not every platform decoder handles.
    const maxSide = 2800;
    final scale = (w > 0 && h > 0)
        ? math.min(1.0, maxSide / math.max(w, h))
        : 1.0;
    final hq = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: (w > 0 && h > 0)
          ? ThumbnailSize((w * scale).round(), (h * scale).round())
          : const ThumbnailSize.square(2400),
    );
    return InteractiveViewer(
      maxScale: 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The card image is already cached: show it at once, then sharpen.
          Image(
            image: cardImageFor(asset),
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
          Image(
            image: hq,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
              opacity: sync || frame != null ? 1 : 0,
              duration: Motion.medium,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.asset});
  final AssetEntity asset;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _ctrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // May download from iCloud first.
      final file = await widget.asset.file;
      if (file == null) throw StateError('No file');
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.play();
      setState(() => _ctrl = ctrl);
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

  void _toggle() {
    final c = _ctrl;
    if (c == null) return;
    HapticFeedback.selectionClick();
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: cardImageFor(widget.asset), fit: BoxFit.contain),
          if (c != null)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            ),
          if (c == null && !_failed)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          if (_failed)
            Center(
              child: Text(
                'Could not play this video',
                style: AppText.label(color: Colors.white70),
              ),
            ),
          if (c != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) => Stack(
                children: [
                  Center(
                    child: AnimatedOpacity(
                      opacity: v.isPlaying ? 0 : 1,
                      duration: Motion.fast,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 46,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 110,
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Text(
                            formatDuration(v.position),
                            style: AppText.caption(color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: VideoProgressIndicator(
                                c,
                                allowScrubbing: true,
                                padding: EdgeInsets.zero,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white24,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatDuration(v.duration),
                            style: AppText.caption(color: Colors.white70),
                          ),
                        ],
                      ),
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
