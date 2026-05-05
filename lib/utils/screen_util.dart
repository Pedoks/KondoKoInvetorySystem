import 'package:flutter/material.dart';


class SU {
  SU._(); // prevent instantiation

  static double _w       = 400;
  static double _h       = 800;
  static double _topPad  = 0;
  static double _botPad  = 0;

  /// Call once at the top of build()
  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _w      = mq.size.width;
    _h      = mq.size.height;
    _topPad = mq.padding.top;
    _botPad = mq.padding.bottom;
  }

  // ── Raw dimensions ──────────────────────────────────
  static double get w => _w;
  static double get h => _h;

  // ── Percentage helpers ──────────────────────────────
  /// Percentage of screen width  e.g. wp(0.04) = 4% of width
  static double wp(double pct) => _w * pct;

  /// Percentage of screen height e.g. hp(0.02) = 2% of height
  static double hp(double pct) => _h * pct;

  // ── Consistent spacing scale ────────────────────────
  /// ~6px  on a 400w screen
  static double get xs => _w * 0.015;

  /// ~10px on a 400w screen
  static double get sm => _w * 0.025;

  /// ~16px on a 400w screen  (default padding)
  static double get md => _w * 0.04;

  /// ~22px on a 400w screen
  static double get lg => _w * 0.055;

  /// ~32px on a 400w screen
  static double get xl => _w * 0.08;

  // ── Safe area ───────────────────────────────────────
  /// Top padding — accounts for notch, punch-hole, status bar
  static double get topSafe => _topPad;

  /// Bottom padding — accounts for gesture navigation bar
  static double get bottomSafe => _botPad;

  /// Full app bar container height (status bar + 60px bar)
  static double get appBarHeight => _topPad + 60;

  // ── Font sizes ──────────────────────────────────────
  static double get textXs  => _w * 0.028; // ~11px
  static double get textSm  => _w * 0.030; // ~12px
  static double get textMd  => _w * 0.035; // ~14px
  static double get textLg  => _w * 0.040; // ~16px
  static double get textXl  => _w * 0.055; // ~22px

  // ── Icon sizes ──────────────────────────────────────
  static double get iconSm  => _w * 0.045; // ~18px
  static double get iconMd  => _w * 0.055; // ~22px
  static double get iconLg  => _w * 0.07;  // ~28px

  // ── Card/component sizes ────────────────────────────
  /// Action card height (e.g. Add Item card)
  static double get actionCardH => _h * 0.12;

  /// Standard border radius
  static double get radius    => 12;
  static double get radiusLg  => 20;
  static double get radiusXl  => 24;
}