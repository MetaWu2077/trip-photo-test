import '../cloudbase_client.dart';

/// 云端预约/订单模型（MySQL bookings 表）。
class CloudBooking {
  final int id;
  final int userId;
  final int? customerId;
  final DateTime bookDate;
  final String location;
  final String status;
  final String? note;
  final DateTime? createdAt;
  final String? customerName;

  CloudBooking({
    required this.id,
    required this.userId,
    this.customerId,
    required this.bookDate,
    this.location = '',
    this.status = 'pending',
    this.note,
    this.createdAt,
    this.customerName,
  });

  factory CloudBooking.fromJson(Map<String, dynamic> json) {
    return CloudBooking(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      customerId: json['customer_id'] as int?,
      bookDate: DateTime.parse(json['book_date'] as String),
      location: (json['location'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      note: json['note'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      customerName: json['customer_name'] as String?,
    );
  }
}

/// 云端预约仓库。
class CloudBookingRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  Future<List<CloudBooking>> getBookings(int userId) async {
    final resp = await _client.get('/bookings', queryParams: {
      'userId': userId.toString(),
    });
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((e) => CloudBooking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CloudBooking?> createBooking({
    required int userId,
    int? customerId,
    required DateTime bookDate,
    String location = '',
    String status = 'pending',
    String note = '',
  }) async {
    final resp = await _client.post('/bookings', body: {
      'userId': userId,
      'customerId': customerId,
      'bookDate': bookDate.toIso8601String().substring(0, 10),
      'location': location,
      'status': status,
      'note': note,
    });
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudBooking.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<bool> updateBooking(int id, {String? status, String? location, String? note}) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (location != null) body['location'] = location;
    if (note != null) body['note'] = note;
    final resp = await _client.patch('/bookings/$id', body: body);
    return resp.isSuccess;
  }

  Future<bool> deleteBooking(int id) async {
    final resp = await _client.delete('/bookings/$id');
    return resp.isSuccess;
  }
}
