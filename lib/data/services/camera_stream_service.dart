import 'dart:async';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

/// Reachability state of the ESP32-CAM stream endpoint.
enum CameraLinkState { idle, connecting, streaming, unreachable }

/// Talks to the ESP32-CAM over Wi-Fi only.
///
/// IMPORTANT: this service never touches the phone's camera hardware —
/// it exclusively fetches/streams from an HTTP(S) URL that the ESP32-CAM
/// module serves on the local network (typically
/// `http://<esp32-ip>:81/stream` for MJPEG). This service only tracks
/// connectivity/latency for that URL; actual frame decoding happens in
/// [MjpegStreamView], which parses the raw multipart JPEG boundary
/// stream by hand and paints frames via `Image.memory` (plain
/// `Image.network` cannot decode a multipart MJPEG stream).
///
/// Latency is measured by timing a lightweight GET probe against the
/// stream host's origin, which also doubles as a reachability check for
/// the "Camera Connected" status card on the dashboard.
class CameraStreamService {
  CameraStreamService();

  final _stateController = StreamController<CameraLinkState>.broadcast();
  final _latencyController = StreamController<int>.broadcast();

  CameraLinkState _state = CameraLinkState.idle;
  Timer? _healthCheckTimer;
  String _streamUrl = AppConstants.defaultCameraUrlHint;

  Stream<CameraLinkState> get stateStream => _stateController.stream;
  Stream<int> get latencyStream => _latencyController.stream;
  CameraLinkState get state => _state;
  String get streamUrl => _streamUrl;
  bool get isStreaming => _state == CameraLinkState.streaming;

  void _setState(CameraLinkState s) {
    _state = s;
    _stateController.add(s);
  }

  void updateStreamUrl(String url) {
    _streamUrl = url;
  }

  /// Derives the base HTTP origin (scheme + host + port) from the
  /// configured MJPEG stream URL, for lightweight health probes.
  String get _originForProbe {
    try {
      final uri = Uri.parse(_streamUrl);
      return uri.replace(path: '/', query: '').toString();
    } catch (_) {
      return _streamUrl;
    }
  }

  /// Probes the ESP32-CAM host and begins periodic latency polling.
  /// Actual frame rendering is handled in the widget layer (a
  /// motion-jpeg-capable `Image.network` widget) pointed at [streamUrl];
  /// this method only tracks connectivity/latency for the overlay.
  Future<void> connect() async {
    _setState(CameraLinkState.connecting);
    final reachable = await _probeOnce();
    _setState(reachable ? CameraLinkState.streaming : CameraLinkState.unreachable);

    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(AppConstants.statusPollInterval, (_) async {
      final ok = await _probeOnce();
      _setState(ok ? CameraLinkState.streaming : CameraLinkState.unreachable);
    });
  }

  Future<bool> _probeOnce() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse(_originForProbe))
          .timeout(AppConstants.httpTimeout);
      stopwatch.stop();
      _latencyController.add(stopwatch.elapsedMilliseconds);
      return response.statusCode < 500;
    } catch (_) {
      stopwatch.stop();
      _latencyController.add(-1);
      return false;
    }
  }

  void disconnect() {
    _healthCheckTimer?.cancel();
    _setState(CameraLinkState.idle);
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _stateController.close();
    _latencyController.close();
  }
}
