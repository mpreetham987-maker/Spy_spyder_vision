import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Thin, typed wrapper around [SharedPreferences] so the rest of the
/// app never touches raw string keys directly.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyCameraUrl = 'camera_url';
  static const _keyRobotName = 'robot_name';
  static const _keyWalkingSpeed = 'walking_speed';
  static const _keyLastDeviceAddress = 'last_device_address';
  static const _keyLastDeviceName = 'last_device_name';
  static const _keyServoTrim = 'servo_trim_'; // + channel number
  static const _keyThemeMode = 'theme_mode'; // 'system' | 'light' | 'dark'

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String get cameraUrl =>
      _prefs.getString(_keyCameraUrl) ?? AppConstants.defaultCameraUrlHint;
  Future<void> setCameraUrl(String url) => _prefs.setString(_keyCameraUrl, url);

  String get robotName => _prefs.getString(_keyRobotName) ?? 'SPIDER-01';
  Future<void> setRobotName(String name) => _prefs.setString(_keyRobotName, name);

  /// 0.0 (slowest) .. 1.0 (fastest)
  double get walkingSpeed => _prefs.getDouble(_keyWalkingSpeed) ?? 0.6;
  Future<void> setWalkingSpeed(double v) => _prefs.setDouble(_keyWalkingSpeed, v);

  String? get lastDeviceAddress => _prefs.getString(_keyLastDeviceAddress);
  String? get lastDeviceName => _prefs.getString(_keyLastDeviceName);
  Future<void> setLastDevice(String address, String name) async {
    await _prefs.setString(_keyLastDeviceAddress, address);
    await _prefs.setString(_keyLastDeviceName, name);
  }

  /// Per-servo calibration trim, in degrees, applied on top of the
  /// commanded angle to compensate for mechanical mounting offsets.
  int servoTrim(int channel) => _prefs.getInt('$_keyServoTrim$channel') ?? 0;
  Future<void> setServoTrim(int channel, int trimDegrees) =>
      _prefs.setInt('$_keyServoTrim$channel', trimDegrees);

  /// Persisted appearance preference. Defaults to 'dark' — the app's
  /// original identity — until the user explicitly picks Light Mode
  /// or System in Settings.
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_keyThemeMode, mode);
}
