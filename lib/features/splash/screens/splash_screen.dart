import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../dashboard/screens/dashboard_screen.dart';

/// First screen shown on launch.
///
/// Complete redesign from the old flat-charcoal-background version:
/// the same "Royal Midnight" gradient + gold/amethyst glow used
/// everywhere else in the app, an original faceted spider-crest mark
/// (not the flat asterisk-style glyph the old splash used), a rotating
/// hairline halo, and a staged fade/scale/shimmer sequence — no
/// spinner, no progress bar chatter — before handing off to the
/// dashboard.
///
/// The native launch_background (Android/iOS) is set to the same
/// charcoal base color as [AppColors.charcoal], so this screen's first
/// frame lands on an already-matching background instead of the
/// jarring plain-black flash the app used to show before Flutter's
/// first frame painted.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _haloController;

  @override
  void initState() {
    super.initState();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    Future.delayed(AppConstants.splashDuration, _goToDashboard);
  }

  @override
  void dispose() {
    _haloController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    if (!mounted) return;
    // Defensive: navigation itself can't meaningfully throw here, but
    // guarding it means a mistimed hot-reload/route-table edit can
    // never turn "go to dashboard" into an uncaught crash on launch.
    try {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: AppConstants.animMedium,
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const DashboardScreen(),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Royal Midnight gradient base, matching every other screen
          // in the app instead of a flat black rectangle.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0A16),
                  Color(0xFF15122A),
                  Color(0xFF0B0A16),
                ],
              ),
            ),
          ),

          // Soft dual-tone glow — gold above, amethyst below — behind
          // the mark. This, plus the crest itself, is what reads as
          // "premium / royal" instead of a logo pasted on a dark
          // screen.
          Center(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withValues(alpha: 0.14),
                    AppColors.amethyst.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 1400.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 1900.ms,
                curve: Curves.easeOutCubic,
              ),

          // Slow-rotating hairline halo ring — ambient motion behind
          // the mark rather than on it, so it reads as "alive" without
          // competing with the wordmark reveal.
          Center(
            child: AnimatedBuilder(
              animation: _haloController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _haloController.value * 2 * math.pi,
                  child: child,
                );
              },
              child: SizedBox(
                width: 210,
                height: 210,
                child: CustomPaint(painter: _HaloPainter()),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 1200.ms),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The app's one crest mark — same asset the launcher
                // icon and dashboard header use, not a splash-only
                // graphic.
                const AppLogo(size: 112)
                    .animate()
                    .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                    .scale(
                      begin: const Offset(0.78, 0.78),
                      end: const Offset(1, 1),
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const SizedBox(height: AppConstants.spaceXl),

                // Hairline gold ornament above the wordmark — a small,
                // restrained flourish that reads as "crest" rather than
                // "app title", reinforcing the royal identity.
                Container(
                      width: 34,
                      height: 1.4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.cyan.withValues(alpha: 0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    )
                    .animate(delay: 250.ms)
                    .fadeIn(duration: 600.ms)
                    .scaleX(begin: 0, end: 1, duration: 600.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: AppConstants.spaceMd),

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
                    .slideY(begin: 0.25, end: 0, duration: 700.ms, curve: Curves.easeOutCubic)
                    // A single restrained gold sweep across the
                    // wordmark once it's settled — the "royal shimmer"
                    // touch — rather than a looping/gimmicky animation.
                    .shimmer(
                      delay: 1100.ms,
                      duration: 1400.ms,
                      color: AppColors.cyan.withValues(alpha: 0.55),
                    ),

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
        ],
      ),
    );
  }
}

/// A slow-rotating hairline ring with two brighter gold arcs — ambient
/// motion behind the crest, evoking a rotating halo/orbit rather than
/// a loading spinner (it never implies progress, it's purely
/// atmospheric).
class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final basePaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, basePaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.cyan.withValues(alpha: 0.9),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 0.55,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * 0.35,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
