import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour tokens for one brightness. Read with `Palette.of(context)`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.stroke,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.keep,
    required this.delete,
    required this.accent,
    required this.accentAlt,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color stroke;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color keep;
  final Color delete;
  final Color accent;
  final Color accentAlt;

  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentAlt],
  );

  static const dark = Palette(
    bg: Color(0xFF0A0A0F),
    surface: Color(0xFF15151D),
    surfaceHigh: Color(0xFF1F1F2A),
    stroke: Color(0x14FFFFFF),
    text: Color(0xFFF5F5F8),
    textDim: Color(0xFFA2A2B3),
    textFaint: Color(0xFF6B6B7D),
    keep: Color(0xFF2FD89A),
    delete: Color(0xFFFF4D67),
    accent: Color(0xFF8B7BFF),
    accentAlt: Color(0xFFFF6BB5),
  );

  static const light = Palette(
    bg: Color(0xFFF4F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFECECF3),
    stroke: Color(0x14000000),
    text: Color(0xFF111118),
    textDim: Color(0xFF5E5E70),
    textFaint: Color(0xFF9A9AAB),
    keep: Color(0xFF12B981),
    delete: Color(0xFFF03A56),
    accent: Color(0xFF6C5CFF),
    accentAlt: Color(0xFFF0509E),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      stroke: l(stroke, other.stroke),
      text: l(text, other.text),
      textDim: l(textDim, other.textDim),
      textFaint: l(textFaint, other.textFaint),
      keep: l(keep, other.keep),
      delete: l(delete, other.delete),
      accent: l(accent, other.accent),
      accentAlt: l(accentAlt, other.accentAlt),
    );
  }
}

/// Text styles. The bundled font is variable, so every weight also sets the
/// `wght` axis — `fontWeight` alone does not move a variable font.
abstract final class AppText {
  static const family = 'Jakarta';

  static TextStyle w(
    double size,
    FontWeight weight, {
    double height = 1.25,
    double spacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      height: height,
      letterSpacing: spacing,
      color: color,
    );
  }

  static TextStyle display({Color? color}) =>
      w(34, FontWeight.w800, height: 1.08, spacing: -1.2, color: color);
  static TextStyle title({Color? color}) =>
      w(22, FontWeight.w700, height: 1.15, spacing: -0.5, color: color);
  static TextStyle headline({Color? color}) =>
      w(17, FontWeight.w700, spacing: -0.2, color: color);
  static TextStyle body({Color? color}) =>
      w(15, FontWeight.w500, height: 1.45, color: color);
  static TextStyle label({Color? color}) =>
      w(13, FontWeight.w600, spacing: 0.1, color: color);
  static TextStyle caption({Color? color}) =>
      w(12, FontWeight.w600, spacing: 0.2, color: color);
  static TextStyle overline({Color? color}) =>
      w(11, FontWeight.w800, spacing: 1.4, color: color);
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const ease = Curves.easeOutCubic;
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: AppText.family,
      scaffoldBackgroundColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
        surface: p.surface,
        primary: p.accent,
        error: p.delete,
      ),
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: p.text,
        displayColor: p.text,
        fontFamily: AppText.family,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceHigh,
        contentTextStyle: AppText.label(color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}
