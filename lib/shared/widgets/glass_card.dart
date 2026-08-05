import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// A "liquid glass" surface: a heavier frosted blur, a translucent
/// fill, a bright hairline edge, and a curved specular highlight
/// hugging the top so the surface reads as a refractive layer of
/// glass sitting over the background rather than a flat tinted panel.
/// This is the single visual primitive behind every card/controller
/// surface in the app, so all "glassmorphism" in the spec routes
/// through here.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppConstants.spaceMd),
    this.borderRadius = AppConstants.radiusLarge,
    this.blurSigma = 26,
    this.fillColor,
    this.borderColor,
    this.onTap,
    this.margin,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? fillColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  /// Optional accent color for a subtle top-edge glow (e.g. gold for a
  /// primary card, amethyst for a secondary one). Null = neutral glass.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(borderRadius);
    final sheenTop = accent ?? Colors.white;

    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor ?? palette.glassFill,
            borderRadius: radius,
            border: Border.all(
              // A brighter, thinner edge than the fill reads as light
              // catching the rim of a curved glass surface.
              color: borderColor ?? Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.35, 1.0],
              colors: [
                sheenTop.withValues(alpha: accent != null ? 0.16 : 0.12),
                sheenTop.withValues(alpha: accent != null ? 0.05 : 0.03),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // A short, curved specular highlight along the top edge —
          // the detail that sells "liquid glass" over a flat gradient.
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: borderRadius * 0.6,
                right: borderRadius * 0.6,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    final wrapped = Container(margin: margin, child: card);

    if (onTap == null) return wrapped;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          splashColor: (accent ?? palette.gold).withValues(alpha: 0.12),
          highlightColor: (accent ?? palette.gold).withValues(alpha: 0.06),
          child: card,
        ),
      ),
    );
  }
}
