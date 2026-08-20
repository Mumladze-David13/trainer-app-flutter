// lib/core/models/photo_models.dart

/// Response from POST /api/cloudinary/signature — everything needed to do a
/// signed direct upload to Cloudinary without exposing the API secret.
class CloudinarySignatureResponse {
  final int timestamp;
  final String signature;
  final String apiKey;
  final String cloudName;
  final String folder;

  CloudinarySignatureResponse({
    required this.timestamp,
    required this.signature,
    required this.apiKey,
    required this.cloudName,
    required this.folder,
  });

  factory CloudinarySignatureResponse.fromJson(Map<String, dynamic> j) =>
      CloudinarySignatureResponse(
        timestamp: j['timestamp'] is int
            ? j['timestamp']
            : int.parse(j['timestamp'].toString()),
        signature: j['signature'] ?? '',
        apiKey: j['apiKey'] ?? '',
        cloudName: j['cloudName'] ?? '',
        folder: j['folder'] ?? '',
      );
}
