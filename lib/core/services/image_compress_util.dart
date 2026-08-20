// lib/core/services/image_compress_util.dart
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses an image before upload. Falls back to the original file if
/// compression fails or yields nothing — compression is an optimization,
/// not a requirement.
Future<File> compressImageForUpload(File file) async {
  final targetPath = '${file.path}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  try {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (result == null) return file;
    return File(result.path);
  } catch (_) {
    return file;
  }
}
