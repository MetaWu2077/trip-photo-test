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
    // sessionId 在旧数据中不存在，降级兼容。
    final sessionId = fields[9] as String? ?? '';
    return UploadTask(
      id: fields[0] as String,
      sessionId: sessionId,
      filePath: fields[1] as String,
      uploadOriginal: fields[2] as bool,
      thumbKey: fields[3] as String?,
      originalKey: fields[4] as String?,
      status: fields[5] as UploadStatus,
      createdAt: fields[6] as DateTime,
      retryCount: fields[7] as int? ?? 0,
      errorMessage: fields[8] as String?,
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
