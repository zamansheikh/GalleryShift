// Renders docs/showcase.jpg — the README banner — from the screenshots in
// docs/screenshots/ and the app icon.
//
//   flutter test tool/showcase_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _w = 2400.0, _h = 1300.0;
const _bg = Color(0xFF0A0A0F);
const _violet = Color(0xFF8B7BFF);
const _pink = Color(0xFFFF6BB5);
const _keep = Color(0xFF2FD89A);
const _delete = Color(0xFFFF4D67);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate showcase banner', () async {
    final font = File('assets/fonts/PlusJakartaSans.ttf').readAsBytesSync();
    await (FontLoader('Jakarta')
          ..addFont(Future.value(ByteData.sublistView(font))))
        .load();

    final icon = await _decode('assets/icon/icon.png');
    final home = await _decode('docs/screenshots/home.jpg');
    final keep = await _decode('docs/screenshots/swipe-keep.jpg');
    final bin = await _decode('docs/screenshots/review-bin.jpg');

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    _background(c);
    _copy(c, icon);
    _phone(c, bin, center: const Offset(2110, 690), height: 1000, degrees: 7);
    _phone(c, home, center: const Offset(1320, 690), height: 1000, degrees: -7);
    _phone(c, keep, center: const Offset(1715, 650), height: 1120, degrees: 0);

    final image = await recorder.endRecording().toImage(_w.toInt(), _h.toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('docs/showcase.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void _background(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, _w, _h);
  c.drawRect(rect, Paint()..color = _bg);
  void glow(Offset at, double r, Color color, double alpha) {
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }

  glow(const Offset(380, 120), 900, _violet, 0.32);
  glow(const Offset(1900, 1250), 1000, _pink, 0.22);
  glow(const Offset(1700, 300), 700, _violet, 0.18);
}

void _copy(Canvas c, ui.Image icon) {
  const left = 150.0;
  // App icon.
  final iconRect = const Rect.fromLTWH(left, 250, 190, 190);
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(iconRect, const Radius.circular(44)));
  c.drawImageRect(
    icon,
    Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
    iconRect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();

  var y = 500.0;
  y += _text(c, 'GalleryShift', left, y, 118, FontWeight.w800, Colors.white,
      spacing: -3.5);
  y += 10;
  y += _text(c, 'Swipe your gallery clean.', left, y, 54, FontWeight.w600,
      const Color(0xFFB4B4C4),
      spacing: -1);
  y += 60;
  for (final (color, line) in [
    (_keep, 'Swipe right to keep'),
    (_delete, 'Swipe left to delete'),
    (_violet, 'Review the bin before anything goes'),
    (_pink, 'Private: nothing leaves your phone'),
  ]) {
    c.drawCircle(Offset(left + 12, y + 27), 11, Paint()..color = color);
    y += _text(c, line, left + 44, y, 38, FontWeight.w600,
            const Color(0xFFE6E6EE)) +
        18;
  }
}

double _text(
  Canvas c,
  String text,
  double x,
  double y,
  double size,
  FontWeight weight,
  Color color, {
  double spacing = 0,
}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Jakarta'))
    ..pushStyle(ui.TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      fontFamily: 'Jakarta',
      fontVariations: [ui.FontVariation.weight(weight.value.toDouble())],
      letterSpacing: spacing,
    ))
    ..addText(text);
  final p = b.build()..layout(const ui.ParagraphConstraints(width: 1100));
  c.drawParagraph(p, Offset(x, y));
  return p.height;
}

void _phone(
  Canvas c,
  ui.Image shot, {
  required Offset center,
  required double height,
  required double degrees,
}) {
  final screenH = height;
  final screenW = screenH * shot.width / shot.height;
  const bezel = 16.0;
  final screen = Rect.fromCenter(
    center: Offset.zero,
    width: screenW,
    height: screenH,
  );
  final body = screen.inflate(bezel);
  final radius = screenW * 0.11;

  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(degrees * math.pi / 180);

  // Shadow.
  c.drawRRect(
    RRect.fromRectAndRadius(body.shift(const Offset(0, 40)),
        Radius.circular(radius + bezel)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
  );
  // Body.
  final bodyR = RRect.fromRectAndRadius(body, Radius.circular(radius + bezel));
  c.drawRRect(bodyR, Paint()..color = const Color(0xFF1A1A22));
  c.drawRRect(
    bodyR,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.14),
  );
  // Screen.
  c.save();
  c.clipRRect(RRect.fromRectAndRadius(screen, Radius.circular(radius)));
  c.drawImageRect(
    shot,
    Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
    screen,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
  c.restore();
}
