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

  /// 当前 session 的 COS 目录名：手机后四位 + 订单日期时间。
  /// 格式：{phoneLast4}_{yyyyMMdd_HHmm}
  String get cosDirName {
    if (_activeSession == null) return 'no-session';
    final s = _activeSession!;
    final d = s.createdAt;
    final padM = d.month < 10 ? '0${d.month}' : '${d.month}';
    final padD = d.day < 10 ? '0${d.day}' : '${d.day}';
    final padH = d.hour < 10 ? '0${d.hour}' : '${d.hour}';
    final padMin = d.minute < 10 ? '0${d.minute}' : '${d.minute}';
    return '${s.phoneLast4}_${d.year}$padM${padD}_$padH$padMin';
  }

  /// 获取当前 session 的 COS 上传根路径（不含文件名）。
  /// 格式：thumb/{cosDirName}/ 或 original/{cosDirName}/
  String thumbBasePath() => 'thumb/$cosDirName/';
  String originalBasePath() => 'original/$cosDirName/';

  /// 上传时拼接完整的 COS object key。
  /// [photoId] 使用任务 ID 简化处理。
  String thumbKey(String photoId) => '${thumbBasePath()}$photoId.jpg';
  String originalKey(String photoId) => '${originalBasePath()}$photoId.jpg';
}

/// 全局单例（APP 级别）。
final sessionManager = SessionManager();
