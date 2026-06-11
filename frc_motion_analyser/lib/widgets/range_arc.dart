import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Returns the fraction of [normative] represented by [value], clamped to
/// the `[0, 1]` range.
///
/// A non-positive [normative] (no reference data) yields `0`.
double arcFraction(double value, double normative) {
  if (normative <= 0) return 0;
  final fraction = value / normative;
  if (fraction.isNaN) return 0;
  return fraction.clamp(0.0, 1.0);
}

/// Signature "Range Arc" component — DESIGN SPEC.md §2.
///
/// Draws, from the inside out: a base ring, the AROM arc (orange), the
/// passive deficit arc (red, or green once the deficit is "achieved"
/// i.e. < 5°), and a PROM reference line — with the active value shown in
/// the centre.
class RangeArc extends StatefulWidget {
  const RangeArc({
    super.key,
    required this.arom,
    required this.prom,
    required this.normative,
    required this.label,
    this.size = 104,
  });

  /// Active range of motion, in degrees.
  final double arom;

  /// Passive range of motion, in degrees.
  final double prom;

  /// Normative ROM for this joint/movement, in degrees (from the FRC
  /// knowledge base ROM table).
  final double normative;

  /// Label shown under the main value, e.g. "HIP FLEX".
  final String label;

  /// Overall widget size (square), in logical pixels. Defaults to the
  /// 104px reference size used in `frc-motion-ui-v3.html`.
  final double size;

  @override
  State<RangeArc> createState() => _RangeArcState();
}

class _RangeArcState extends State<RangeArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _aromPromAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.value,
    );
    _aromPromAnimation = AlwaysStoppedAnimation(
      Offset(widget.arom, widget.prom),
    );
  }

  @override
  void didUpdateWidget(covariant RangeArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arom != widget.arom || oldWidget.prom != widget.prom) {
      final current = _aromPromAnimation.value;
      _aromPromAnimation = Tween<Offset>(
        begin: current,
        end: Offset(widget.arom, widget.prom),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: AppDurations.valueCurve,
        ),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final arom = _aromPromAnimation.value.dx;
          final prom = _aromPromAnimation.value.dy;
          return CustomPaint(
            painter: _RangeArcPainter(
              arom: arom,
              prom: prom,
              normative: widget.normative,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${arom.round()}°',
                    style: AppText.data(
                      size: widget.size * (18 / 104),
                      weight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: widget.size * (4 / 104)),
                  Text(
                    widget.label.toUpperCase(),
                    style: AppText.data(
                      size: widget.size * (9 / 104),
                      color: AppColors.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangeArcPainter extends CustomPainter {
  _RangeArcPainter({
    required this.arom,
    required this.prom,
    required this.normative,
  });

  final double arom;
  final double prom;
  final double normative;

  /// Reference viewBox size from `frc-motion-ui-v3.html` (`0 0 104 104`).
  static const double _refSize = 104;
  static const double _baseRadius = 42;
  static const double _baseStroke = 9;
  static const double _promRadius = 49;
  static const double _promStroke = 1.5;

  /// 12 o'clock, sweeping clockwise.
  static const double _startAngle = -math.pi / 2;

  /// Deficit < 5° is treated as "achieved" and shown in green.
  static const double _deficitAchievedThreshold = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _refSize;
    final center = Offset(size.width / 2, size.height / 2);

    final aromFrac = arcFraction(arom, normative);
    final promFrac = arcFraction(math.max(prom, arom), normative);
    final deficitFrac = (promFrac - aromFrac).clamp(0.0, 1.0);

    final baseRect = Rect.fromCircle(
      center: center,
      radius: _baseRadius * scale,
    );
    final promRect = Rect.fromCircle(
      center: center,
      radius: _promRadius * scale,
    );

    // 1. Base ring.
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _baseStroke * scale
      ..color = AppColors.ringBase;
    canvas.drawCircle(center, _baseRadius * scale, basePaint);

    // 2. Deficit arc — drawn before the AROM arc so the AROM round cap
    // sits on top at the seam between the two arcs.
    if (deficitFrac > 0) {
      final deficitDeg = prom - arom;
      final deficitPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _baseStroke * scale
        ..strokeCap = StrokeCap.round
        ..color = deficitDeg < _deficitAchievedThreshold
            ? AppColors.deficitAchieved
            : AppColors.deficitArc;
      canvas.drawArc(
        baseRect,
        _startAngle + aromFrac * 2 * math.pi,
        deficitFrac * 2 * math.pi,
        false,
        deficitPaint,
      );
    }

    // 3. AROM arc.
    if (aromFrac > 0) {
      final aromPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _baseStroke * scale
        ..strokeCap = StrokeCap.round
        ..color = AppColors.orange;
      canvas.drawArc(
        baseRect,
        _startAngle,
        aromFrac * 2 * math.pi,
        false,
        aromPaint,
      );
    }

    // 4. PROM reference line.
    if (promFrac > 0) {
      final promPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _promStroke * scale
        ..color = AppColors.promLine;
      canvas.drawArc(
        promRect,
        _startAngle,
        promFrac * 2 * math.pi,
        false,
        promPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RangeArcPainter oldDelegate) {
    return oldDelegate.arom != arom ||
        oldDelegate.prom != prom ||
        oldDelegate.normative != normative;
  }
}
