// lib/core/services/cloudinary_upload_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../models/photo_models.dart';
import 'api_service.dart';

class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryUploadService {
  final ApiService api;
  // Separate Dio instance for talking to Cloudinary directly — the ApiService
  // Dio is pinned to our backend baseUrl and auto-attaches our JWT, neither
  // of which belongs on a request to api.cloudinary.com.
  final Dio _uploadDio = Dio();

  CloudinaryUploadService(this.api);

  Future<CloudinarySignatureResponse> requestSignature(String category) {
    return api.getCloudinarySignature(category);
  }

  Future<({String publicId, String secureUrl})> uploadRaw(
    File file,
    CloudinarySignatureResponse sig, {
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'api_key': sig.apiKey,
      'timestamp': sig.timestamp,
      'signature': sig.signature,
      'folder': sig.folder,
    });

    Response cloudinaryRes;
    try {
      cloudinaryRes = await _uploadDio.post(
        'https://api.cloudinary.com/v1_1/${sig.cloudName}/image/upload',
        data: formData,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw CloudinaryUploadException(_networkErrorMessage(e));
    }

    return (
      publicId: cloudinaryRes.data['public_id'] as String,
      secureUrl: cloudinaryRes.data['secure_url'] as String,
    );
  }

  Future<Exercise> uploadExercisePhoto(
    File file,
    String exerciseId, {
    ProgressCallback? onSendProgress,
  }) async {
    final CloudinarySignatureResponse sig;
    try {
      sig = await requestSignature('exercise-photos');
    } on DioException catch (e) {
      throw CloudinaryUploadException(
          'Не удалось получить разрешение на загрузку: ${_networkErrorMessage(e)}');
    }

    final uploaded = await uploadRaw(file, sig, onSendProgress: onSendProgress);

    try {
      return await api.updateExercisePhoto(
        exerciseId,
        publicId: uploaded.publicId,
        secureUrl: uploaded.secureUrl,
      );
    } on DioException catch (e) {
      // The Cloudinary asset already exists at this point — only linking it
      // to the exercise failed, worth saying explicitly.
      throw CloudinaryUploadException(
          'Фото загружено, но не удалось привязать к упражнению: ${_networkErrorMessage(e)}');
    }
  }

  String _networkErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Истекло время ожидания. Проверьте соединение и попробуйте снова';
      case DioExceptionType.connectionError:
        return 'Нет соединения с интернетом';
      default:
        break;
    }
    final status = e.response?.statusCode;
    if (status == 413) {
      return 'Файл слишком большой для загрузки';
    }
    if (status != null && status >= 400 && status < 500) {
      return 'Не удалось загрузить фото (ошибка $status)';
    }
    return 'Не удалось загрузить фото. Попробуйте позже';
  }
}
