import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/command_protocol.dart';
import '../data/models/robot_status.dart';
import '../data/models/servo_channel.dart';
import '../data/services/bluetooth_service.dart';
import '../data/services/preferences_service.dart';

/// The app's central nervous system: owns the Bluetooth link, the
/// robot's live telemetry, and the state of all 8 servos.
///
/// Every screen that needs to know "are we connected", "what's the
/// battery", or "what angle is servo 4 at" reads from this provider
/// rather than talking to [RobotBluetoothService] directly.
class RobotProvider extends ChangeNotifier {
  RobotProvider(this._bluetooth, this._preferences) {
    _bluetooth.stateStream.listen(_onBtStateChanged);
    _bluetooth.statusLines.listen(_onStatusLine);
    _bluetooth.discoveredDevices.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
    });
  }

  final RobotBluetoothService _bluetooth;
  final PreferencesService _preferences;

  // ---------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------
  BtConnectionState _btState = BtConnectionState.disconnected;
  List<BluetoothDevice> _discoveredDevices = [];

  BtConnectionState get btState => _btState;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  bool get isConnected => _btState == BtConnectionState.connected;
  bool get isScanning => _btState == BtConnectionState.scanning;
  bool get isConnecting => _btState == BtConnectionState.connecting;
  bool get permissionDenied => _btState == BtConnectionState.permissionDenied;
  String? get connectedDeviceName => _bluetooth.connectedDevice?.name;

  // ---------------------------------------------------------------------
  // Telemetry
  // ---------------------------------------------------------------------
  RobotStatus _status = const RobotStatus();
  RobotStatus get status => _status;

  // ---------------------------------------------------------------------
  // Servos — one entry per SG90 channel, keyed by channel number 1-8.
  // ---------------------------------------------------------------------
  final Map<int, ServoChannel> _servos = {
    for (final entry in AppConstants.legServoMap.entries)
      for (final ch in entry.value)
        ch: ServoChannel(
          channel: ch,
          label: '${entry.key} · S$ch',
        ),
  };

  Map<int, ServoChannel> get servos => Map.unmodifiable(_servos);

  ServoChannel servo(int channel) =>
      _servos[channel] ?? ServoChannel(channel: channel, label: 'S$channel');

  bool _emergencyStopped = false;
  bool get emergencyStopped => _emergencyStopped;

  // ---------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------

  void _onBtStateChanged(BtConnectionState state) {
    _btState = state;
    notifyListeners();
  }

  void _onStatusLine(String line) {
    _status = RobotStatus.fromStatusLine(line, _status);
    if (_status.mode == RobotMode.emergencyStopped) {
      _emergencyStopped = true;
    }
    notifyListeners();
  }

  Future<void> scanForDevices() async {
    final enabled = await _bluetooth.ensureAdapterEnabled();
    if (!enabled) return;
    await _bluetooth.scanDevices();
  }

  /// Opens the OS app-settings screen so the user can grant Bluetooth
  /// permission after having denied it once ("Don't ask again") —
  /// the request dialog won't reappear on its own after that.
  Future<void> openPermissionSettings() => _bluetooth.openPermissionSettings();

  Future<bool> connectToDevice(BluetoothDevice device) async {
    final ok = await _bluetooth.connect(device);
    if (ok) {
      await _preferences.setLastDevice(device.address, device.name ?? 'Robot');
      _emergencyStopped = false;
      // Sync the persisted walking speed immediately so a freshly
      // connected robot reflects the last value set in Settings,
      // rather than waiting for the next slider touch.
      await setWalkingSpeed((_preferences.walkingSpeed * 100).round());
    }
    notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    await _bluetooth.disconnect();
    notifyListeners();
  }

  Future<void> reconnect() async {
    await _bluetooth.reconnect();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Locomotion commands
  // ---------------------------------------------------------------------

  Future<void> moveForward() => _guardedSend(CommandProtocol.forward);
  Future<void> moveBackward() => _guardedSend(CommandProtocol.backward);
  Future<void> turnLeft() => _guardedSend(CommandProtocol.left);
  Future<void> turnRight() => _guardedSend(CommandProtocol.right);
  Future<void> stopMovement() => _guardedSend(CommandProtocol.stop);

  Future<void> standPose() => _guardedSend(CommandProtocol.stand);
  Future<void> sitPose() => _guardedSend(CommandProtocol.sit);
  Future<void> walkGait() => _guardedSend(CommandProtocol.walk);
  Future<void> homePosition() => _guardedSend(CommandProtocol.homePosition);
  Future<void> resetPose() => _guardedSend(CommandProtocol.reset);

  /// Immediately halts all motion and latches an emergency-stopped
  /// state until explicitly cleared. This bypasses the normal
  /// emergency-stop guard since it must always be sendable.
  Future<void> emergencyStop() async {
    _emergencyStopped = true;
    notifyListeners();
    await _bluetooth.sendCommand(CommandProtocol.emergencyStop);
  }

  /// Clears the latched emergency stop so movement commands are
  /// accepted again (operator must explicitly re-arm).
  Future<void> clearEmergencyStop() async {
    _emergencyStopped = false;
    notifyListeners();
    await _bluetooth.sendCommand(CommandProtocol.reset);
  }

  Future<void> setMode(RobotMode mode) async {
    if (mode == RobotMode.manual) {
      await _guardedSend(CommandProtocol.modeManual);
    } else if (mode == RobotMode.auto) {
      await _guardedSend(CommandProtocol.modeAuto);
    }
  }

  /// Transmits the firmware's walking-speed multiplier.
  ///
  /// [percent] is 0-100, matching the 0.0-1.0 value stored by
  /// [SettingsProvider.setWalkingSpeed] in Settings › Walking Speed
  /// (multiplied by 100 and rounded by the caller). Sending this is
  /// what makes that slider actually change the robot's gait speed,
  /// rather than only persisting a number nothing reads.
  Future<void> setWalkingSpeed(int percent) =>
      _guardedSend(CommandProtocol.walkingSpeedCommand(percent.clamp(0, 100)));

  // ---------------------------------------------------------------------
  // Servo control
  // ---------------------------------------------------------------------

  /// Updates a single servo's angle locally and transmits the command
  /// immediately. Called continuously while a slider drags.
  ///
  /// [angle] is the commanded angle as shown on the slider. Before
  /// transmission, the per-channel calibration trim set in Settings ›
  /// Servo Calibration is added on top and the result is re-clamped to
  /// the servo's physical 0-180 range — this is what makes that
  /// screen's "applied on top of every commanded angle" claim true.
  /// [_servos] stores the un-trimmed slider angle so the UI continues
  /// to reflect exactly what the user set; only the wire command
  /// includes the trim offset.
  Future<void> setServoAngle(int channel, int angle) async {
    if (_emergencyStopped) return;
    final current = _servos[channel];
    if (current == null) return;
    final updated = current.copyWith(angle: angle);
    _servos[channel] = updated;
    notifyListeners();
    await _bluetooth.sendCommand(_trimmedCommand(updated));
  }

  /// Sends every servo's current angle in one batch — used after
  /// restoring a saved pose or on initial connect sync. Each command
  /// includes that channel's calibration trim, same as [setServoAngle].
  Future<void> syncAllServos() async {
    if (_emergencyStopped) return;
    await _bluetooth.sendCommands(
      _servos.values.map(_trimmedCommand).toList(),
    );
  }

  /// Builds the wire command for [servo] with its calibration trim
  /// (Settings › Servo Calibration, degrees, ±15) added and the result
  /// re-clamped to [AppConstants.servoMin]..[AppConstants.servoMax] so
  /// trim can never push a physical SG90 past its real range.
  String _trimmedCommand(ServoChannel servo) {
    final trim = _preferences.servoTrim(servo.channel);
    final trimmedAngle = (servo.angle + trim).clamp(
      AppConstants.servoMin,
      AppConstants.servoMax,
    );
    return CommandProtocol.servoCommand(servo.channel, trimmedAngle);
  }

  Future<void> _guardedSend(String command) async {
    if (_emergencyStopped) return;
    await _bluetooth.sendCommand(command);
  }

  @override
  void dispose() {
    _bluetooth.dispose();
    super.dispose();
  }
}
