import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_session.dart';

/// 订单会话仓库（基于 Hive）。
class OrderSessionRepository {
  static const String _boxName = 'order_sessions';
  Box<OrderSession>? _box;
  Future<void>? _initFuture;

  Future<void> init() {
    if (_box != null && _box!.isOpen) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(OrderStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(OrderSessionAdapter());
    }
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<OrderSession>(_boxName);
      return;
    }
    _box = await Hive.openBox<OrderSession>(_boxName);
  }

  Box<OrderSession> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('OrderSessionRepository 未初始化');
    }
    return _box!;
  }

  Future<void> add(OrderSession session) async {
    await _safeBox.put(session.id, session);
  }

  Future<void> update(OrderSession session) async {
    await session.save();
  }

  /// 获取所有订单（按创建时间倒序）。
  List<OrderSession> getAll() {
    final sessions = _safeBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  /// 获取进行中的订单。
  OrderSession? getActive() {
    final sessions = getAll();
    for (final s in sessions) {
      if (s.status == OrderStatus.active) return s;
    }
    return null;
  }

  /// 获取指定 ID 的订单。
  OrderSession? getById(String id) {
    return _safeBox.get(id);
  }

  /// 初始化模拟订单数据（仅在空仓库时自动填充）。
  Future<void> ensureMockOrders() async {
    if (_safeBox.isNotEmpty) return;
    final mocks = [
      OrderSession(
        id: 'order_001',
        customerName: '李女士',
        location: '厦门鼓浪屿',
        phoneLast4: '1234',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      OrderSession(
        id: 'order_002',
        customerName: '张先生',
        location: '厦门中山路',
        phoneLast4: '5678',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      OrderSession(
        id: 'order_003',
        customerName: '王小姐',
        location: '厦门曾厝垵',
        phoneLast4: '9012',
        createdAt: DateTime.now(),
      ),
    ];
    for (final s in mocks) {
      await add(s);
    }
  }

  Future<void> clearAll() async {
    await _safeBox.clear();
  }
}

/// 全局单例。
final orderSessionRepository = OrderSessionRepository();
