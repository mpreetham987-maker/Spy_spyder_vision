import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/servo_channel.dart';
import '../../../shared/widgets/glass_card.dart';
import 'servo_slider.dart';

/// Groups the two servos belonging to a single leg (e.g. "Front Left"
/// → S1 + S2) inside one glass card, matching the spec's leg-first
/// organization for manual control.
class LegControlCard extends StatelessWidget {
  const LegControlCard({
    super.key,
    required this.legName,
    required this.legIcon,
    required this.servos,
    required this.onServoChanged,
    required this.onServoChangeEnd,
    this.enabled = true,
  });

  final String legName;
  final IconData legIcon;
  final List<ServoChannel> servos;
  final void Function(int channel, int angle) onServoChanged;
  final void Function(int channel, int angle) onServoChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(legIcon, size: 16, color: AppColors.cyan),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                legName.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          for (int i = 0; i < servos.length; i++) ...[
            ServoSlider(
              servo: servos[i],
              enabled: enabled,
              onChanged: (angle) => onServoChanged(servos[i].channel, angle),
              onChangeEnd: (angle) => onServoChangeEnd(servos[i].channel, angle),
            ),
            if (i != servos.length - 1) const SizedBox(height: AppConstants.spaceXs),
          ],
        ],
      ),
    );
  }
}
