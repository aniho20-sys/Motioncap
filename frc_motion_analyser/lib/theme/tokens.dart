import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens — DESIGN SPEC.md §1 顏色.
///
/// 顏色語義鐵律：橙=主動/品牌、綠=好、黃=注意、紅=deficit/代償。唔可以混用。
class AppColors {
  AppColors._();

  static const ink = Color(0xFF0A0A0A);
  static const surface = Color(0xFF151515);
  static const surface2 = Color(0xFF1E1E1E);

  /// rgba(255,255,255,.08) — borders / dividers / Range Arc base ring.
  static const line = Color(0x14FFFFFF);

  static const orange = Color(0xFFFF5C00);

  /// rgba(255,92,0,.14) — coach cue background.
  static const orangeSoft = Color(0x24FF5C00);

  static const good = Color(0xFF4ADE80);
  static const warn = Color(0xFFFFB020);
  static const deficit = Color(0xFFFF3B5C);

  static const text = Color(0xFFF5F2EE);
  static const muted = Color(0xFF8A8580);

  /// rgba(255,255,255,.08) — Range Arc base ring (alias of [line]).
  static const ringBase = line;

  /// rgba(255,255,255,.28) — Range Arc PROM reference line.
  static const promLine = Color(0x47FFFFFF);

  /// rgba(255,59,92,.35) — Range Arc deficit arc.
  static const deficitArc = Color(0x59FF3B5C);

  /// rgba(74,222,128,.3) — Range Arc deficit arc once deficit < 5° (achieved).
  static const deficitAchieved = Color(0x4D4ADE80);
}

/// Typography tokens — DESIGN SPEC.md §1 字體.
///
/// 規則：任何量化數據（角度、百分比、計數）一律 DM Mono ([AppText.data]).
class AppText {
  AppText._();

  /// Display — Space Grotesk 600/700. Page titles, greetings.
  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  /// Body — Inter 400-700. General UI text.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  /// Data — DM Mono 400/500. All numbers, angles, time, labels.
  static TextStyle data({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
      letterSpacing: letterSpacing,
    );
  }
}

/// Shape tokens — DESIGN SPEC.md §1 形狀.
class AppRadius {
  AppRadius._();

  static const double card = 18;
  static const double drawerTop = 26;
  static const double button = 14;
  static const double chip = 999;
}

/// Spacing / layout tokens — DESIGN SPEC.md §1 形狀.
class AppSpacing {
  AppSpacing._();

  static const double pageHorizontal = 20;
  static const double tabBarHeight = 78;
}

/// Animation tokens — DESIGN SPEC.md §8 實作指引.
class AppDurations {
  AppDurations._();

  /// 數值變化動畫：300ms ease-out.
  static const Duration value = Duration(milliseconds: 300);
  static const Curve valueCurve = Curves.easeOut;
}
