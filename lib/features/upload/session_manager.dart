import 'package:flutter/foundation.dart';
import 'models/order_session.dart';
import 'repositories/order_session_repository.dart';

/// 当前活跃 Session 管理器（内存级，APP 级别单例）。
/// 管理"当前正在拍摄"的订单 session，关联所有上传任务路径。
class SessionManager {
  OrderSession? _activeSession;

  OrderSession? get activeSession => _activeSession;
  bool get hasActiveSession => _activeSession != null;
  String get activeSessionId => _activeSession?.id ?? '';

  /// 开始一个 session（选定的订单进入"进行中"状态）。
  Future<void> startSession(String orderId) async {
    // 先结束当前 session。
    if (_activeSession != null) {
      await endSession();
    }

    final session = orderSessionRepository.getById(orderId);
    if (session == null) {
      throw StateError('订单不存在: $orderId');
    }
    session.status = OrderStatus.active;
    session.startedAt = DateTime.now();
    await orderSessionRepository.update(session);
    _activeSession = session;
    debugPrint('[SessionManager] startSession: $orderId');
  }

  /// 结束当前 session。
  Future<void> endSession() async {
    if (_activeSession == null) return;
    final session = _activeSession!;
    session.status = OrderStatus.completed;
    session.endedAt = DateTime.now();
    await orderSessionRepository.update(session);
    debugPrint('[SessionManager] endSession: ${session.id}');
    _activeSession = null;
  }

  /// 获取当前 session 的 COS 上传根路径（不含文件名）。
  /// 格式：thumb/{sessionId}/ 或 original/{sessionId}/
  String thumbBasePath() => 'thumb/${_activeSession?.id ?? 'no-session'}/';
  String originalBasePath() => 'original/${_activeSession?.id ?? 'no-session'}/';

  /// 上传时拼接完整的 COS object key。
  /// [photoId] 使用任务 ID 简化处理。
  String thumbKey(String photoId) => '${thumbBasePath()}$photoId.jpg';
  String originalKey(String photoId) => '${originalBasePath()}$photoId.jpg';
}

/// 全局单例（APP 级别）。
final sessionManager = SessionManager();
