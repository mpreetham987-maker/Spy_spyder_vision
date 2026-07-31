import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';

/// One tappable action chip in the manual-control quick-action row
/// (Stand / Sit / Walk / Home Position / Reset / Stop).
class QuickActionChip extends StatelessWidget {
  const QuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasis = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasis;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = emphasis ? AppColors.cyan : AppColors.textPrimary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: emphasis
            ? AppColors.cyan.withValues(alpha: 0.14)
            : AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: emphasis
                    ? AppColors.cyan.withValues(alpha: 0.4)
                    : AppColors.glassStroke,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
