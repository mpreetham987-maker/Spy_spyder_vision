import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/robot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../dashboard/widgets/device_picker_sheet.dart';
import '../widgets/servo_calibration_sheet.dart';
import '../widgets/settings_section.dart';

/// Settings tab covering everything the spec calls for: Bluetooth
/// device, ESP32 camera URL, robot name, servo calibration, walking
/// speed, theme, and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final settings = context.watch<SettingsProvider>();
    final camera = context.watch<CameraProvider>();

    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.backgroundGradient,
          ),
        ),
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg,
            AppConstants.spaceMd,
            AppConstants.spaceLg,
            AppConstants.spaceXxl,
          ),
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [palette.gold, palette.amethyst],
              ).createShader(bounds),
              child: Text(
                'SETTINGS',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceLg),

            SettingsSection(
              title: 'Connectivity',
              children: [
                SettingsRow(
                  icon: Icons.bluetooth_rounded,
                  label: 'Bluetooth Device',
                  value: robot.isConnected
                      ? (robot.connectedDeviceName ?? 'Connected')
                      : 'Not connected',
                  onTap: () => DevicePickerSheet.show(context),
                ),
                SettingsRow(
                  icon: Icons.videocam_rounded,
                  label: 'ESP32 Camera URL',
                  showDivider: false,
                  onTap: () => _showCameraUrlDialog(context, camera, settings),
                  // Full URLs (http://192.168.4.1:81/stream, etc.) don't
                  // fit beside the label without truncating — shown on
                  // its own line underneath instead, wrapping if needed.
                  subtitle: Text(
                    settings.cameraUrl,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            SettingsSection(
              title: 'Robot',
              children: [
                SettingsRow(
                  icon: Icons.badge_rounded,
                  label: 'Robot Name',
                  value: settings.robotName,
                  onTap: () => _showRobotNameDialog(context, settings),
                ),
                SettingsRow(
                  icon: Icons.tune_rounded,
                  label: 'Servo Calibration',
                  value: '8 channels',
                  onTap: () => ServoCalibrationSheet.show(context),
                ),
                _WalkingSpeedRow(settings: settings, robot: robot),
              ],
            ),

            SettingsSection(
              title: 'Appearance',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spaceMd,
                    4,
                    AppConstants.spaceMd,
                    AppConstants.spaceMd,
                  ),
                  child: _ThemeModeToggle(settings: settings),
                ),
              ],
            ),

            SettingsSection(
              title: 'Info',
              children: [
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  showDivider: false,
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: AppConstants.animMedium),
        ),
      ),
    );
  }

  void _showRobotNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.robotName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Robot Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: context.palette.textPrimary),
          decoration: const InputDecoration(hintText: 'e.g. SPIDER-01'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              settings.setRobotName(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCameraUrlDialog(
    BuildContext context,
    CameraProvider camera,
    SettingsProvider settings,
  ) {
    final controller = TextEditingController(text: settings.cameraUrl);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ESP32 Camera URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: GoogleFonts.inter(color: context.palette.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: AppConstants.defaultCameraUrlHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              settings.setCameraUrl(url);
              camera.updateStreamUrl(url);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.smart_toy_rounded,
        color: context.palette.gold,
        size: 32,
      ),
      children: [
        Text(
          'Professional controller for a Bluetooth/Wi-Fi 4-legged spy '
          'spider robot built on Arduino Uno, ESP32, and ESP32-CAM. '
          'Controls 8 SG90 servos and streams live video over the '
          'local network.',
          style: GoogleFonts.inter(fontSize: 13, color: context.palette.textSecondary),
        ),
      ],
    );
  }
}

/// Pill-shaped segmented control for Light/Dark Mode — the one bit of
/// state that reskins the entire app, so it gets a deliberately premium
/// treatment: a moving gold/amethyst gradient indicator behind glass.
class _ThemeModeToggle extends StatelessWidget {
  const _ThemeModeToggle({required this.settings});
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = settings.themeMode != ThemeMode.light;

    Widget segment({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              gradient: selected
                  ? LinearGradient(colors: [palette.gold, palette.amethyst])
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.gold.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : palette.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall + 4),
        border: Border.all(color: palette.glassStroke),
      ),
      child: Row(
        children: [
          segment(
            label: 'Dark',
            icon: Icons.nights_stay_rounded,
            selected: isDark,
            onTap: () => settings.setThemeMode(ThemeMode.dark),
          ),
          segment(
            label: 'Light',
            icon: Icons.wb_sunny_rounded,
            selected: !isDark,
            onTap: () => settings.setThemeMode(ThemeMode.light),
          ),
        ],
      ),
    );
  }
}

class _WalkingSpeedRow extends StatefulWidget {
  const _WalkingSpeedRow({required this.settings, required this.robot});
  final SettingsProvider settings;
  final RobotProvider robot;

  @override
  State<_WalkingSpeedRow> createState() => _WalkingSpeedRowState();
}

class _WalkingSpeedRowState extends State<_WalkingSpeedRow> {
  Timer? _throttle;
  double? _pending;
  double? _dragValue;

  void _onChanged(double v) {
    // Local state only — this is what keeps the thumb and the "NN%"
    // label tracking the finger every frame without touching
    // SettingsProvider. Calling settings.setWalkingSpeed() here (as
    // this used to) persists to disk AND calls notifyListeners() on
    // every pixel of drag; since SettingsProvider used to be watched
    // at the very top of the widget tree, each of those notifications
    // rebuilt the entire app. That round-trip was the walking-speed
    // slider's lag, not the slider itself.
    setState(() => _dragValue = v);
    _pending = v;
    _throttle ??= Timer.periodic(AppConstants.sliderSendInterval, (_) {
      final p = _pending;
      if (p != null) widget.robot.setWalkingSpeed((p * 100).round());
    });
  }

  void _onChangeEnd(double v) {
    _throttle?.cancel();
    _throttle = null;
    _pending = null;
    setState(() => _dragValue = null);
    // Persist + notify exactly once, when the drag actually ends —
    // the value is already final, so there's nothing gained by having
    // done this on every intermediate frame.
    widget.settings.setWalkingSpeed(v);
    widget.robot.setWalkingSpeed((v * 100).round());
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = _dragValue ?? widget.settings.walkingSpeed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        4,
        AppConstants.spaceMd,
        AppConstants.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 19, color: context.palette.gold),
              const SizedBox(width: AppConstants.spaceMd),
              Expanded(
                child: Text(
                  'Walking Speed',
                  style: GoogleFonts.inter(fontSize: 14, color: context.palette.textPrimary),
                ),
              ),
              Text(
                '${(displayValue * 100).round()}%',
                style: GoogleFonts.inter(fontSize: 13, color: context.palette.textSecondary),
              ),
            ],
          ),
          Slider(
            value: displayValue,
            onChanged: _onChanged,
            onChangeEnd: _onChangeEnd,
          ),
        ],
      ),
    );
  }
}
