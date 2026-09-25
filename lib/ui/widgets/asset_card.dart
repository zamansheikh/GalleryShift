import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../data/gallery_repository.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import 'video_view.dart';

/// Image provider for a full card. Shared with precaching so both hit the
/// same cache entry.
ImageProvider cardImageFor(AssetEntity a) {
  const maxSide = 1440;
  final w = a.orientatedWidth, h = a.orientatedHeight;
  ThumbnailSize size;
  if (w <= 0 || h <= 0) {
    size = const ThumbnailSize.square(1200);
  } else {
    final scale = math.min(1.0, maxSide / math.max(w, h));
    size = ThumbnailSize((w * scale).round(), (h * scale).round());
  }
  return AssetEntityImageProvider(a, isOriginal: false, thumbnailSize: size);
}

ImageProvider backdropImageFor(AssetEntity a) => AssetEntityImageProvider(
  a,
  isOriginal: false,
  thumbnailSize: const ThumbnailSize.square(96),
);

class AssetCard extends StatelessWidget {
  const AssetCard({
    super.key,
    required this.asset,
    required this.repo,
    this.isScreenshot = false,
    this.depth = 0,
    this.videoFocus,
    this.muted,
    this.onFullscreen,
  });

  final AssetEntity asset;
  final GalleryRepository repo;
  final bool isScreenshot;

  /// Position in the deck; videos play only at depth 0.
  final int depth;

  /// For videos: whether playback is allowed right now, and the shared mute
  /// setting. Without them a video card shows its poster only.
  final ValueListenable<bool>? videoFocus;
  final ValueNotifier<bool>? muted;
  final void Function(Duration position)? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cardAspect = c.maxWidth / c.maxHeight;
        final w = asset.orientatedWidth, h = asset.orientatedHeight;
        final aspect = (w > 0 && h > 0) ? w / h : cardAspect;
        // Fill the card when the shapes are close; otherwise show the whole
        // picture on a blurred copy of itself so nothing important is cropped.
        final fill = (aspect / cardAspect - 1).abs() < 0.22;
        final isVideo = asset.type == AssetType.video;
        final playable = isVideo && videoFocus != null && muted != null;
        // Scrim and date/size info. A playing video puts its controls
        // underneath, so the info sits above them.
        final overlay = IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _BottomScrim(),
              Positioned(
                left: 22,
                right: 22,
                bottom: playable ? kVideoControlsHeight + 24 : 22,
                child: _CardInfo(
                  asset: asset,
                  repo: repo,
                  isScreenshot: isScreenshot,
                ),
              ),
            ],
          ),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: ColoredBox(
              color: p.surfaceHigh,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!fill) ...[
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Image(
                        image: backdropImageFor(asset),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                    ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
                  ],
                  _FadeInImage(
                    image: cardImageFor(asset),
                    fit: fill ? BoxFit.cover : BoxFit.contain,
                  ),
                  if (playable)
                    CardVideo(
                      asset: asset,
                      depth: depth,
                      fit: fill ? BoxFit.cover : BoxFit.contain,
                      focus: videoFocus!,
                      muted: muted!,
                      onFullscreen: onFullscreen,
                      overlay: overlay,
                    )
                  else ...[
                    overlay,
                    if (isVideo) const Center(child: _PlayBadge()),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FadeInImage extends StatelessWidget {
  const _FadeInImage({required this.image, required this.fit});
  final ImageProvider image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: Motion.medium,
          child: child,
        );
      },
      errorBuilder: (context, _, _) => Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: Palette.of(context).textFaint,
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.38,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x8C000000)],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    // Plain fills, not BackdropFilter: this sits on a card that moves every
    // frame during a drag.
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 40,
        color: Colors.white,
      ),
    );
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({
    required this.asset,
    required this.repo,
    required this.isScreenshot,
  });

  final AssetEntity asset;
  final GalleryRepository repo;
  final bool isScreenshot;

  @override
  Widget build(BuildContext context) {
    final isVideo = asset.type == AssetType.video;
    final cached = repo.cachedSize(asset.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatDate(asset.createDateTime),
          style:
              AppText.w(
                26,
                FontWeight.w800,
                spacing: -0.6,
                color: Colors.white,
              ).copyWith(
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 12),
                ],
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isVideo)
              _Chip(
                icon: Icons.videocam_rounded,
                label: formatDuration(asset.videoDuration),
              )
            else if (isScreenshot)
              const _Chip(icon: Icons.screenshot_rounded, label: 'Screenshot')
            else
              const _Chip(icon: Icons.photo_rounded, label: 'Photo'),
            FutureBuilder<int>(
              initialData: cached,
              future: cached == null ? repo.fileSize(asset) : null,
              builder: (context, snap) => AnimatedSwitcher(
                duration: Motion.fast,
                child: (snap.data ?? 0) > 0
                    ? _Chip(
                        icon: Icons.sd_storage_rounded,
                        label: formatBytes(snap.data!),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption(color: Colors.white)),
        ],
      ),
    );
  }
}
