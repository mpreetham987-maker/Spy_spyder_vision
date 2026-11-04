import 'package:flutter/material.dart';

import '../data/services/preferences_service.dart';

/// Holds every user-configurable setting: robot identity, camera
/// endpoint, walking speed, per-servo calibration trims, and the
/// Light/Dark appearance preference.
///
/// All values are persisted immediately via [PreferencesService] so
/// they survive app restarts without any explicit "Save" step.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._preferences) {
    _robotName = _preferences.robotName;
    _cameraUrl = _preferences.cameraUrl;
    _walkingSpeed = _preferences.walkingSpeed;
    _themeMode = _decodeThemeMode(_preferences.themeMode);
  }

  final PreferencesService _preferences;

  late String _robotName;
  late String _cameraUrl;
  late double _walkingSpeed;
  late ThemeMode _themeMode;

  String get robotName => _robotName;
  String get cameraUrl => _cameraUrl;
  double get walkingSpeed => _walkingSpeed;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> setRobotName(String name) async {
    _robotName = name;
    await _preferences.setRobotName(name);
    notifyListeners();
  }

  Future<void> setCameraUrl(String url) async {
    _cameraUrl = url;
    await _preferences.setCameraUrl(url);
    notifyListeners();
  }

  Future<void> setWalkingSpeed(double speed) async {
    _walkingSpeed = speed.clamp(0.0, 1.0);
    await _preferences.setWalkingSpeed(_walkingSpeed);
    notifyListeners();
  }

  /// Sets the appearance mode ([ThemeMode.light], [ThemeMode.dark], or
  /// [ThemeMode.system]) and persists it immediately.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _preferences.setThemeMode(_encodeThemeMode(mode));
    notifyListeners();
  }

  /// Convenience toggle used by the Settings segmented control.
  Future<void> setDarkMode(bool dark) =>
      setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);

  int servoTrim(int channel) => _preferences.servoTrim(channel);

  Future<void> setServoTrim(int channel, int trimDegrees) async {
    await _preferences.setServoTrim(channel, trimDegrees);
    notifyListeners();
  }

  static ThemeMode _decodeThemeMode(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
