import 'package:flutter/foundation.dart';
import '../../cloudbase/cloudbase_client.dart';
import '../../cloudbase/models/cloud_session.dart';
import '../../cloudbase/repositories/cloud_session_repository.dart';

/// 当前活跃 Session 管理器（内存级，APP 级别单例）。
/// 统一使用云端 CloudSession。
class SessionManager {
  static final SessionManager _instance = SessionManager._();
  factory SessionManager() => _instance;
  SessionManager._();

  final _sessionRepo = CloudSessionRepository();

  /// 进行中的云端 CloudSession。
  CloudSession? _activeSession;

  CloudSession? get activeSession => _activeSession;
  bool get hasActiveSession => _activeSession != null;

  /// 设置当前活跃 session（不创建，仅激活已有 session）。
  Future<void> setActiveSession(CloudSession session) async {
    await _sessionRepo.startSession(session.id);
    _activeSession = session;
    debugPrint('[SessionManager] setActiveSession: id=${session.id}');
  }

  /// 当前 CloudSession 的 int id（供 CloudPhotoRepository 用）。
  int? get activeCloudSessionId => _activeSession?.id;

  /// 当前 Session 的 String id（供 COS 路径等兼容用）。
  String get activeSessionId => _activeSession?.id.toString() ?? '';

  /// 当前客户名（供 COS 路径等用）。
  String get activeCustomerName => _activeSession?.customerName ?? 'unknown';

  /// 启动（创建）一个新的云端 session 并设为当前活跃。
  /// [customerId] 可选（有客户时传入，无客户则为 null）。
  /// [shiftId] 可选（关联上工班次）。
  Future<void> startSession({int? customerId, int? shiftId}) async {
    await _clearActive();

    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) {
      throw StateError('未登录，无 userId');
    }

    final sessionId = await _sessionRepo.createSession(
      userId: userId,
      customerId: customerId,
      shiftId: shiftId,
      status: 'active',
    );
    if (sessionId == null) {
      throw StateError('创建 CloudSession 失败');
    }

    // 重新查询以获取完整对象（含 customerName 左连接结果）。
    final sessions = await _sessionRepo.getSessions(userId);
    _activeSession = sessions.where((s) => s.id == sessionId).firstOrNull;
    debugPrint('[SessionManager] startSession: id=$sessionId, shiftId=$shiftId, customer=${_activeSession?.customerName}');
  }

  /// 结束当前活跃的 session。
  Future<void> endSession() async {
    if (_activeSession == null) return;
    final sessionId = _activeSession!.id;
    await _sessionRepo.completeSession(sessionId);
    debugPrint('[SessionManager] endSession: id=$sessionId');
    _activeSession = null;
  }

  /// 从云端同步当前活跃 session 状态（App 重启后恢复）。
  Future<void> restoreActive() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) return;
    _activeSession = await _sessionRepo.getActiveSession(userId);
    debugPrint('[SessionManager] restoreActive: ${_activeSession?.id}');
  }

  Future<void> _clearActive() async {
    if (_activeSession != null) {
      await endSession();
    }
  }

  /// 当前 session 的 COS 目录名：客户名（无则 unknown）+ 日期时间。
  String get cosDirName {
    if (_activeSession == null) return 'no-session';
    final d = _activeSession!.createdAt ?? DateTime.now();
    final pad = (int v) => v < 10 ? '0$v' : '$v';
    return '${activeCustomerName}_${d.year}${pad(d.month)}${pad(d.day)}_${pad(d.hour)}${pad(d.minute)}';
  }

  /// 缩略图 COS 上传路径。
  String thumbBasePath() => 'thumb/$cosDirName/';
  String originalBasePath() => 'original/$cosDirName/';

  /// 完整的 COS object key。
  String thumbKey(String photoId) => '${thumbBasePath()}$photoId.jpg';
  String originalKey(String photoId) => '${originalBasePath()}$photoId.jpg';
}

/// 全局单例。
final sessionManager = SessionManager();
