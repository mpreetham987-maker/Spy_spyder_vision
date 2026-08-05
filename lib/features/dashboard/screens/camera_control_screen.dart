import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/robot_provider.dart';
import '../../../shared/widgets/emergency_stop_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../camera/widgets/mjpeg_stream_view.dart';
import '../../manual_control/widgets/leg_control_card.dart';

/// Combined camera + control screen: the ESP32-CAM live feed fills the
/// top (large, unobstructed — no overlay text on top of it), a
/// full-width emergency stop sits directly below the feed, and the
/// controller surface (D-pad, pose macros, servo fine-control)
/// fills the rest. AI detection lives on its own screen, not here.
///
/// No phone camera, no fake HUD elements. Every control is disabled
/// whenever the robot isn't connected or is emergency-stopped.
class CameraControlScreen extends StatefulWidget {
  const CameraControlScreen({super.key});

  @override
  State<CameraControlScreen> createState() => _CameraControlScreenState();
}

class _CameraControlScreenState extends State<CameraControlScreen> {
  bool _servosExpanded = false;

  static const _legIcons = {
    'Front Left': Icons.north_west_rounded,
    'Front Right': Icons.north_east_rounded,
    'Rear Left': Icons.south_west_rounded,
    'Rear Right': Icons.south_east_rounded,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final camera = context.watch<CameraProvider>();
    final connected = robot.isConnected;
    final stopped = robot.emergencyStopped;
    final controlsEnabled = connected && !stopped;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.palette.backgroundGradient,
          ),
        ),
        child: SafeArea(
        child: Column(
          children: [
            // ---------------- Camera feed (top, large, clean) ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                AppConstants.spaceMd,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 12, // larger feed, unobstructed view
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
                  child: MjpegStreamView(streamUrl: camera.streamUrl),
                ),
              ),
            ).animate().fadeIn(duration: AppConstants.animMedium),

            // ---------------- Emergency stop: full-width, directly under feed ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                0,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: EmergencyStopButton(onPressed: () => robot.emergencyStop()),
            ),

            if (!connected) const _NotConnectedBanner(),
            if (stopped) _EmergencyBanner(onClear: () => robot.clearEmergencyStop()),

            // ---------------- Controller (bottom) ----------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceLg,
                  AppConstants.spaceSm,
                  AppConstants.spaceLg,
                  AppConstants.spaceXxl,
                ),
                children: [
                  Row(
                    children: [
                      Text(
                        'CONTROLLER',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: context.palette.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      StatusBadge(
                        label: stopped
                            ? 'E-STOP ACTIVE'
                            : (connected ? 'LINK ACTIVE' : 'NO LINK'),
                        level: stopped
                            ? StatusLevel.warning
                            : (connected ? StatusLevel.connected : StatusLevel.idle),
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceMd),

                  // Realistic controller surface — drive pad + pose
                  // diamond side by side, mirroring the approved mockup.
                  _ControllerPad(enabled: controlsEnabled, robot: robot),

                  const SizedBox(height: AppConstants.spaceXl),

                  // Servo fine-control, collapsed by default.
                  InkWell(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    onTap: () => setState(() => _servosExpanded = !_servosExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            'SERVO FINE CONTROL · 8 CHANNELS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: context.palette.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _servosExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: context.palette.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_servosExpanded) ...[
                    const SizedBox(height: AppConstants.spaceMd),
                    for (final legEntry in AppConstants.legServoMap.entries) ...[
                      LegControlCard(
                        legName: legEntry.key,
                        legIcon: _legIcons[legEntry.key] ?? Icons.circle,
                        enabled: controlsEnabled,
                        servos: legEntry.value
                            .map((channel) => robot.servo(channel))
                            .toList(),
                        onServoChanged: (channel, angle) =>
                            robot.setServoAngle(channel, angle),
                        onServoChangeEnd: (channel, angle) =>
                            robot.setServoAngle(channel, angle),
                      ),
                      const SizedBox(height: AppConstants.spaceMd),
                    ],
                  ],
                ],
              ).animate().fadeIn(duration: AppConstants.animMedium),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _NotConnectedBanner extends StatelessWidget {
  const _NotConnectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppConstants.spaceLg,
        0,
        AppConstants.spaceLg,
        AppConstants.spaceMd,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: context.palette.statusWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: context.palette.statusWarning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled_rounded,
              size: 16, color: context.palette.statusWarning),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Text(
              'Connect the robot to enable controls.',
              style: GoogleFonts.inter(fontSize: 12, color: context.palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppConstants.spaceLg,
        0,
        AppConstants.spaceLg,
        AppConstants.spaceMd,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: context.palette.statusEmergency.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: context.palette.statusEmergency.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.report_rounded, size: 16, color: context.palette.statusEmergency),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Text(
              'Emergency stop is active. All controls are locked.',
              style: GoogleFonts.inter(fontSize: 12, color: context.palette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text(
              'CLEAR',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: context.palette.statusEmergency,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Directional pad sending Forward/Backward/Left/Right/Stop — the
/// single-character locomotion commands from [CommandProtocol]. This
/// is the "Controller" the user drives with — restyled to look like a
/// real ergonomic game controller: a recessed plate, a raised gold
/// D-pad with beveled edges, and a distinct ruby STOP button.
class _ControllerPad extends StatelessWidget {
  const _ControllerPad({required this.enabled, required this.robot});

  final bool enabled;
  final RobotProvider robot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [
              palette.surfaceHigh,
              palette.surface,
            ],
          ),
          border: Border.all(color: palette.glassStroke),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        // The two housings are sized FROM the width Flutter actually gives
        // us, not from a guessed constant — so on any phone, big or small,
        // "two circles + the gap between them" can never exceed what's
        // available. This is what the previous fixed 212dp version got
        // wrong: it assumed a screen width instead of measuring it, which
        // is what produced the "RIGHT OVERFLOWED BY 113 PIXELS" crash.
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final housingSize =
                ((constraints.maxWidth - gap) / 2).clamp(0.0, 215.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _housing(
                  label: 'DRIVE',
                  size: housingSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PadButton(
                            enabled: enabled,
                            size: housingSize * 0.29,
                            icon: Icons.keyboard_arrow_up_rounded,
                            onTap: () => robot.moveForward(),
                          ),
                          SizedBox(height: housingSize * 0.045),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PadButton(
                                enabled: enabled,
                                size: housingSize * 0.29,
                                icon: Icons.keyboard_arrow_left_rounded,
                                onTap: () => robot.turnLeft(),
                              ),
                              SizedBox(width: housingSize * 0.045),
                              _PadButton(
                                enabled: enabled,
                                size: housingSize * 0.29,
                                icon: Icons.stop_rounded,
                                onTap: () => robot.stopMovement(),
                                emphasis: true,
                              ),
                              SizedBox(width: housingSize * 0.045),
                              _PadButton(
                                enabled: enabled,
                                size: housingSize * 0.29,
                                icon: Icons.keyboard_arrow_right_rounded,
                                onTap: () => robot.turnRight(),
                              ),
                            ],
                          ),
                          SizedBox(height: housingSize * 0.045),
                          _PadButton(
                            enabled: enabled,
                            size: housingSize * 0.29,
                            icon: Icons.keyboard_arrow_down_rounded,
                            onTap: () => robot.moveBackward(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                _housing(
                  label: 'POSE',
                  size: housingSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 0,
                        child: _ActionButton(
                          enabled: enabled,
                          size: housingSize * 0.32,
                          label: 'Stand',
                          icon: Icons.height_rounded,
                          onTap: () => robot.standPose(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: _ActionButton(
                          enabled: enabled,
                          size: housingSize * 0.32,
                          label: 'Sit',
                          icon: Icons.expand_more_rounded,
                          onTap: () => robot.sitPose(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        child: _ActionButton(
                          enabled: enabled,
                          size: housingSize * 0.32,
                          // A walking-human pictogram didn't fit a
                          // 4-legged robot — a paw print reads correctly
                          // at a glance.
                          label: 'Walk',
                          icon: Icons.pets_rounded,
                          onTap: () => robot.walkGait(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: _ActionButton(
                          enabled: enabled,
                          size: housingSize * 0.32,
                          label: 'Reset',
                          icon: Icons.restart_alt_rounded,
                          onTap: () => robot.resetPose(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Shared recessed circular housing behind both the D-pad and the
  /// pose diamond, so the two clusters read as one cohesive controller
  /// rather than two unrelated widgets bolted together.
  Widget _housing({required String label, required double size, required Widget child}) {
    return Builder(
      builder: (context) {
        final palette = context.palette;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [palette.surfaceHigh, palette.surface],
                      ),
                      border: Border.all(
                        color: palette.glassStroke.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow,
                          blurRadius: 10,
                          offset: const Offset(4, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(-3, -3),
                        ),
                      ],
                    ),
                  ),
                  child,
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: palette.textTertiary,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One button of the D-pad. Bigger touch target than the original
/// mockup (62dp vs 50dp) for easier thumb control, plus tactile
/// press feedback: it scales down and its glow deepens on tap-down,
/// with a light haptic tick so it reads as a real physical button
/// rather than a flat icon.
class _PadButton extends StatefulWidget {
  const _PadButton({
    required this.enabled,
    required this.size,
    required this.icon,
    required this.onTap,
    this.emphasis = false,
  });

  final bool enabled;
  final double size;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = widget.size;

    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
        if (widget.enabled) {
          widget.emphasis
              ? HapticFeedback.mediumImpact()
              : HapticFeedback.selectionClick();
        }
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.enabled ? widget.onTap : null,
          splashColor:
              (widget.emphasis ? palette.statusEmergency : palette.gold)
                  .withValues(alpha: 0.18),
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfaceHigh, palette.surface],
                ),
                border: Border.all(
                  color: widget.emphasis
                      ? palette.statusEmergency.withValues(alpha: 0.45)
                      : palette.glassStroke,
                  width: widget.emphasis ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.emphasis
                        ? palette.statusEmergency.withValues(
                            alpha: _pressed ? 0.45 : 0.0)
                        : palette.gold.withValues(
                            alpha: _pressed ? 0.35 : 0.0),
                    blurRadius: _pressed ? 18 : 0,
                    spreadRadius: _pressed ? 1 : 0,
                  ),
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 8,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.emphasis
                    ? palette.statusEmergency
                    : palette.textSecondary,
                size: size * (widget.emphasis ? 0.36 : 0.42),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One vertex of the Stand/Sit/Walk/Reset pose diamond — visually
/// paired with [_PadButton] (same gradient, same bevel, same press
/// animation) so the two housings read as one controller family.
/// Sized relative to the housing (computed by [_ControllerPad]) rather
/// than a fixed constant, same fix as [_PadButton].
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.enabled,
    required this.size,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool enabled;
  final double size;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = widget.size;

    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
        if (widget.enabled) HapticFeedback.selectionClick();
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.enabled ? widget.onTap : null,
          splashColor: palette.gold.withValues(alpha: 0.16),
          child: AnimatedScale(
            scale: _pressed ? 0.90 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfaceHigh, palette.surface],
                ),
                border: Border.all(color: palette.glassStroke),
                boxShadow: [
                  BoxShadow(
                    color: palette.gold.withValues(alpha: _pressed ? 0.35 : 0.0),
                    blurRadius: _pressed ? 16 : 0,
                    spreadRadius: _pressed ? 1 : 0,
                  ),
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 8,
                    offset: const Offset(3, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: palette.gold, size: size * 0.28),
                  SizedBox(height: size * 0.03),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: (size * 0.14).clamp(8.0, 10.5),
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
