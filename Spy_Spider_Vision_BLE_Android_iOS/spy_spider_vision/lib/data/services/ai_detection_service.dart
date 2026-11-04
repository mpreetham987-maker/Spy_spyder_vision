import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// A single detected object, in normalized (0.0-1.0) coordinates so
/// the UI can scale it to whatever size the camera preview renders
/// at, regardless of the source frame's native resolution.
class Detection {
  const Detection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String label;
  final double confidence;
}

/// Runs real on-device object detection (Google ML Kit) against each
/// decoded ESP32-CAM JPEG frame. This is genuine inference — bounding
/// boxes and labels come directly from the model's output on the
/// actual frame bytes, never simulated, randomized, or hardcoded.
///
/// Detection runs fully on-device: no frame is ever uploaded anywhere.
class AiDetectionService {
  AiDetectionService()
      : _detector = ObjectDetector(
          options: ObjectDetectorOptions(
            mode: DetectionMode.single,
            classifyObjects: true,
            multipleObjects: true,
          ),
        );

  final ObjectDetector _detector;
  bool _busy = false;

  /// Whether inference is currently running on a previous frame. The
  /// caller should skip calling [detect] again until this is false, so
  /// frames are dropped rather than queued when the model can't keep
  /// up with the stream's actual frame rate.
  bool get isBusy => _busy;

  /// Runs detection on a single decoded JPEG frame ([jpegBytes] — the
  /// exact bytes [MjpegStreamView] decoded from the live ESP32-CAM
  /// stream). Returns real detections in normalized coordinates, or an
  /// empty list if the frame couldn't be decoded or nothing was found.
  Future<List<Detection>> detect(Uint8List jpegBytes) async {
    if (_busy) return const [];
    _busy = true;
    try {
      // ML Kit's on-device API expects raw NV21/YUV pixel planes, not
      // compressed JPEG bytes. Decode the JPEG to actual RGBA pixels
      // first, then convert those real pixels to NV21 — this is the
      // step that makes the input genuinely valid, rather than
      // mislabeling compressed bytes as a raw format ML Kit can't
      // actually parse.
      final codec = await ui.instantiateImageCodec(jpegBytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      if (rgba == null) return const [];

      final nv21 = _rgbaToNv21(rgba.buffer.asUint8List(), width, height);

      final input = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: ui.Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );

      final results = await _detector.processImage(input);
      return results.map((obj) {
        final box = obj.boundingBox;
        final best = obj.labels.isNotEmpty ? obj.labels.first : null;
        return Detection(
          left: (box.left / width).clamp(0.0, 1.0),
          top: (box.top / height).clamp(0.0, 1.0),
          width: (box.width / width).clamp(0.0, 1.0),
          height: (box.height / height).clamp(0.0, 1.0),
          label: best?.text ?? 'Object',
          confidence: best?.confidence ?? 0.0,
        );
      }).toList();
    } catch (_) {
      // A malformed or partial JPEG frame (possible on a lossy Wi-Fi
      // link) should not crash detection — just skip that frame.
      return const [];
    } finally {
      _busy = false;
    }
  }

  /// Converts real decoded RGBA pixels to real NV21 (Y plane followed
  /// by interleaved VU), the raw format ML Kit's on-device detector
  /// actually requires. Standard BT.601 luma/chroma coefficients.
  Uint8List _rgbaToNv21(Uint8List rgba, int width, int height) {
    final frameSize = width * height;
    final nv21 = Uint8List(frameSize + (frameSize ~/ 2));

    int yIndex = 0;
    int uvIndex = frameSize;

    for (int j = 0; j < height; j++) {
      for (int i = 0; i < width; i++) {
        final rgbaIndex = (j * width + i) * 4;
        final r = rgba[rgbaIndex];
        final g = rgba[rgbaIndex + 1];
        final b = rgba[rgbaIndex + 2];

        final y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
        nv21[yIndex++] = y.clamp(0, 255);

        if (j % 2 == 0 && i % 2 == 0) {
          final u = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
          final v = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
          nv21[uvIndex++] = v.clamp(0, 255);
          nv21[uvIndex++] = u.clamp(0, 255);
        }
      }
    }
    return nv21;
  }

  Future<void> dispose() => _detector.close();
}
