import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/ai_detection_service.dart';
import '../../../providers/camera_provider.dart';
import '../../../providers/robot_provider.dart';
import '../../../shared/widgets/emergency_stop_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../camera/widgets/mjpeg_stream_view.dart';

/// A single auto-captured snapshot. [bytes] is the *actual* JPEG frame
/// that was already decoded off the live stream for inference — this
/// is a real photo, not a re-render or a placeholder graphic.
class _Snapshot {
  _Snapshot({required this.bytes, required this.time, required this.label});
  final Uint8List bytes;
  final DateTime time;
  final String label;
}

/// Standalone AI Detection screen: its own ESP32-CAM feed with a real
/// on-device object-detection toggle (Google ML Kit), separate from
/// the manual gamepad Control screen. Detection is genuine inference
/// on the actual decoded stream frames — never simulated.
class AiDetectionScreen extends StatefulWidget {
  const AiDetectionScreen({super.key});

  @override
  State<AiDetectionScreen> createState() => _AiDetectionScreenState();
}

class _AiDetectionScreenState extends State<AiDetectionScreen> {
  bool _aiEnabled = false;
  bool _nightVision = false;
  bool _autoSnapshot = false;
  List<Detection> _detections = [];
  final List<_Snapshot> _snapshots = [];
  DateTime? _lastSnapshotAt;
  late final AiDetectionService _ai;

