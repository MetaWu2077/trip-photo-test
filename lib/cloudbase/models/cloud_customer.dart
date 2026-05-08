/// 云端客户模型（MySQL customers 表）。
class CloudCustomer {
  final int id;
  final int userId;
  final String name;
  final String? phoneLast4;
  final String? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CloudCustomer({
    required this.id,
    required this.userId,
    required this.name,
    this.phoneLast4,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  factory CloudCustomer.fromJson(Map<String, dynamic> json) {
    return CloudCustomer(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      phoneLast4: json['phone_last4'] as String?,
      location: json['location'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_last4': phoneLast4,
      'location': location,
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
