import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/settings_provider.dart';

/// Bottom sheet allowing per-servo trim calibration (a small degree
/// offset applied to compensate for mechanical mounting variance
/// between individual SG90 units).
class ServoCalibrationSheet extends StatelessWidget {
  const ServoCalibrationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoalElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXLarge),
        ),
      ),
      builder: (_) => const ServoCalibrationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg,
            AppConstants.spaceSm,
            AppConstants.spaceLg,
            AppConstants.spaceLg,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Text(
                    'SERVO CALIBRATION',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trim each servo to correct mechanical offset. Applied on top of every commanded angle.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: 8,
                  separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spaceSm),
                  itemBuilder: (context, index) {
                    final channel = index + 1;
                    final trim = settings.servoTrim(channel);
                    return _TrimRow(
                      channel: channel,
                      trim: trim,
                      onChanged: (value) =>
                          settings.setServoTrim(channel, value.round()),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrimRow extends StatelessWidget {
  const _TrimRow({
    required this.channel,
    required this.trim,
    required this.onChanged,
  });

  final int channel;
  final int trim;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'S$channel',
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.cyan,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: -15,
              max: 15,
              divisions: 30,
              value: trim.toDouble(),
              label: '$trim°',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$trim°',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
