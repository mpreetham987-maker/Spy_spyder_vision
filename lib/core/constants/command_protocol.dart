/// Single source of truth for every command string sent to the
/// Arduino Uno / ESP32 over Bluetooth serial.
///
/// Keeping the protocol centralized here means the firmware team has
/// exactly one file to diff against when the wire format changes.
///
/// Locomotion commands are single ASCII characters (cheap over serial,
/// trivial to parse with a `switch` in Arduino). Servo commands follow
/// the pattern `S<channel>:<angle>` (e.g. `S1:90`, `S8:0`), matching the
/// spec's example protocol exactly.
class CommandProtocol {
  CommandProtocol._();

  // Locomotion
  static const String forward = 'F';
  static const String backward = 'B';
  static const String left = 'L';
  static const String right = 'R';
  static const String stop = 'X';

  // Pose / gait macros — the firmware expands these into the correct
  // sequence of servo moves for all 8 channels.
  static const String stand = 'P:STAND';
  static const String sit = 'P:SIT';
  static const String walk = 'P:WALK';
  static const String homePosition = 'P:HOME';
  static const String reset = 'P:RESET';

  // Safety
  static const String emergencyStop = 'ESTOP';

  // Mode switching
  static const String modeManual = 'MODE:MANUAL';
  static const String modeAuto = 'MODE:AUTO';

  // Auto-mode AI behaviors
  static const String aiStart = 'AI:START';
  static const String aiStop = 'AI:STOP';
  static const String aiObjectDetection = 'AI:OBJECT';
  static const String aiHumanDetection = 'AI:HUMAN';
  static const String aiObstacleDetection = 'AI:OBSTACLE';
  static const String aiFollowTarget = 'AI:FOLLOW';
  static const String returnHome = 'AI:RETURN_HOME';

  /// Builds a single servo command, e.g. `servoCommand(3, 120) == 'S3:120'`.
  static String servoCommand(int channel, int angle) => 'S$channel:$angle';

  /// Sets the firmware's walking speed multiplier, 0-100.
  static String walkingSpeedCommand(int percent) => 'SPEED:$percent';
}
