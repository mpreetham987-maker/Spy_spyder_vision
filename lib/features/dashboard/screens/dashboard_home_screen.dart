import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/robot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/status_badge.dart';
import '../widgets/device_picker_sheet.dart';

/// Dashboard tab: an at-a-glance status screen. Every reading here is
/// sourced from real provider state — the robot's actual `STATUS:`
/// packets over Bluetooth ([RobotProvider]), the actual MJPEG stream
/// link state ([CameraProvider]), and the actual persisted robot name
/// ([SettingsProvider]). Nothing is a placeholder number: unconnected
/// fields show "—" rather than a fake reading.
class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key, this.onNavigateToTab});

  /// Called with a tab index (1=Control, 2=AI, 3=Settings) when a
  /// quick-action button is tapped. Null when this screen is shown
  /// standalone (e.g. in isolation for testing) — buttons hide then.
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final camera = context.watch<CameraProvider>();
    final settings = context.watch<SettingsProvider>();
    final palette = context.palette;
    final connected = robot.isConnected;
    final status = robot.status;
    final totalServos =
        AppConstants.legServoMap.values.fold<int>(0, (a, b) => a + b.length);

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [palette.gold, palette.amethyst],
                          ).createShader(bounds),
                          child: Text(
                            'SPY SPIDER VISION',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'TACTICAL ROBOTICS CONTROL',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceMd),
                  _ThemeToggleButton(settings: settings),
                ],
              ),
              const SizedBox(height: AppConstants.spaceLg),

              // ---------------- Status card ----------------
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: palette.glassFill,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  border: Border.all(color: palette.glassStroke),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          settings.robotName,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: palette.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => connected
                              ? robot.disconnect()
                              : DevicePickerSheet.show(context),
                          child: StatusBadge(
                            label: connected ? 'LINK ACTIVE' : 'NO LINK',
                            level: connected
                                ? StatusLevel.connected
                                : StatusLevel.idle,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _BatteryGauge(
                      percent: status.batteryPercent,
                      connected: connected,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            emoji: '📡',
                            value: connected ? '${status.signalStrengthPercent}%' : '—',
                            label: 'SIGNAL',
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceSm),
                        Expanded(
                          child: _StatTile(
                            emoji: '🎥',
                            value: camera.isStreaming ? 'Streaming' : 'Offline',
                            label: 'CAMERA',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            emoji: '🦿',
                            value: '$totalServos',
                            label: 'SERVO CHANNELS',
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceSm),
                        Expanded(
                          child: _StatTile(
                            emoji: '🛡️',
                            value: robot.emergencyStopped
                                ? 'E-STOP'
                                : (connected ? 'Ready' : 'Offline'),
                            label: 'SYSTEM STATUS',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (robot.emergencyStopped) ...[
                const SizedBox(height: AppConstants.spaceMd),
                Container(
                  padding: const EdgeInsets.all(AppConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: palette.statusEmergency.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(
                      color: palette.statusEmergency.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.report_rounded, color: palette.statusEmergency, size: 20),
                      const SizedBox(width: AppConstants.spaceSm),
                      Expanded(
                        child: Text(
                          'Emergency stop is active — controls are locked.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                    color: palette.textTertiary,
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
      ),
    );
  }
}

/// Circular button top-right of the header that flips [SettingsProvider]'s
/// theme mode — same toggle Settings exposes, just reachable from the
/// dashboard too. The icon crossfades + spins on change instead of
/// snapping, so it doesn't feel like a flat state flip.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = settings.isDarkMode;

    return Material(
      color: palette.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.glassStroke),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                key: ValueKey(isDark),
                color: palette.gold,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated circular battery indicator. On first connect it sweeps from
/// 0% up to the real reading; on every subsequent `STATUS:` update it
/// eases from the previous value to the new one (never snaps, never
/// re-drains to 0 on a routine refresh).
class _BatteryGauge extends StatefulWidget {
  const _BatteryGauge({required this.percent, required this.connected});

  final int percent;
  final bool connected;

  @override
  State<_BatteryGauge> createState() => _BatteryGaugeState();
}

class _BatteryGaugeState extends State<_BatteryGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _lastValue = 0;

  double get _target => widget.connected ? widget.percent / 100 : 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _animation = Tween(begin: 0.0, end: _target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _lastValue = _target;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _BatteryGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (target != _lastValue) {
      _animation = Tween(begin: _lastValue, end: target).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _lastValue = target;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final value = _animation.value;
        return SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(148, 148),
                painter: _GaugePainter(
                  progress: value,
                  trackColor: palette.glassStroke,
                  gradientColors: [palette.gold, palette.amethyst, palette.emerald],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.connected ? '${(value * 100).round()}%' : '—',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'BATTERY',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
  });

  final double progress; // 0..1
  final Color trackColor;
  final List<Color> gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 10) / 2;
    const strokeWidth = 9.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: gradientColors,
      stops: const [0.0, 0.55, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.gradientColors != gradientColors;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: palette.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.glassStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
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
    final palette = context.palette;
    return Material(
      color: palette.glassFill,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: palette.glassStroke),
          ),
          child: Row(
            mainAxisAlignment:
                fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: palette.gold, size: 20),
              const SizedBox(width: AppConstants.spaceSm),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
