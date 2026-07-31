import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// First screen shown on launch. Displays the brand mark with a
/// restrained, premium fade/scale sequence — no spinner, no progress
/// bar chatter — then hands off to the dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(AppConstants.splashDuration, _goToDashboard);
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppConstants.animMedium,
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const DashboardScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark — geometric spider glyph rendered from
            // primitives so no external asset dependency is required.
            _SpiderMark()
                .animate()
                .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.82, 0.82),
                  end: const Offset(1, 1),
                  duration: 900.ms,
                  curve: Curves.easeOutCubic,
                ),

            const SizedBox(height: AppConstants.spaceXl),

            Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: AppColors.textPrimary,
                  ),
                )
                .animate(delay: 350.ms)
                .fadeIn(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms, curve: Curves.easeOutCubic),

            const SizedBox(height: AppConstants.spaceSm),

            Text(
                  AppConstants.appTagline,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                )
                .animate(delay: 600.ms)
                .fadeIn(duration: 700.ms),
          ],
        ),
      ),
    );
  }
}

/// A minimal geometric spider glyph — eight legs radiating from a
/// central body — rendered with `CustomPaint` so the brand mark has
/// zero external asset dependencies and stays crisp at any size.
class _SpiderMark extends StatelessWidget {
  const _SpiderMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: CustomPaint(painter: _SpiderMarkPainter()),
    );
  }
}

class _SpiderMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyRadius = size.width * 0.16;

    final ringPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, size.width * 0.46, ringPaint);

    final legPaint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    // 8 legs, evenly distributed, each with a single "knee" bend to
    // read clearly as a spider silhouette rather than a plain asterisk.
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final kneeRadius = size.width * 0.30;
      final footRadius = size.width * 0.48;

      final kneeAngle = angle + 0.28;
      final knee = Offset(
        center.dx + kneeRadius * math.cos(kneeAngle),
        center.dy + kneeRadius * math.sin(kneeAngle),
      );
      final foot = Offset(
        center.dx + footRadius * math.cos(angle),
        center.dy + footRadius * math.sin(angle),
      );
      final hip = Offset(
        center.dx + bodyRadius * 0.9 * math.cos(angle),
        center.dy + bodyRadius * 0.9 * math.sin(angle),
      );

      final path = Path()
        ..moveTo(hip.dx, hip.dy)
        ..quadraticBezierTo(knee.dx, knee.dy, foot.dx, foot.dy);
      canvas.drawPath(path, legPaint);
    }

    final bodyGlow = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, bodyRadius, bodyGlow);

    final bodyPaint = Paint()..color = AppColors.cyan;
    canvas.drawCircle(center, bodyRadius, bodyPaint);

    final bodyCorePaint = Paint()..color = AppColors.charcoal;
    canvas.drawCircle(center, bodyRadius * 0.42, bodyCorePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
