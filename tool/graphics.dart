// Shared drawing helpers for the generated marketing images
// (showcase_test.dart, store_graphics_test.dart).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const bg = Color(0xFF0A0A0F);
const violet = Color(0xFF8B7BFF);
const pink = Color(0xFFFF6BB5);
const keepGreen = Color(0xFF2FD89A);
const deleteRed = Color(0xFFFF4D67);
const textDim = Color(0xFFB4B4C4);

/// Registers the bundled font so [drawText] renders real glyphs in tests.
Future<void> loadFont() async {
  final font = File('assets/fonts/PlusJakartaSans.ttf').readAsBytesSync();
  await (FontLoader(
    'Jakarta',
  )..addFont(Future.value(ByteData.sublistView(font)))).load();
}

Future<ui.Image> decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Dark backdrop with the brand's violet and pink glows. Each glow is
/// (centre as a fraction of the canvas, radius as a fraction of its width,
/// colour, strength).
void drawBackground(
  Canvas c,
  Size size, {
  List<(Offset, double, Color, double)> glows = const [
    (Offset(0.16, 0.09), 0.40, violet, 0.32),
    (Offset(0.80, 0.96), 0.44, pink, 0.22),
    (Offset(0.70, 0.22), 0.30, violet, 0.18),
  ],
}) {
  c.drawRect(Offset.zero & size, Paint()..color = bg);
  for (final (at, radius, color, alpha) in glows) {
    final centre = Offset(at.dx * size.width, at.dy * size.height);
    final r = radius * size.width;
    c.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
  }
}

/// Draws [text] and returns the height it took.
double drawText(
  Canvas c,
  String text, {
  required double x,
  required double y,
  required double size,
  required double width,
  FontWeight weight = FontWeight.w600,
  Color color = Colors.white,
  double spacing = 0,
  double height = 1.15,
  TextAlign align = TextAlign.left,
}) {
  final b =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(fontFamily: 'Jakarta', textAlign: align),
        )
        ..pushStyle(
          ui.TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            fontFamily: 'Jakarta',
            fontVariations: [ui.FontVariation.weight(weight.value.toDouble())],
            letterSpacing: spacing,
            height: height,
          ),
        )
        ..addText(text);
  final p = b.build()..layout(ui.ParagraphConstraints(width: width));
  c.drawParagraph(p, Offset(x, y));
  return p.height;
}

/// A phone showing [shot], [height] tall (screen only), centred on [center].
void drawPhone(
  Canvas c,
  ui.Image shot, {
  required Offset center,
  required double height,
  double degrees = 0,
}) {
  final screenW = height * shot.width / shot.height;
  final bezel = screenW * 0.028;
  final screen = Rect.fromCenter(
    center: Offset.zero,
    width: screenW,
    height: height,
  );
  final body = screen.inflate(bezel);
  final radius = screenW * 0.11;

  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(degrees * math.pi / 180);

  final bodyR = RRect.fromRectAndRadius(body, Radius.circular(radius + bezel));
  c.drawRRect(
    bodyR.shift(Offset(0, screenW * 0.07)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, screenW * 0.11),
  );
  c.drawRRect(bodyR, Paint()..color = const Color(0xFF1A1A22));
  c.drawRRect(
    bodyR,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, screenW * 0.006)
      ..color = Colors.white.withValues(alpha: 0.16),
  );
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

/// [image] clipped to a rounded square.
void drawIcon(Canvas c, ui.Image image, Rect rect) {
  c.save();
  c.clipRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.23)),
  );
  c.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

Future<void> savePng(
  ui.PictureRecorder recorder,
  int width,
  int height,
  String path,
) async {
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
}
