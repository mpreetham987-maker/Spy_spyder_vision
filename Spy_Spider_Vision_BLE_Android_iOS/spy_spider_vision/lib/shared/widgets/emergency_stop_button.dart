import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';

/// The one place red appears in this app: the emergency stop control.
///
/// Tapping asks for a brief confirmation tap-and-hold-free double
/// action isn't required here (speed matters in an emergency), but we
/// do give tactile/visual feedback via a scale-down animation so a
/// stray tap doesn't feel like a false trigger versus a deliberate
/// press.
class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactEstop(onPressed: onPressed);
    }

    return Material(
      color: AppColors.statusEmergency,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppColors.statusEmergency.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                'EMERGENCY STOP',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).boxShadow(
          begin: const BoxShadow(
            color: Color(0x00FF3B3B),
            blurRadius: 0,
          ),
          end: BoxShadow(
            color: AppColors.statusEmergency.withValues(alpha: 0.18),
            blurRadius: 16,
          ),
          duration: 1400.ms,
        );
  }
}

/// Small circular variant used inside the camera overlay where space
/// is at a premium.
class _CompactEstop extends StatelessWidget {
  const _CompactEstop({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.statusEmergency,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.statusEmergency.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.stop_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
