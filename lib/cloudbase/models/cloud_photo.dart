/// 云端照片模型（MySQL photos 表）。
enum CloudPhotoUploadStatus {
  pending,
  uploading,
  success,
  failed,
}

class CloudPhoto {
  final int id;
  final int sessionId;
  final String? thumbKey;
  final String? originalKey;
  final String? filePath;
  final CloudPhotoUploadStatus uploadStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CloudPhoto({
    required this.id,
    required this.sessionId,
    this.thumbKey,
    this.originalKey,
    this.filePath,
    this.uploadStatus = CloudPhotoUploadStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  factory CloudPhoto.fromJson(Map<String, dynamic> json) {
    return CloudPhoto(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      thumbKey: json['thumb_key'] as String?,
      originalKey: json['original_key'] as String?,
      filePath: json['file_path'] as String?,
      uploadStatus: _parseUploadStatus(json['upload_status'] as String?),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'thumb_key': thumbKey,
      'original_key': originalKey,
      'file_path': filePath,
      'upload_status': uploadStatus.name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static CloudPhotoUploadStatus _parseUploadStatus(String? value) {
    switch (value) {
      case 'uploading':
        return CloudPhotoUploadStatus.uploading;
      case 'success':
        return CloudPhotoUploadStatus.success;
      case 'failed':
        return CloudPhotoUploadStatus.failed;
      default:
        return CloudPhotoUploadStatus.pending;
    }
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
