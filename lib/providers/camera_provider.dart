import 'package:flutter/foundation.dart';

import '../data/services/camera_stream_service.dart';
import '../data/services/preferences_service.dart';

/// Exposes ESP32-CAM connectivity + latency to the UI layer.
///
/// This provider never touches `package:camera` or any phone-camera
/// API — its only job is tracking the reachability/latency of the
/// Wi-Fi MJPEG stream URL configured in Settings.
class CameraProvider extends ChangeNotifier {
  CameraProvider(this._service, this._preferences) {
    _streamUrl = _preferences.cameraUrl;
    _service.updateStreamUrl(_streamUrl);
    _service.stateStream.listen((state) {
      _linkState = state;
      notifyListeners();
    });
    _service.latencyStream.listen((ms) {
      _latencyMs = ms;
      notifyListeners();
    });
  }

  final CameraStreamService _service;
  final PreferencesService _preferences;

  CameraLinkState _linkState = CameraLinkState.idle;
  int _latencyMs = -1;
  late String _streamUrl;

  CameraLinkState get linkState => _linkState;
  bool get isStreaming => _linkState == CameraLinkState.streaming;
  int get latencyMs => _latencyMs;
  String get streamUrl => _streamUrl;

  Future<void> connect() async {
    await _service.connect();
  }

  void disconnect() {
    _service.disconnect();
  }

  Future<void> updateStreamUrl(String url) async {
    _streamUrl = url;
    _service.updateStreamUrl(url);
    await _preferences.setCameraUrl(url);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
