import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// State for a single SG90 servo channel (S1..S8).
///
/// [channel] corresponds 1:1 to the wire protocol identifier used in
/// commands like `S3:120`. [angle] is clamped to [AppConstants.servoMin]..
/// [AppConstants.servoMax] to match the physical range of an SG90.
@immutable
class ServoChannel {
  const ServoChannel({
    required this.channel,
    required this.label,
    this.angle = AppConstants.servoDefault,
  });

  final int channel;
  final String label;
  final int angle;

  ServoChannel copyWith({int? angle}) {
    final clamped = (angle ?? this.angle).clamp(
      AppConstants.servoMin,
      AppConstants.servoMax,
    );
    return ServoChannel(channel: channel, label: label, angle: clamped);
  }

  /// The exact command string sent over Bluetooth, e.g. `S1:90`.
  String toCommand() => 'S$channel:$angle';
}
