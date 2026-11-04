import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/servo_channel.dart';

/// A premium slider control for a single SG90 servo channel.
///
/// Shows the channel's short label (e.g. "S1"), a live numeric angle
/// readout, and a full-width slider styled to match the app's cyan
/// accent. The UI readout updates on every drag frame, but outbound
/// Bluetooth commands are throttled to [AppConstants.sliderSendInterval]
/// (~20/sec) to avoid flooding the serial link across 8 simultaneous
/// servo sliders; [onChangeEnd] always fires immediately, un-throttled,
/// so the final released angle is never delayed or dropped.
class ServoSlider extends StatefulWidget {
  const ServoSlider({
    super.key,
    required this.servo,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
  });

  final ServoChannel servo;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;
  final bool enabled;

  @override
  State<ServoSlider> createState() => _ServoSliderState();
}

class _ServoSliderState extends State<ServoSlider> {
  Timer? _throttle;
  int? _pendingAngle;
  double? _dragValue;

  void _onChanged(double v) {
    final angle = v.round();
    setState(() => _dragValue = v); // instant local UI feedback every frame
    _pendingAngle = angle;
    _throttle ??= Timer.periodic(AppConstants.sliderSendInterval, (_) {
      final pending = _pendingAngle;
      if (pending != null) widget.onChanged(pending);
    });
  }

  void _onChangeEnd(double v) {
    _throttle?.cancel();
    _throttle = null;
    _pendingAngle = null;
    setState(() => _dragValue = null);
    final angle = v.round();
    widget.onChanged(angle); // guarantee the final value is sent, un-throttled
    widget.onChangeEnd?.call(angle);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.4;
    final displayAngle = (_dragValue?.round()) ?? widget.servo.angle;

    return Opacity(
      opacity: opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'S${widget.servo.channel}',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  widget.servo.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$displayAngle°',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: AppConstants.servoMin.toDouble(),
              max: AppConstants.servoMax.toDouble(),
              value: _dragValue ?? widget.servo.angle.toDouble(),
              label: '$displayAngle°',
              onChanged: widget.enabled ? _onChanged : null,
              onChangeEnd: widget.enabled ? _onChangeEnd : null,
            ),
          ),
        ],
      ),
    );
  }
}
