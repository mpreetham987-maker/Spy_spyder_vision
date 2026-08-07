import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';

/// A titled group of settings rows, rendered as one glass card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: AppConstants.spaceSm,
          ),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
        const SizedBox(height: AppConstants.spaceLg),
      ],
    );
  }
}

/// A single tappable row inside a [SettingsSection], with an optional
/// trailing value label, an optional full-width line underneath (for
/// values too long to sit beside the label — e.g. a camera URL), and
/// a divider.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.showDivider = true,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDivider;

  /// Full-width text shown on its own line below the label — used
  /// instead of [trailing]/[value] when the content (e.g. a URL) is
  /// too long to sit beside the label without truncating.
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceMd,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 19, color: AppColors.cyan),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (subtitle == null) ...[
                      if (trailing != null)
                        trailing!
                      else if (value != null)
                        Text(
                          value!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (onTap != null && trailing == null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ] else
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  // Indented to line up under the label, not the icon —
                  // and given the full row width so a long URL wraps
                  // instead of being clipped with an ellipsis.
                  Padding(
                    padding: const EdgeInsets.only(left: 19 + AppConstants.spaceMd),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}
