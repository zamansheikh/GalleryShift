import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../models/deck.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../widgets/asset_card.dart';
import '../widgets/common.dart';
import '../widgets/video_view.dart';

/// Full-screen look at one asset. Pops with a [Decision] when [showActions]
/// is set and the user picks one.
class ViewerScreen extends StatelessWidget {
  const ViewerScreen({
    super.key,
    required this.asset,
    this.showActions = false,
    this.startAt = Duration.zero,
  });

  final AssetEntity asset;
  final bool showActions;

  /// Where a video starts, e.g. continuing from the swipe card.
  final Duration startAt;

  static Route<Decision> route(
    AssetEntity asset, {
    bool showActions = false,
    Duration startAt = Duration.zero,
  }) {
    return PageRouteBuilder<Decision>(
      opaque: false,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.fast,
      pageBuilder: (_, _, _) => ViewerScreen(
        asset: asset,
        showActions: showActions,
        startAt: startAt,
      ),
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
            if (isVideo)
              VideoView(
                asset: asset,
                startAt: startAt,
                topInset: MediaQuery.paddingOf(context).top + 64,
                bottomInset:
                    MediaQuery.paddingOf(context).bottom +
                    (showActions ? 82 : 12),
              )
            else
              _PhotoView(asset: asset),
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
