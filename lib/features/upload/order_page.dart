import 'package:flutter/material.dart';
import 'models/order_session.dart';
import 'repositories/order_session_repository.dart';
import 'session_manager.dart';
import 'task_queue_notifier.dart';

/// 订单 Tab：模拟的预约订单列表，点击后开始对应拍摄 session。
class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  List<OrderSession> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() => _orders = orderSessionRepository.getAll());
  }

  Future<void> _startOrder(OrderSession order) async {
    try {
      await sessionManager.startSession(order.id);
      _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('开始拍摄：${order.customerName}（${order.location}）'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      taskQueueChangeNotifier.refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _endOrder() async {
    await sessionManager.endSession();
    _loadOrders();
    taskQueueChangeNotifier.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('当前订单已结束'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return '📋';
      case OrderStatus.active:
        return '📷';
      case OrderStatus.completed:
        return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeOrder = sessionManager.activeSession;
    final pendingCount = _orders.where((o) => o.status == OrderStatus.pending).length;
    final activeCount = _orders.where((o) => o.status == OrderStatus.active).length;
    final completedCount = _orders.where((o) => o.status == OrderStatus.completed).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 当前进行中的 session 提示栏
            if (activeOrder != null)
              Container(
                width: double.infinity,
                color: scheme.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '进行中：${activeOrder.customerName}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                          ),
                          Text(
                            activeOrder.location,
                            style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _endOrder,
                      style: OutlinedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('结束拍摄'),
                    ),
                  ],
                ),
              ),
            // 统计栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatChip(label: '待处理', value: '$pendingCount', color: scheme.outline),
                  const SizedBox(width: 8),
                  _StatChip(label: '进行中', value: '$activeCount', color: scheme.primary),
                  const SizedBox(width: 8),
                  _StatChip(label: '已完成', value: '$completedCount', color: Colors.green),
                ],
              ),
            ),
            const Divider(height: 1),
            // 订单列表
            Expanded(
              child: _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt_rounded, size: 48, color: scheme.outline),
                          const SizedBox(height: 8),
                          Text('暂无预约订单', style: TextStyle(color: scheme.outline)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return ListTile(
                          leading: Text(_statusIcon(order.status), style: const TextStyle(fontSize: 20)),
                          title: Text(order.customerName),
                          subtitle: Text(
                            '${order.location} · ${order.statusLabel}',
                            style: TextStyle(
                              color: order.status == OrderStatus.active ? scheme.primary : null,
                            ),
                          ),
                          trailing: order.status == OrderStatus.pending
                              ? FilledButton.tonal(
                                  onPressed: () => _startOrder(order),
                                  child: const Text('开始拍摄'),
                                )
                              : order.status == OrderStatus.active
                                  ? const Icon(Icons.camera_alt_rounded, color: Colors.green)
                                  : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
