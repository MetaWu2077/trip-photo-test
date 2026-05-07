import 'package:hive/hive.dart';

/// 订单状态。
@HiveType(typeId: 2)
enum OrderStatus {
  @HiveField(0)
  pending, // 待处理

  @HiveField(1)
  active, // 进行中（已选为当前 session）

  @HiveField(2)
  completed, // 已完成（拍摄结束）
}

/// 一次拍摄会话，关联一个预约订单。
@HiveType(typeId: 3)
class OrderSession extends HiveObject {
  /// 订单 ID（用作 sessionId）。
  @HiveField(0)
  final String id;

  /// 客户名称。
  @HiveField(1)
  final String customerName;

  /// 拍摄地点。
  @HiveField(2)
  final String location;

  /// 订单状态。
  @HiveField(3)
  OrderStatus status;

  /// session 开始时间。
  @HiveField(4)
  DateTime? startedAt;

  /// session 结束时间。
  @HiveField(5)
  DateTime? endedAt;

  /// 客户手机尾号后四位。
  @HiveField(7)
  final String phoneLast4;

  /// 创建时间。
  @HiveField(6)
  final DateTime createdAt;

  OrderSession({
    required this.id,
    required this.customerName,
    required this.location,
    required this.phoneLast4,
    this.status = OrderStatus.pending,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return '待处理';
      case OrderStatus.active:
        return '进行中';
      case OrderStatus.completed:
        return '已完成';
    }
  }
}

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 2;

  @override
  OrderStatus read(BinaryReader reader) {
    return OrderStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    writer.writeByte(obj.index);
  }
}

class OrderSessionAdapter extends TypeAdapter<OrderSession> {
  @override
  final int typeId = 3;

  @override
  OrderSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderSession(
      id: fields[0] as String,
      customerName: fields[1] as String,
      location: fields[2] as String,
      status: fields[3] as OrderStatus,
      startedAt: fields[4] as DateTime?,
      endedAt: fields[5] as DateTime?,
      createdAt: fields[6] as DateTime,
      phoneLast4: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, OrderSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.startedAt)
      ..writeByte(5)
      ..write(obj.endedAt)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.phoneLast4);
  }
}
