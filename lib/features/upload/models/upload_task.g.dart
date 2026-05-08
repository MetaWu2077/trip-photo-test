// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual implementation of Hive TypeAdapter (avoiding build_runner complexity)

part of 'upload_task.dart';

class UploadStatusAdapter extends TypeAdapter<UploadStatus> {
  @override
  final int typeId = 0;

  @override
  UploadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UploadStatus.pending;
      case 1:
        return UploadStatus.uploading;
      case 2:
        return UploadStatus.success;
      case 3:
        return UploadStatus.failed;
      default:
        return UploadStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, UploadStatus obj) {
    switch (obj) {
      case UploadStatus.pending:
        writer.writeByte(0);
        break;
      case UploadStatus.uploading:
        writer.writeByte(1);
        break;
      case UploadStatus.success:
        writer.writeByte(2);
        break;
      case UploadStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UploadTaskAdapter extends TypeAdapter<UploadTask> {
  @override
  final int typeId = 1;

  @override
  UploadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    T _field<T>(Map<int, dynamic> fields, int key, T defaultValue) {
      final v = fields[key];
      if (v is T) return v;
      return defaultValue;
    }
    // sessionId 在旧数据中不存在，降级兼容。
    final sessionId = _field<String>(fields, 9, '');
    // uploadOriginal 旧数据可能存为 "true"/"false" 字符串，防御性转换。
    final uploadOriginalRaw = fields[2];
    bool uploadOriginal;
    if (uploadOriginalRaw is bool) {
      uploadOriginal = uploadOriginalRaw;
    } else if (uploadOriginalRaw is String) {
      uploadOriginal = uploadOriginalRaw == 'true';
    } else {
      uploadOriginal = false;
    }
    // 兼容 status 字段旧数据中可能为 int/string/bool。
    final statusRaw = fields[5];
    UploadStatus status;
    if (statusRaw is UploadStatus) {
      status = statusRaw;
    } else if (statusRaw is int) {
      status = UploadStatus.values[statusRaw.clamp(0, UploadStatus.values.length - 1)];
    } else {
      status = UploadStatus.pending;
    }
    return UploadTask(
      id: _field<String>(fields, 0, ''),
      sessionId: sessionId,
      filePath: _field<String>(fields, 1, ''),
      uploadOriginal: uploadOriginal,
      thumbKey: _field<String?>(fields, 3, null),
      originalKey: _field<String?>(fields, 4, null),
      status: status,
      createdAt: _field<DateTime?>(fields, 6, null) ?? DateTime.now(),
      retryCount: _field<int>(fields, 7, 0),
      errorMessage: _field<String?>(fields, 8, null),
    );
  }

  @override
  void write(BinaryWriter writer, UploadTask obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.uploadOriginal)
      ..writeByte(4)
      ..write(obj.thumbKey)
      ..writeByte(5)
      ..write(obj.originalKey)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.retryCount)
      ..writeByte(9)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
