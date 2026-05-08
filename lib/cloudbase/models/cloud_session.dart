/// 云端会话模型（MySQL sessions 表）。
enum CloudSessionStatus {
  pending,
  active,
  completed,
}

class CloudSession {
  final int id;
  final int userId;
  final int? customerId;
  final String? cosDirPrefix;
  final CloudSessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// 左连接 customers 表的 name 字段。
  final String? customerName;

  CloudSession({
    required this.id,
    required this.userId,
    this.customerId,
    this.cosDirPrefix,
    this.status = CloudSessionStatus.pending,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
    this.customerName,
  });

  factory CloudSession.fromJson(Map<String, dynamic> json) {
    return CloudSession(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      customerId: json['customer_id'] as int?,
      cosDirPrefix: json['cos_dir_prefix'] as String?,
      status: _parseStatus(json['status'] as String?),
      startedAt: _parseDateTime(json['started_at']),
      endedAt: _parseDateTime(json['ended_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      customerName: json['customer_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'customer_id': customerId,
      'cos_dir_prefix': cosDirPrefix,
      'status': status.name,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static CloudSessionStatus _parseStatus(String? value) {
    switch (value) {
      case 'active':
        return CloudSessionStatus.active;
      case 'completed':
        return CloudSessionStatus.completed;
      default:
        return CloudSessionStatus.pending;
    }
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
