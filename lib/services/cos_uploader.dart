import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tencent_cos/tencent_cos.dart';

/// Reads COS configuration from the loaded `.env` file.
class CosEnvConfig {
  final String appId;
  final String secretId;
  final String secretKey;
  final String region;
  final String bucket;
  final String domain;

  const CosEnvConfig({
    required this.appId,
    required this.secretId,
    required this.secretKey,
    required this.region,
    required this.bucket,
    required this.domain,
  });

  /// Load configuration from [dotenv].
  factory CosEnvConfig.fromDotenv() {
    return CosEnvConfig(
      appId: dotenv.env['COS_APP_ID'] ?? '',
      secretId: dotenv.env['COS_SECRET_ID'] ?? '',
      secretKey: dotenv.env['COS_SECRET_KEY'] ?? '',
      region: dotenv.env['COS_REGION'] ?? '',
      bucket: dotenv.env['COS_BUCKET'] ?? '',
      domain: dotenv.env['COS_DOMAIN'] ?? '',
    );
  }

  /// Returns true when all required fields are filled in.
  bool get isConfigured =>
      appId.isNotEmpty &&
      secretId.isNotEmpty &&
      secretKey.isNotEmpty &&
      region.isNotEmpty &&
      bucket.isNotEmpty;

  /// Missing field names (for user-facing error messages).
  List<String> get missingFields {
    final missing = <String>[];
    if (appId.isEmpty) missing.add('COS_APP_ID');
    if (secretId.isEmpty) missing.add('COS_SECRET_ID');
    if (secretKey.isEmpty) missing.add('COS_SECRET_KEY');
    if (region.isEmpty) missing.add('COS_REGION');
    if (bucket.isEmpty) missing.add('COS_BUCKET');
    return missing;
  }
}

/// Handles uploading files / bytes to Tencent COS.
class CosUploader {
  final CosEnvConfig config;
  bool _initialized = false;

  CosUploader(this.config);

  void _ensureInit() {
    if (_initialized) return;
    COS.init(
      config: COSConfig(
        appId: config.appId,
        secretId: config.secretId,
        secretKey: config.secretKey,
        region: config.region,
      ),
    );
    _initialized = true;
  }

  /// Upload raw [bytes] to COS with the given [objectKey].
  /// Returns the public URL of the uploaded object.
  Future<String> uploadBytes(Uint8List bytes, String objectKey) async {
    _ensureInit();
    await COS().putObject(
      bucket: config.bucket,
      objectKey: objectKey,
      data: bytes,
    );
    return _buildUrl(objectKey);
  }

  /// Upload a local file at [filePath] to COS with the given [objectKey].
  /// Returns the public URL of the uploaded object.
  Future<String> uploadFile(String filePath, String objectKey) async {
    _ensureInit();
    await COS().putObject(
      bucket: config.bucket,
      objectKey: objectKey,
      filePath: filePath,
    );
    return _buildUrl(objectKey);
  }

  String _buildUrl(String objectKey) {
    if (config.domain.isNotEmpty) {
      final base = config.domain.replaceAll(RegExp(r'/$'), '');
      return '$base/$objectKey';
    }
    // Default COS URL pattern
    return 'https://${config.bucket}.cos.${config.region}.myqcloud.com/$objectKey';
  }
}
