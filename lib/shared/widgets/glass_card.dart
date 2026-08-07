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
    // 14, not 26 — BackdropFilter blur cost scales with sigma², so this
    // is roughly a 3x cheaper GPU pass per card per frame. That matters
    // a lot here specifically because every glass card on screen gets
    // re-blurred on every frame of a theme-switch animation (the
    // interpolating ThemeData touches context.palette, which every
    // GlassCard reads) — a handful of 26px blurs animating at once was
    // the real source of the "laggy theme switch" reports, more than
    // the animation itself.
    this.blurSigma = 14,
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
          // Two static details that sell "liquid glass" over a flat
          // tinted panel — a curved specular highlight along the top
          // edge, and a soft warm glow pooling along the bottom edge
          // (Flutter's BoxDecoration has no inset-shadow equivalent, so
          // this is a positioned gradient standing in for one). Both
          // are fixed — nothing here loops or rotates.
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 36,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          (accent ?? palette.gold).withValues(alpha: 0.14),
                          (accent ?? palette.gold).withValues(alpha: 0.0),
                        ],
                      ),
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

    // Isolates this card's paint layer from its ancestors' — when the
    // app-wide theme animation touches everything above it each frame,
    // the blur+gradient work here stays confined to this boundary
    // instead of forcing sibling glass cards to be reconsidered too.
    final wrapped = Container(margin: margin, child: RepaintBoundary(child: card));

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
          child: RepaintBoundary(child: card),
        ),
      ),
    );
  }
}
