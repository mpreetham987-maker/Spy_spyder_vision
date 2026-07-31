import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// A frosted-glass surface: blurred backdrop + translucent fill + a
/// hairline gold stroke + a soft diagonal sheen. This is the single
/// visual primitive behind every card in the app, so all
/// "glassmorphism" in the spec routes through here.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppConstants.spaceMd),
    this.borderRadius = AppConstants.radiusLarge,
    this.blurSigma = 18,
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
              color: borderColor ?? palette.glassStroke,
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                sheenTop.withValues(alpha: accent != null ? 0.10 : 0.06),
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
          child: child,
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
