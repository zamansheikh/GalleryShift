// Renders the Google Play graphics into store/play/ from the device captures
// in store/play/captures/:
//
//   feature-graphic.png                 1024 x 500 (drawn at 2x)
//   screenshots/screenshot-01..08.png   1242 x 2208
//
//   flutter test tool/store_graphics_test.dart && tool/finish_store_graphics.sh
//
// The second step is needed: these come out as 32-bit PNGs, and Play accepts
// only 24-bit ones with no alpha channel.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'graphics.dart';

const _captures = 'store/play/captures';

/// (capture, headline, line under it) in listing order. Play shows the first
/// three without scrolling, so they carry the idea on their own.
const _screens = [
  (
    'swipe-keep',
    'Swipe your gallery clean',
    'Right to keep. One photo at a time.',
  ),
  ('swipe-delete', 'Left to let it go', 'Nothing is deleted until you say so.'),
  (
    'home',
    'Pick up where you left off',
    'Decks by month, screenshots, videos and more.',
  ),
  (
    'video-card',
    'Videos play right on the card',
    'Scrub, skip 10 seconds, or hold for 4× speed.',
  ),
  (
    'review-bin',
    'Review before anything goes',
    'Tap to rescue a photo, then delete the rest.',
  ),
  (
    'space-freed',
    'See the space you got back',
    'Every delete adds to your total.',
  ),
  (
    'storage-cleanup',
    'Clear junk and empty folders',
    'Find large files and old documents too.',
  ),
  (
    'home-light',
    'Light or dark, always private',
    'No account, no ads. Photos stay on your phone.',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFont);

  test('phone screenshots', () async {
    const w = 1242.0, h = 2208.0;
    for (var i = 0; i < _screens.length; i++) {
      final (capture, headline, sub) = _screens[i];
      final shot = await decode('$_captures/$capture.jpg');
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      drawBackground(
        c,
        const Size(w, h),
        glows: const [
          (Offset(0.10, 0.04), 0.70, violet, 0.36),
          (Offset(0.95, 0.60), 0.70, pink, 0.20),
        ],
      );

      var y = 118.0;
      y += drawText(
        c,
        headline,
        x: 70,
        y: y,
        width: w - 140,
        size: 80,
        weight: FontWeight.w800,
        spacing: -2.2,
        height: 1.1,
        align: TextAlign.center,
      );
      drawText(
        c,
        sub,
        x: 90,
        y: y + 22,
        width: w - 180,
        size: 38,
        color: textDim,
        height: 1.3,
        align: TextAlign.center,
      );

      // Large enough to read in the listing; it runs just past the bottom
      // edge, which only costs the system gesture bar.
      const phoneH = 1790.0;
      drawPhone(
        c,
        shot,
        center: const Offset(w / 2, 430 + phoneH / 2),
        height: phoneH,
      );

      await savePng(
        recorder,
        w.toInt(),
        h.toInt(),
        'store/play/screenshots/screenshot-${(i + 1).toString().padLeft(2, '0')}.png',
      );
    }
  });

  test('feature graphic', () async {
    // Logical 1024 x 500, drawn at 2x and scaled down afterwards for clean
    // edges.
    const w = 1024.0, h = 500.0, scale = 2.0;
    final icon = await decode('assets/icon/icon.png');
    final home = await decode('$_captures/home.jpg');
    final keep = await decode('$_captures/swipe-keep.jpg');
    final bin = await decode('$_captures/review-bin.jpg');

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder)..scale(scale);
    drawBackground(
      c,
      const Size(w, h),
      glows: const [
        (Offset(0.10, 0.10), 0.42, violet, 0.36),
        (Offset(0.86, 0.95), 0.46, pink, 0.24),
        (Offset(0.66, 0.20), 0.30, violet, 0.20),
      ],
    );

    drawPhone(c, bin, center: const Offset(962, 372), height: 500, degrees: 8);
    drawPhone(
      c,
      home,
      center: const Offset(624, 372),
      height: 500,
      degrees: -8,
    );
    drawPhone(c, keep, center: const Offset(792, 340), height: 560);

    const left = 58.0;
    drawIcon(c, icon, const Rect.fromLTWH(left, 112, 84, 84));
    var y = 218.0;
    y += drawText(
      c,
      'GalleryShift',
      x: left,
      y: y,
      width: 460,
      size: 58,
      weight: FontWeight.w800,
      spacing: -1.8,
    );
    y += 8;
    y += drawText(
      c,
      'Swipe your gallery clean.',
      x: left,
      y: y,
      width: 460,
      size: 26,
      color: textDim,
      spacing: -0.4,
    );
    y += 22;
    for (final (color, line) in [
      (keepGreen, 'Right to keep'),
      (deleteRed, 'Left to delete'),
    ]) {
      c.drawCircle(Offset(left + 7, y + 12), 6, Paint()..color = color);
      y +=
          drawText(
            c,
            line,
            x: left + 24,
            y: y,
            width: 400,
            size: 19,
            color: const Color(0xFFE6E6EE),
          ) +
          8;
    }

    await savePng(
      recorder,
      (w * scale).toInt(),
      (h * scale).toInt(),
      'store/play/feature-graphic.png',
    );
  });
}
