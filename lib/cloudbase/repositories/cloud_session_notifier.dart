import 'package:flutter/foundation.dart';
import '../cloudbase_client.dart';
import '../models/cloud_session.dart';
import 'cloud_session_repository.dart';

/// CloudBase 会话列表状态管理。
/// 负责从云端加载/创建/更新会话，对接 trip-api。
class CloudSessionNotifier extends ChangeNotifier {
  final CloudSessionRepository _repo = CloudSessionRepository();
  final CloudBaseClient _client = CloudBaseClient.instance;

  List<CloudSession> _sessions = [];
  bool _loading = false;
  String? _error;

  List<CloudSession> get sessions => _sessions;
  bool get loading => _loading;
  String? get error => _error;

  /// 检查是否已登录（有 currentUserId）
  bool get isLoggedIn => _client.currentUserId != null;

  /// 加载当前用户的所有会话。
  Future<void> loadSessions() async {
    final userId = _client.currentUserId;
    if (userId == null) {
      _error = '未登录';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _repo.getSessions(userId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 创建新会话。
  Future<CloudSession?> createSession({
    int? customerId,
    required String cosDirPrefix,
    String status = 'pending',
  }) async {
    final userId = _client.currentUserId;
    if (userId == null) return null;

    final id = await _repo.createSession(
      userId: userId,
      customerId: customerId,
      cosDirPrefix: cosDirPrefix,
      status: status,
    );

    if (id != null) {
      await loadSessions();
    }
    return _sessions.firstWhere((s) => s.id == id, orElse: () => _sessions.first);
  }

  /// 更新会话状态。
  Future<bool> updateSession(
    int sessionId, {
    String? status,
    String? cosDirPrefix,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final ok = await _repo.updateSession(
      sessionId,
      status: status,
      cosDirPrefix: cosDirPrefix,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    if (ok) await loadSessions();
    return ok;
  }

  /// 激活会话（started -> active）
  Future<bool> startSession(int sessionId) async {
    return updateSession(sessionId, status: 'active');
  }

  /// 完成会话（ended -> completed）
  Future<bool> completeSession(int sessionId) async {
    return updateSession(sessionId, status: 'completed');
  }

  /// 设置当前登录用户（登录后调用）。
  void setCurrentUser(int userId) {
    _client.currentUserId = userId;
    notifyListeners();
  }

  /// 登出。
  void signOut() {
    _client.currentUserId = null;
    _sessions = [];
    _error = null;
    notifyListeners();
  }
}
