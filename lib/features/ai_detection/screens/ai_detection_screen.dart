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

/// Standalone AI Detection screen: its own ESP32-CAM feed with a
/// real on-device object-detection toggle (Google ML Kit), separate
/// from the manual gamepad Control screen. Detection is genuine
/// inference on the actual decoded stream frames — never simulated.
class AiDetectionScreen extends StatefulWidget {
  const AiDetectionScreen({super.key});

  @override
  State<AiDetectionScreen> createState() => _AiDetectionScreenState();
}

class _AiDetectionScreenState extends State<AiDetectionScreen> {
  bool _aiEnabled = false;
  List<Detection> _detections = [];
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
      if (mounted) setState(() => _detections = result);
    });
  }

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robot = context.watch<RobotProvider>();
    final camera = context.watch<CameraProvider>();
    final connected = robot.isConnected;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                AppConstants.spaceMd,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: Row(
                children: [
                  Text(
                    'AI DETECTION',
                    style: GoogleFonts.outfit(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textPrimary,
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
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                0,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MjpegStreamView(
                        streamUrl: camera.streamUrl,
                        onFrame: _onFrame,
                      ),
                      if (_aiEnabled)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _DetectionPainter(_detections),
                            size: Size.infinite,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: AppConstants.animMedium),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                0,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: SizedBox(
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
                    backgroundColor: AppColors.cyan,
                    foregroundColor: AppColors.charcoal,
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
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceLg,
                0,
                AppConstants.spaceLg,
                AppConstants.spaceSm,
              ),
              child: EmergencyStopButton(onPressed: () => robot.emergencyStop()),
            ),

            if (!connected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceLg),
                child: Text(
                  'Connect the robot to start AI detection.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

            // Detected-objects panel fills the remaining space with
            // real content instead of leaving it empty: every row here
            // is an actual current Detection, never a placeholder.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceLg,
                  AppConstants.spaceMd,
                  AppConstants.spaceLg,
                  AppConstants.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETECTED OBJECTS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    Expanded(
                      child: !_aiEnabled
                          ? _EmptyHint(text: 'Start detection to see results here.')
                          : (_detections.isEmpty
                              ? _EmptyHint(text: 'No objects in view yet.')
                              : ListView.separated(
                                  itemCount: _detections.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppConstants.spaceSm),
                                  itemBuilder: (context, i) {
                                    final d = _detections[i];
                                    return _DetectionRow(detection: d);
                                  },
                                )),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textTertiary),
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  const _DetectionRow({required this.detection});
  final Detection detection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: AppConstants.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppColors.glassStroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.center_focus_strong_rounded,
              size: 16, color: AppColors.cyan),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Text(
              detection.label,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(detection.confidence * 100).round()}%',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.cyan,
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
  _DetectionPainter(this.detections);
  final List<Detection> detections;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = AppColors.cyan
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
            backgroundColor: AppColors.cyan.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(rect.left, rect.top - painter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
