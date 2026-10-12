// Renders docs/showcase.png, the README and website banner, from the
// screenshots in docs/screenshots/ and the app icon.
//
//   flutter test tool/showcase_test.dart && tool/finish_store_graphics.sh
//
// The second step turns it into docs/showcase.jpg.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'graphics.dart';

const _w = 2400.0, _h = 1300.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate showcase banner', () async {
    await loadFont();
    final icon = await decode('assets/icon/icon.png');
    final home = await decode('docs/screenshots/home.jpg');
    final keep = await decode('docs/screenshots/swipe-keep.jpg');
    final bin = await decode('docs/screenshots/review-bin.jpg');

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    drawBackground(c, const Size(_w, _h));

    const left = 150.0;
    drawIcon(c, icon, const Rect.fromLTWH(left, 250, 190, 190));
    var y = 500.0;
    y += drawText(
      c,
      'GalleryShift',
      x: left,
      y: y,
      width: 1100,
      size: 118,
      weight: FontWeight.w800,
      spacing: -3.5,
    );
    y += 10;
    y += drawText(
      c,
      'Swipe your gallery clean.',
      x: left,
      y: y,
      width: 1100,
      size: 54,
      color: textDim,
      spacing: -1,
    );
    y += 60;
    for (final (color, line) in [
      (keepGreen, 'Swipe right to keep'),
      (deleteRed, 'Swipe left to delete'),
      (violet, 'Review the bin before anything goes'),
      (pink, 'Private: nothing leaves your phone'),
    ]) {
      c.drawCircle(Offset(left + 12, y + 27), 11, Paint()..color = color);
      y +=
          drawText(
            c,
            line,
            x: left + 44,
            y: y,
            width: 1100,
            size: 38,
            color: const Color(0xFFE6E6EE),
          ) +
          18;
    }

    drawPhone(
      c,
      bin,
      center: const Offset(2110, 690),
      height: 1000,
      degrees: 7,
    );
    drawPhone(
      c,
      home,
      center: const Offset(1320, 690),
      height: 1000,
      degrees: -7,
    );
    drawPhone(c, keep, center: const Offset(1715, 650), height: 1120);

    await savePng(recorder, _w.toInt(), _h.toInt(), 'docs/showcase.png');
  });
}