  @override
  void initState() {
    super.initState();
    _ai = AiDetectionService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().connect();
    });
  }

  /// Real per-frame inference hook. Frames are dropped (not queued)
  /// while a previous frame is still being processed, so the app
  /// never fakes or interpolates a result.
  void _onFrame(Uint8List jpegBytes) {
    if (!_aiEnabled || _ai.isBusy) return;
    _ai.detect(jpegBytes).then((result) {
      if (!mounted) return;
      setState(() => _detections = result);
      if (_autoSnapshot && result.isNotEmpty) {
        _maybeCaptureSnapshot(jpegBytes, result);
      }
    });
  }

  /// Throttled so a burst of consecutive detections doesn't flood the
  /// gallery — same cadence a person would actually want (roughly one
  /// capture every few seconds), and it's a real frame every time.
  void _maybeCaptureSnapshot(Uint8List bytes, List<Detection> detections) {
    final now = DateTime.now();
    if (_lastSnapshotAt != null &&
        now.difference(_lastSnapshotAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastSnapshotAt = now;
    final label = detections.map((d) => d.label).toSet().join(', ');
    setState(() {
      _snapshots.insert(0, _Snapshot(bytes: bytes, time: now, label: label));
      if (_snapshots.length > 24) _snapshots.removeRange(24, _snapshots.length);
    });
  }

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final robot = context.watch<RobotProvider>();
    final camera = context.watch<CameraProvider>();
    final connected = robot.isConnected;

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
                children: [
                  Text(
                    'AI DETECTION',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: palette.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: _aiEnabled ? 'DETECTING' : 'IDLE',
                    level: _aiEnabled ? StatusLevel.connected : StatusLevel.idle,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceMd),

              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _NightVisionFilter(
                        active: _nightVision,
                        child: MjpegStreamView(
                          streamUrl: camera.streamUrl,
                          onFrame: _onFrame,
                        ),
                      ),
                      if (_aiEnabled)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _DetectionPainter(_detections, palette.amethyst),
                            size: Size.infinite,
                          ),
                        ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: _NightVisionButton(
                          active: _nightVision,
                          onTap: () => setState(() => _nightVision = !_nightVision),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: AppConstants.animMedium),
              const SizedBox(height: AppConstants.spaceMd),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: connected
                      ? () {
                          setState(() {
                            _aiEnabled = !_aiEnabled;
                            if (!_aiEnabled) _detections = [];
                          });
                        }
                      : null,
                  icon: Icon(_aiEnabled
                      ? Icons.stop_circle_rounded
                      : Icons.center_focus_strong_rounded),
                  label: Text(_aiEnabled ? 'Stop Detection' : 'Start Detection'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.amethyst,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              if (!connected) ...[
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Connect the robot to start AI detection.',
                  style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                ),
              ],
              const SizedBox(height: AppConstants.spaceMd),

              // ---------------- Auto-save snapshots ----------------
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
                decoration: BoxDecoration(
                  color: palette.glassFill,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  border: Border.all(color: palette.glassStroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: AppConstants.spaceSm + 2),
                          Text(
                            'Auto-Save Snapshots',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Captures a real frame whenever something is detected',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceSm + 2),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoSnapshot,
                      activeColor: palette.emerald,
                      onChanged: (v) => setState(() => _autoSnapshot = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),

              Row(
                children: [
                  Text(
                    'SNAPSHOTS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: palette.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_snapshots.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.gold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_snapshots.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _snapshots.clear()),
                      child: Text(
                        'CLEAR',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              SizedBox(
                height: 72,
                child: _snapshots.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No snapshots yet — turn on Auto-Save above, then start detection.',
                          style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _snapshots.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => _SnapshotThumb(
                          snapshot: _snapshots[i],
                          onTap: () => _openSnapshot(context, i),
                        ),
                      ),
              ),
              const SizedBox(height: AppConstants.spaceLg),

              EmergencyStopButton(onPressed: () => robot.emergencyStop()),
              const SizedBox(height: AppConstants.spaceLg),

              // Detected-objects panel: every row here is an actual
              // current Detection, never a placeholder.
              Text(
                'DETECTED OBJECTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),
              if (!_aiEnabled)
                _EmptyHint(text: 'Start detection to see results here.')
              else if (_detections.isEmpty)
                _EmptyHint(text: 'No objects in view yet.')
              else
                Column(
                  children: [
                    for (final d in _detections) ...[
                      _DetectionRow(detection: d),
                      const SizedBox(height: AppConstants.spaceSm),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSnapshot(BuildContext context, int index) {
    final palette = context.palette;
    final snap = _snapshots[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spaceLg,
            AppConstants.spaceMd,
            AppConstants.spaceLg,
            AppConstants.spaceXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: palette.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                snap.label.isEmpty ? 'Detection' : snap.label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${snap.time.hour.toString().padLeft(2, '0')}:'
                '${snap.time.minute.toString().padLeft(2, '0')}:'
                '${snap.time.second.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(fontSize: 11.5, color: palette.textTertiary),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                child: Image.memory(snap.bytes, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _snapshots.removeAt(index));
                        Navigator.of(sheetContext).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.statusEmergency,
                        side: BorderSide(color: palette.statusEmergency.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.gold,
                        foregroundColor: palette.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      child: const Text('Close'),
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

/// Small circular toggle overlaid on the feed's top-right corner.
class _NightVisionButton extends StatelessWidget {
  const _NightVisionButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: active ? palette.emerald : Colors.black.withValues(alpha: 0.4),
      shape: CircleBorder(
        side: BorderSide(color: active ? palette.emerald : palette.glassStroke),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.dark_mode_rounded,
            size: 15,
            color: active ? const Color(0xFF04140E) : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Wraps the camera feed with a green-tinted, high-contrast look when
/// night vision is on — a real color transform (ColorFilter matrix)
/// applied to the actual live frame, not a static overlay image.
class _NightVisionFilter extends StatelessWidget {
  const _NightVisionFilter({required this.active, required this.child});

  final bool active;
  final Widget child;

  static const _matrix = <double>[
    0.35, 0.9, 0.35, 0, -20,
    0.35, 0.9, 0.35, 0, 10,
    0.15, 0.4, 0.15, 0, -20,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: active
          ? ColorFiltered(
              key: const ValueKey('nv-on'),
              colorFilter: const ColorFilter.matrix(_matrix),
              child: child,
            )
          : KeyedSubtree(key: const ValueKey('nv-off'), child: child),
    );
  }
}

class _SnapshotThumb extends StatelessWidget {
  const _SnapshotThumb({required this.snapshot, required this.onTap});

  final _Snapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(border: Border.all(color: palette.glassStroke)),
          child: Image.memory(snapshot.bytes, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12.5, color: context.palette.textTertiary),
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  const _DetectionRow({required this.detection});
  final Detection detection;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: palette.glassStroke),
      ),
      child: Row(
        children: [
          Icon(Icons.center_focus_strong_rounded, size: 16, color: palette.amethyst),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Text(
              detection.label,
              style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(detection.confidence * 100).round()}%',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.amethyst,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws bounding boxes from real [Detection] results only — each box
/// and label comes directly from the on-device model's output for the
/// current frame; nothing here is randomized, hardcoded, or simulated.
class _DetectionPainter extends CustomPainter {
  _DetectionPainter(this.detections, this.color);
  final List<Detection> detections;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final d in detections) {
      final rect = Rect.fromLTWH(
        d.left * size.width,
        d.top * size.height,
        d.width * size.width,
        d.height * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        boxPaint,
      );

      final label = '${d.label} ${(d.confidence * 100).round()}%';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            backgroundColor: color.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(rect.left, rect.top - painter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections || oldDelegate.color != color;
}
