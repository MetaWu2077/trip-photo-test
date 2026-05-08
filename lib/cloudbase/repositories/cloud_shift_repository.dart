import '../cloudbase_client.dart';

/// 云端班次模型（MySQL shifts 表）。
class CloudShift {
  final int id;
  final int userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int photoCount;
  final DateTime? createdAt;

  CloudShift({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.photoCount = 0,
    this.createdAt,
  });

  bool get isActive => endedAt == null;

  factory CloudShift.fromJson(Map<String, dynamic> json) {
    return CloudShift(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      photoCount: (json['photo_count'] as int?) ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}

/// 云端班次仓库。
class CloudShiftRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 获取班次列表。
  Future<List<CloudShift>> getShifts(int userId, {String? date}) async {
    final params = <String, String>{'userId': userId.toString()};
    if (date != null) params['date'] = date;
    final resp = await _client.get('/shifts', queryParams: params);
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((e) => CloudShift.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 上工（创建新班次）。
  Future<CloudShift?> clockIn(int userId) async {
    final resp = await _client.post('/shifts', body: {'userId': userId});
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudShift.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 收工。
  Future<CloudShift?> clockOut(int shiftId) async {
    final resp = await _client.patch('/shifts/$shiftId', body: {'action': 'clock_out'});
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudShift.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 获取当前用户今日未收工的班次。
  Future<CloudShift?> getActiveShift(int userId) async {
    final shifts = await getShifts(userId, date: _today());
    return shifts.where((s) => s.isActive).firstOrNull;
  }

  /// 追加照片计数。
  Future<void> incrementPhotoCount(int shiftId, {int delta = 1}) async {
    await _client.patch('/shifts/$shiftId', body: {'photoCount': delta});
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
}
