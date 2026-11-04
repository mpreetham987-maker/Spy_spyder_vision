import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';

/// Renders a live Motion-JPEG stream served by an ESP32-CAM over
/// Wi-Fi (`http://<esp32-ip>:81/stream`).
///
/// This widget performs a raw HTTP GET against the MJPEG endpoint and
/// manually splits the multipart `--frame` boundary stream into
/// individual JPEG images, repainting as each new frame arrives. It
/// deliberately does NOT use `package:camera`, `image_picker`, or any
/// phone-camera API — the only camera involved is the physical
/// ESP32-CAM module on the robot.
class MjpegStreamView extends StatefulWidget {
  const MjpegStreamView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
    this.onFrame,
  });

  final String streamUrl;
  final BoxFit fit;

  /// Called with each real decoded JPEG frame as it arrives, so a
  /// caller (e.g. an on-device AI detector) can run inference on the
  /// actual stream — never a simulated or fake frame.
  final ValueChanged<Uint8List>? onFrame;

  @override
  State<MjpegStreamView> createState() => _MjpegStreamViewState();
}

class _MjpegStreamViewState extends State<MjpegStreamView> {
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  Uint8List? _currentFrame;
  bool _hasError = false;

  final List<int> _byteBuffer = [];

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(covariant MjpegStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _stopStream();
      _startStream();
    }
  }

  void _startStream() async {
    setState(() => _hasError = false);
    _byteBuffer.clear();

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await _client!.send(request).timeout(AppConstants.httpTimeout);

      if (response.statusCode != 200) {
        _fail();
        return;
      }

      if (!mounted) {
        _client?.close();
        return;
      }

      _subscription = response.stream.listen(
        _onData,
        onError: (_) => _fail(),
        onDone: () {
          if (mounted) _fail();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _fail();
    }
  }

  void _onData(List<int> chunk) {
    _byteBuffer.addAll(chunk);

    // JPEG frames begin with FFD8 and end with FFD9. We scan the
    // rolling buffer for a complete frame, extract it, and discard
    // everything up to and including that frame's end marker.
    while (true) {
      final start = _indexOfMarker(_byteBuffer, 0xFF, 0xD8);
      if (start == -1) {
        // No frame start yet; keep buffer bounded.
        if (_byteBuffer.length > 2000000) _byteBuffer.clear();
        return;
      }
      final end = _indexOfMarker(_byteBuffer, 0xFF, 0xD9, start: start + 2);
      if (end == -1) {
        // Frame incomplete — drop any garbage before the start marker
        // and wait for more data.
        if (start > 0) _byteBuffer.removeRange(0, start);
        return;
      }

      final frameBytes = Uint8List.fromList(
        _byteBuffer.sublist(start, end + 2),
      );
      _byteBuffer.removeRange(0, end + 2);

      if (mounted) {
        setState(() {
          _currentFrame = frameBytes;
          _hasError = false;
        });
        widget.onFrame?.call(frameBytes);
      }
    }
  }

  int _indexOfMarker(List<int> data, int a, int b, {int start = 0}) {
    for (int i = start; i < data.length - 1; i++) {
      if (data[i] == a && data[i + 1] == b) return i;
    }
    return -1;
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _hasError = true);
  }

  void _stopStream() {
    _subscription?.cancel();
    _client?.close();
    _subscription = null;
    _client = null;
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _currentFrame == null) {
      return _StreamPlaceholder(
        icon: Icons.signal_wifi_off_rounded,
        message: 'No signal from ESP32-CAM',
        onRetry: () {
          _stopStream();
          _startStream();
        },
      );
    }

    if (_currentFrame == null) {
      return const _StreamPlaceholder(
        icon: Icons.wifi_tethering_rounded,
        message: 'Connecting to camera stream…',
        showSpinner: true,
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _StreamPlaceholder extends StatelessWidget {
  const _StreamPlaceholder({
    required this.icon,
    required this.message,
    this.showSpinner = false,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final bool showSpinner;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.charcoal,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.cyan,
              ),
            )
          else
            Icon(icon, size: 34, color: AppColors.textTertiary),
          const SizedBox(height: AppConstants.spaceMd),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
