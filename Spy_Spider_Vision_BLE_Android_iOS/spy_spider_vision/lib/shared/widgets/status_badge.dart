import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';

/// The three semantic states a status indicator can be in.
///
/// Color mapping is fixed by design spec:
///  connected → green, warning → orange, disconnected/idle → neutral gray.
/// Red is intentionally excluded here — it is reserved for emergency stop.
enum StatusLevel { connected, warning, idle }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.level,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusLevel level;
  final IconData? icon;
  final bool dense;

  Color get _color {
    switch (level) {
      case StatusLevel.connected:
        return AppColors.statusConnected;
      case StatusLevel.warning:
        return AppColors.statusWarning;
      case StatusLevel.idle:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
