import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// The app's crest mark: a jewel-cut diamond body with eight straight,
/// tapered dagger legs, rendered with `CustomPaint`. This is the one
/// logo asset for the whole app — the splash screen, the dashboard
/// header, and the launcher icon are all generated from this same
/// design, so the brand mark is consistent everywhere it appears.
///
/// Deliberately built from a different visual grammar (straight
/// tapered facets, gem-cut body, no rounded "knee" bends) than any
/// existing spider mark, so it reads as this app's own crest.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 112, this.glow = true});

  final double size;

  /// Whether to draw the soft radial glow behind the mark. Turn this
  /// off when placing the logo somewhere already glowing/busy (e.g. a
  /// small app-bar mark) so it doesn't double up.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter(glow: glow)),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  _AppLogoPainter({required this.glow});
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final legPaint = Paint()..style = PaintingStyle.fill;

    // 8 straight tapered legs — each a thin filled triangle from the
    // body out to a point — rather than a stroked, knee-bent line.
    // This "dagger" silhouette plus the gem-cut body below is the
    // signature that makes this an original mark.
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + (math.pi / 8);
      final tipRadius = size.width * 0.49;
      final baseRadius = size.width * 0.155;
      final spread = 0.11;

      final tip = Offset(
        center.dx + tipRadius * math.cos(angle),
        center.dy + tipRadius * math.sin(angle),
      );
      final baseA = Offset(
        center.dx + baseRadius * math.cos(angle - spread),
        center.dy + baseRadius * math.sin(angle - spread),
      );
      final baseB = Offset(
        center.dx + baseRadius * math.cos(angle + spread),
        center.dy + baseRadius * math.sin(angle + spread),
      );
      final mid = Offset(
        center.dx + (tipRadius * 0.55) * math.cos(angle),
        center.dy + (tipRadius * 0.55) * math.sin(angle),
      );

      final legPath = Path()
        ..moveTo(baseA.dx, baseA.dy)
        ..lineTo(mid.dx + (baseA.dx - mid.dx) * 0.25, mid.dy + (baseA.dy - mid.dy) * 0.25)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(mid.dx + (baseB.dx - mid.dx) * 0.25, mid.dy + (baseB.dy - mid.dy) * 0.25)
        ..lineTo(baseB.dx, baseB.dy)
        ..close();

      legPaint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment(math.cos(angle).toDouble(), math.sin(angle).toDouble()),
        colors: [AppColors.cyan, AppColors.cyan.withValues(alpha: 0.55)],
      ).createShader(legPath.getBounds());
      canvas.drawPath(legPath, legPaint);
    }

    // Gem-cut diamond body (rotated square with faceted highlight)
    // instead of a plain filled circle.
    final bodyRadius = size.width * 0.175;

    if (glow) {
      final bodyGlow = Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(center, bodyRadius * 1.1, bodyGlow);
    }

    final diamond = Path()
      ..moveTo(center.dx, center.dy - bodyRadius)
      ..lineTo(center.dx + bodyRadius, center.dy)
      ..lineTo(center.dx, center.dy + bodyRadius)
      ..lineTo(center.dx - bodyRadius, center.dy)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.cyan, AppColors.amethyst],
      ).createShader(diamond.getBounds());
    canvas.drawPath(diamond, bodyPaint);

    // Single facet highlight line across the gem for a cut-stone
    // glint rather than a flat fill.
    final facetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.01);
    canvas.drawLine(
      Offset(center.dx, center.dy - bodyRadius * 0.85),
      Offset(center.dx + bodyRadius * 0.55, center.dy - bodyRadius * 0.1),
      facetPaint,
    );

    final core = Paint()..color = AppColors.charcoal;
    canvas.drawCircle(center, bodyRadius * 0.3, core);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) => oldDelegate.glow != glow;
}
