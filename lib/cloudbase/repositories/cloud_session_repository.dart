import '../cloudbase_client.dart';
import '../models/cloud_session.dart';

/// 云端会话仓库。
class CloudSessionRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 获取当前摄影师的所有会话列表。
  Future<List<CloudSession>> getSessions(int userId) async {
    final resp = await _client.get('/sessions', queryParams: {
      'userId': userId.toString(),
    });
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((e) => CloudSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 创建会话。
  Future<int?> createSession({
    required int userId,
    int? customerId,
    int? shiftId,
    String? cosDirPrefix,
    String status = 'pending',
  }) async {
    final resp = await _client.post('/sessions', body: {
      'userId': userId,
      'customerId': customerId,
      'shiftId': shiftId,
      'cosDirPrefix': cosDirPrefix,
      'status': status,
    });
    if (!resp.isSuccess || resp.data == null) return null;
    return (resp.data as Map<String, dynamic>)['id'] as int?;
  }

  /// 更新会话状态。
  Future<bool> updateSession(int sessionId,
      {String? status, String? cosDirPrefix, DateTime? startedAt, DateTime? endedAt}) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (cosDirPrefix != null) body['cosDirPrefix'] = cosDirPrefix;
    if (startedAt != null) body['startedAt'] = startedAt.toIso8601String();
    if (endedAt != null) body['endedAt'] = endedAt.toIso8601String();

    final resp = await _client.patch('/sessions/$sessionId', body: body);
    return resp.isSuccess;
  }

  /// 将会话标记为进行中。
  Future<bool> startSession(int sessionId) async {
    return updateSession(
      sessionId,
      status: 'active',
      startedAt: DateTime.now(),
    );
  }

  /// 将会话标记为已完成。
  Future<bool> completeSession(int sessionId) async {
    return updateSession(
      sessionId,
      status: 'completed',
      endedAt: DateTime.now(),
    );
  }

  /// 获取当前用户进行中的 session（未完成/未收工）。
  Future<CloudSession?> getActiveSession(int userId) async {
    final sessions = await getSessions(userId);
    return sessions.where((s) => s.status == CloudSessionStatus.active).firstOrNull;
  }
}
