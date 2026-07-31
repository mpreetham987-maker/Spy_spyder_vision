import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/robot_status.dart';
import '../../../providers/robot_provider.dart';
import '../widgets/device_picker_sheet.dart';

/// Dashboard tab: an at-a-glance status screen showing the robot's
/// real connection state — Bluetooth link, battery, signal strength,
/// mode, and movement — all sourced from the actual `STATUS:` packets
/// the firmware sends over Bluetooth (see
/// [RobotStatus.fromStatusLine]). Nothing here is a placeholder or
/// simulated value; unconnected fields show "—" rather than a fake
/// number.
class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key, this.onNavigateToTab});

  /// Called with a tab index (1=Control, 2=AI, 3=Settings) when a
  /// quick-action button is tapped. Null when this screen is shown
  /// standalone (e.g. in isolation for testing) — buttons hide then.
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final connected = robot.isConnected;
    final status = robot.status;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg,
            AppConstants.spaceMd,
            AppConstants.spaceLg,
            AppConstants.spaceXxl,
          ),
          children: [
            Text(
              'DASHBOARD',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spaceLg),

            // Bluetooth connection card — the primary status, since
            // every other reading depends on this link being up.
            _StatusTile(
              icon: connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              title: 'Bluetooth',
              value: connected
                  ? (robot.connectedDeviceName ?? 'Connected')
                  : 'Not Connected',
              tone: connected ? _Tone.connected : _Tone.idle,
              trailing: TextButton(
                onPressed: () => connected
                    ? robot.disconnect()
                    : DevicePickerSheet.show(context),
                child: Text(
                  connected ? 'DISCONNECT' : 'CONNECT',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: connected ? AppColors.statusEmergency : AppColors.cyan,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),

            Row(
              children: [
                Expanded(
                  child: _StatusTile(
                    icon: _batteryIcon(status.batteryPercent),
                    title: 'Battery',
                    value: connected ? '${status.batteryPercent}%' : '—',
                    tone: !connected
                        ? _Tone.idle
                        : (status.batteryPercent < 20 ? _Tone.warning : _Tone.connected),
                    compact: true,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: _StatusTile(
                    icon: Icons.signal_cellular_alt_rounded,
                    title: 'Signal',
                    value: connected ? '${status.signalStrengthPercent}%' : '—',
                    tone: !connected
                        ? _Tone.idle
                        : (status.signalStrengthPercent < 30
                            ? _Tone.warning
                            : _Tone.connected),
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceMd),

            _StatusTile(
              icon: Icons.tune_rounded,
              title: 'Mode',
              value: _modeLabel(status.mode),
              tone: connected ? _Tone.connected : _Tone.idle,
            ),
            const SizedBox(height: AppConstants.spaceMd),

            _StatusTile(
              icon: status.isMoving
                  ? Icons.directions_walk_rounded
                  : Icons.accessibility_new_rounded,
              title: 'Movement',
              value: connected
                  ? (status.isMoving ? 'Moving' : 'Stationary')
                  : '—',
              tone: connected ? _Tone.connected : _Tone.idle,
            ),

            if (robot.emergencyStopped) ...[
              const SizedBox(height: AppConstants.spaceMd),
              _StatusTile(
                icon: Icons.report_rounded,
                title: 'Emergency Stop',
                value: 'Active — controls locked',
                tone: _Tone.emergency,
              ),
            ],

            if (onNavigateToTab != null) ...[
              const SizedBox(height: AppConstants.spaceXl),
              Text(
                'QUICK ACTIONS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: _QuickJumpCard(
                      icon: Icons.videogame_asset_rounded,
                      label: 'Control',
                      onTap: () => onNavigateToTab!(1),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceMd),
                  Expanded(
                    child: _QuickJumpCard(
                      icon: Icons.center_focus_strong_rounded,
                      label: 'AI Detection',
                      onTap: () => onNavigateToTab!(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceMd),
              _QuickJumpCard(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => onNavigateToTab!(3),
                fullWidth: true,
              ),
            ],
          ],
        ).animate().fadeIn(duration: AppConstants.animMedium),
      ),
    );
  }

  IconData _batteryIcon(int percent) {
    if (percent >= 80) return Icons.battery_full_rounded;
    if (percent >= 50) return Icons.battery_5_bar_rounded;
    if (percent >= 20) return Icons.battery_3_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  String _modeLabel(RobotMode mode) {
    switch (mode) {
      case RobotMode.manual:
        return 'Manual';
      case RobotMode.auto:
        return 'Auto';
      case RobotMode.emergencyStopped:
        return 'Emergency Stop';
      case RobotMode.idle:
        return 'Idle';
    }
  }
}

/// A tappable card that jumps to another tab — real navigation via
/// [AppShell.navigateToTab], not a placeholder.
class _QuickJumpCard extends StatelessWidget {
  const _QuickJumpCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: Row(
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.cyan, size: 20),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Tone { connected, warning, idle, emergency }

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
    this.trailing,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final _Tone tone;
  final Widget? trailing;
  final bool compact;

  Color get _color {
    switch (tone) {
      case _Tone.connected:
        return AppColors.statusConnected;
      case _Tone.warning:
        return AppColors.statusWarning;
      case _Tone.emergency:
        return AppColors.statusEmergency;
      case _Tone.idle:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _color, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
