/// Operating mode reported by / requested from the robot firmware.
enum RobotMode { idle, manual, auto, emergencyStopped }

/// Immutable snapshot of everything the dashboard/camera overlay needs
/// to know about the robot's current state.
///
/// Instances are produced by [BluetoothService] as status lines arrive
/// from the Arduino/ESP32 (see `RobotStatus.fromStatusLine`) and consumed
/// read-only by the UI via [RobotProvider].
class RobotStatus {
  const RobotStatus({
    this.batteryPercent = 0,
    this.mode = RobotMode.idle,
    this.signalStrengthPercent = 0,
    this.latencyMs = 0,
    this.isMoving = false,
  });

  final int batteryPercent;
  final RobotMode mode;
  final int signalStrengthPercent;
  final int latencyMs;
  final bool isMoving;

  RobotStatus copyWith({
    int? batteryPercent,
    RobotMode? mode,
    int? signalStrengthPercent,
    int? latencyMs,
    bool? isMoving,
  }) {
    return RobotStatus(
      batteryPercent: batteryPercent ?? this.batteryPercent,
      mode: mode ?? this.mode,
      signalStrengthPercent: signalStrengthPercent ?? this.signalStrengthPercent,
      latencyMs: latencyMs ?? this.latencyMs,
      isMoving: isMoving ?? this.isMoving,
    );
  }

  /// Parses a status line sent by the firmware in the form:
  /// `STATUS:BAT=87,MODE=MANUAL,SIG=92,LAT=48,MOVE=1`
  ///
  /// Unknown or malformed lines fall back to the current values, so a
  /// single corrupt packet over serial never crashes the UI.
  static RobotStatus fromStatusLine(String line, RobotStatus previous) {
    if (!line.startsWith('STATUS:')) return previous;

    final payload = line.substring('STATUS:'.length);
    final fields = <String, String>{};
    for (final pair in payload.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) fields[parts[0].trim()] = parts[1].trim();
    }

    RobotMode parseMode(String? raw) {
      switch (raw) {
        case 'MANUAL':
          return RobotMode.manual;
        case 'AUTO':
          return RobotMode.auto;
        case 'ESTOP':
          return RobotMode.emergencyStopped;
        default:
          return RobotMode.idle;
      }
    }

    return previous.copyWith(
      batteryPercent: int.tryParse(fields['BAT'] ?? ''),
      mode: parseMode(fields['MODE']),
      signalStrengthPercent: int.tryParse(fields['SIG'] ?? ''),
      latencyMs: int.tryParse(fields['LAT'] ?? ''),
      isMoving: fields['MOVE'] == '1',
    );
  }
}
