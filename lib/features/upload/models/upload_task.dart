import 'package:hive/hive.dart';

part 'upload_task.g.dart';

/// 上传任务状态。
@HiveType(typeId: 0)
enum UploadStatus {
  @HiveField(0)
  pending, // 等待中

  @HiveField(1)
  uploading, // 上传中

  @HiveField(2)
  success, // 成功

  @HiveField(3)
  failed, // 失败
}

/// 单个上传任务（持久化到 Hive）。
@HiveType(typeId: 1)
class UploadTask extends HiveObject {
  /// 任务 ID（时间戳+随机数）。
  @HiveField(0)
  final String id;

  /// 关联的 sessionId（即订单 ID）。
  @HiveField(9)
  final String sessionId;

  /// 原始图片路径。
  @HiveField(1)
  final String filePath;

  /// 是否上传原图。
  @HiveField(2)
  final bool uploadOriginal;

  /// 缩略图 COS key。
  @HiveField(3)
  String? thumbKey;

  /// 原图 COS key（仅 uploadOriginal=true 时有效）。
  @HiveField(4)
  String? originalKey;

  /// 当前状态。
  @HiveField(5)
  UploadStatus status;

  /// 创建时间。
  @HiveField(6)
  final DateTime createdAt;

  /// 重试次数。
  @HiveField(7)
  int retryCount;

  /// 失败时的错误信息。
  @HiveField(8)
  String? errorMessage;

  UploadTask({
    required this.id,
    required this.sessionId,
    required this.filePath,
    required this.uploadOriginal,
    this.thumbKey,
    this.originalKey,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  String get statusLabel {
    switch (status) {
      case UploadStatus.pending:
        return '等待中';
      case UploadStatus.uploading:
        return '上传中';
      case UploadStatus.success:
        return '成功';
      case UploadStatus.failed:
        return '失败';
    }
  }
}
