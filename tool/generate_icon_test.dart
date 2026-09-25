// Renders the app icon PNGs into assets/icon/.
//
//   flutter test tool/generate_icon_test.dart
//   dart run flutter_launcher_icons
//
// Painted with dart:ui so the icon uses the app's own palette and needs no
// external design tools.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _violet = Color(0xFF7B6BFF);
const _pink = Color(0xFFFF5FA8);

enum _Layer { full, foreground, background, monochrome }

void main() {
  test('generate app icon', () async {
    final dir = Directory('assets/icon')..createSync(recursive: true);
    for (final (layer, name) in [
      (_Layer.full, 'icon.png'),
      (_Layer.foreground, 'icon_foreground.png'),
      (_Layer.background, 'icon_background.png'),
      (_Layer.monochrome, 'icon_monochrome.png'),
    ]) {
      final bytes = await _render(layer);
      File('${dir.path}/$name').writeAsBytesSync(bytes);
    }
  });
}

Future<List<int>> _render(_Layer layer) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const s = _size;

  if (layer == _Layer.full || layer == _Layer.background) {
    _paintBackground(canvas);
  }
  if (layer != _Layer.background) {
    // Adaptive layers are drawn at full size: flutter_launcher_icons insets
    // them by 16%, which keeps the cards inside Android's safe zone.
    _paintCards(canvas, mono: layer == _Layer.monochrome);
  }

  final image = await recorder.endRecording().toImage(s.toInt(), s.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void _paintBackground(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_violet, _pink],
      ).createShader(rect),
  );
  // Soft light from the top left.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.7, -0.8),
        radius: 1.0,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect),
  );
}

void _paintCards(Canvas canvas, {required bool mono}) {
  const s = _size;
  const w = s * 0.40, h = s * 0.52;
  const center = Offset(s * 0.5, s * 0.515);
  final card = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: w, height: h),
    const Radius.circular(s * 0.065),
  );

  void placed(double dx, double dy, double degrees, void Function() paint) {
    canvas.save();
    canvas.translate(center.dx + dx, center.dy + dy);
    canvas.rotate(degrees * math.pi / 180);
    paint();
    canvas.restore();
  }

  // Back card, tilted left.
  placed(-s * 0.075, s * 0.01, -13, () {
    canvas.drawRRect(
      card,
      Paint()..color = Colors.white.withValues(alpha: mono ? 0.55 : 0.4),
    );
  });

  // Front card, tilted right as if mid-swipe.
  placed(s * 0.06, -s * 0.01, 9, () {
    if (!mono) {
      canvas.drawRRect(
        card.shift(const Offset(0, s * 0.02)),
        Paint()
          ..color = const Color(0xFF3A1D6E).withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, s * 0.03),
      );
    }
    canvas.drawRRect(card, Paint()..color = Colors.white);

    // The "photo": a framed landscape with sun and mountains.
    final photo = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -w / 2 + s * 0.035,
        -h / 2 + s * 0.035,
        w - s * 0.07,
        h * 0.62,
      ),
      const Radius.circular(s * 0.035),
    );
    final r = photo.outerRect;
    final ink = mono
        ? (Paint()..blendMode = BlendMode.clear)
        : (Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_violet, _pink],
            ).createShader(r));

    canvas.save();
    canvas.clipRRect(photo);
    if (!mono) {
      canvas.drawRect(r, Paint()..color = const Color(0xFFF1EDFF));
    }
    canvas.drawCircle(
      Offset(r.left + r.width * 0.70, r.top + r.height * 0.30),
      r.width * 0.12,
      ink,
    );
    final mountains = Path()
      ..moveTo(r.left - r.width * 0.05, r.bottom)
      ..lineTo(r.left + r.width * 0.34, r.top + r.height * 0.42)
      ..lineTo(r.left + r.width * 0.56, r.top + r.height * 0.70)
      ..lineTo(r.left + r.width * 0.70, r.top + r.height * 0.56)
      ..lineTo(r.right + r.width * 0.05, r.bottom)
      ..close();
    canvas.drawPath(mountains, ink);
    canvas.restore();

    // Caption lines under the photo.
    final line = mono
        ? (Paint()..blendMode = BlendMode.clear)
        : (Paint()..color = const Color(0xFFD9D2FF));
    final top = r.bottom + s * 0.045;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, top, r.width * 0.62, s * 0.03),
        const Radius.circular(s * 0.015),
      ),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, top + s * 0.05, r.width * 0.38, s * 0.03),
        const Radius.circular(s * 0.015),
      ),
      line,
    );
  });
}
