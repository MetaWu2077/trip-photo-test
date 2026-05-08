/// 云端用户模型（MySQL users 表）。
class CloudUser {
  final int id;
  final String phone;
  final String? nickName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CloudUser({
    required this.id,
    required this.phone,
    this.nickName,
    this.createdAt,
    this.updatedAt,
  });

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    return CloudUser(
      id: json['id'] as int,
      phone: json['phone'] as String,
      nickName: json['nick_name'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'nick_name': nickName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
