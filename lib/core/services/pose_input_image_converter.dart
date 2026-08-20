// lib/core/services/pose_input_image_converter.dart
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Converts a camera frame into an [InputImage] ML Kit can process.
///
/// image.format.raw doesn't reliably map to InputImageFormat via
/// fromRawValue on all vendors (e.g. MediaTek) even when the camera is
/// opened with imageFormatGroup forced to nv21/bgra8888, so the format is
/// set explicitly per platform instead of trusting it. On Android the
/// camera plugin also doesn't always deliver a pre-merged NV21 buffer even
/// with imageFormatGroup: nv21 (observed as 3 separate Y/U/V planes on some
/// vendors) — naively concatenating those planes ignores row/pixel stride
/// and produces garbage bytes that ML Kit silently fails to find any pose
/// in, so a proper YUV420->NV21 conversion is used instead.
InputImage? convertCameraImageToInputImage(
    CameraImage image, CameraDescription camera) {
  final rotation =
      InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;

  final format = defaultTargetPlatform == TargetPlatform.android
      ? InputImageFormat.nv21
      : InputImageFormat.bgra8888;

  final isMultiPlaneAndroid =
      defaultTargetPlatform == TargetPlatform.android && image.planes.length > 1;

  final bytes = isMultiPlaneAndroid
      ? _yuv420ToNv21(image)
      : _concatenatePlanes(image.planes);

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow:
          isMultiPlaneAndroid ? image.width : image.planes.first.bytesPerRow,
    ),
  );
}

Uint8List _yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final nv21 = Uint8List(
      width * height + 2 * ((width + 1) ~/ 2) * ((height + 1) ~/ 2));

  int idY = 0;
  final yRowStride = yPlane.bytesPerRow;
  final yPixelStride = yPlane.bytesPerPixel ?? 1;
  for (int y = 0; y < height; y++) {
    final rowStart = y * yRowStride;
    for (int x = 0; x < width; x++) {
      nv21[idY++] = yPlane.bytes[rowStart + x * yPixelStride];
    }
  }

  final uvWidth = (width + 1) ~/ 2;
  final uvHeight = (height + 1) ~/ 2;
  final uRowStride = uPlane.bytesPerRow;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final vRowStride = vPlane.bytesPerRow;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;

  int idUV = width * height;
  for (int y = 0; y < uvHeight; y++) {
    final uRowStart = y * uRowStride;
    final vRowStart = y * vRowStride;
    for (int x = 0; x < uvWidth; x++) {
      nv21[idUV++] = vPlane.bytes[vRowStart + x * vPixelStride];
      nv21[idUV++] = uPlane.bytes[uRowStart + x * uPixelStride];
    }
  }

  return nv21;
}

Uint8List _concatenatePlanes(List<Plane> planes) {
  int totalLength = 0;
  for (final plane in planes) {
    totalLength += plane.bytes.length;
  }
  final result = Uint8List(totalLength);
  int offset = 0;
  for (final plane in planes) {
    result.setRange(offset, offset + plane.bytes.length, plane.bytes);
    offset += plane.bytes.length;
  }
  return result;
}
