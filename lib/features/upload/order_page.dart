import 'package:flutter/material.dart';
import '../../cloudbase/cloudbase_client.dart';
import '../../cloudbase/models/cloud_session.dart';
import '../../cloudbase/repositories/cloud_session_repository.dart';
import '../customer/customer_selector_dialog.dart';
import 'session_manager.dart';
import 'task_queue_notifier.dart';

/// 订单 Tab：云端会话列表，点击后开始/结束对应拍摄 session。
class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _sessionRepo = CloudSessionRepository();

  List<CloudSession> _sessions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null || userId <= 0) return;
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _sessionRepo.getSessions(userId);
      setState(() { _sessions = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _createAndStartSession() async {
    // 先选客户
    final customer = await showCustomerSelectorDialog(context);
    if (!mounted) return;

    try {
      // 创建并激活 session，沿用当前 shift 的 shiftId
      await sessionManager.startSession(
        customerId: customer?.id,
        shiftId: sessionManager.activeSession?.shiftId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建订单失败: $e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始拍摄：${customer?.name ?? '新订单'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    taskQueueChangeNotifier.refresh();
  }

  Future<void> _startSession(CloudSession session) async {
    try {
      await sessionManager.setActiveSession(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动失败: $e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始拍摄：${session.customerName ?? '订单${session.id}'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    taskQueueChangeNotifier.refresh();
  }

  Future<void> _endSession(CloudSession session) async {
    // 如果结束的是当前活跃 session，先让 SessionManager 也结束它
    if (sessionManager.activeSession?.id == session.id) {
      await sessionManager.endSession();
    }
    final ok = await _sessionRepo.completeSession(session.id);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束失败'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前订单已结束'), behavior: SnackBarBehavior.floating),
    );
    taskQueueChangeNotifier.refresh();
  }

  String _statusIcon(CloudSessionStatus status) {
    switch (status) {
      case CloudSessionStatus.pending:
        return '📋';
      case CloudSessionStatus.active:
        return '📷';
      case CloudSessionStatus.completed:
        return '✅';
    }
  }

  String _statusLabel(CloudSessionStatus status) {
    switch (status) {
      case CloudSessionStatus.pending:
        return '待开始';
      case CloudSessionStatus.active:
        return '进行中';
      case CloudSessionStatus.completed:
        return '已完成';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeSessions = _sessions.where((s) => s.status == CloudSessionStatus.active).toList();
    final pendingCount = _sessions.where((s) => s.status == CloudSessionStatus.pending).length;
    final activeCount = activeSessions.length;
    final completedCount = _sessions.where((s) => s.status == CloudSessionStatus.completed).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 当前进行中的 session 提示栏
            if (activeSessions.isNotEmpty)
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
                            '进行中：${activeSessions.first.customerName ?? '订单${activeSessions.first.id}'}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                          ),
                          if (activeSessions.length > 1)
                            Text(
                              '还有 ${activeSessions.length - 1} 个进行中',
                              style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _endSession(activeSessions.first),
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
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _createAndStartSession,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建订单'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 订单列表
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton(onPressed: _load, child: const Text('重试')),
                            ],
                          ),
                        )
                      : _sessions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.list_alt_rounded, size: 48, color: scheme.outline),
                                  const SizedBox(height: 8),
                                  Text('暂无订单', style: TextStyle(color: scheme.outline)),
                                  const SizedBox(height: 4),
                                  Text('点击右上角新建', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                itemCount: _sessions.length,
                                itemBuilder: (context, index) {
                                  final session = _sessions[index];
                                  return ListTile(
                                    leading: Text(_statusIcon(session.status), style: const TextStyle(fontSize: 20)),
                                    title: Text(session.customerName ?? '订单 #${session.id}'),
                                    subtitle: Text(
                                      [
                                        if (session.cosDirPrefix != null && session.cosDirPrefix!.isNotEmpty) session.cosDirPrefix!,
                                        _statusLabel(session.status),
                                      ].join(' · '),
                                      style: TextStyle(
                                        color: session.status == CloudSessionStatus.active ? scheme.primary : null,
                                      ),
                                    ),
                                    trailing: session.status == CloudSessionStatus.pending
                                        ? FilledButton.tonal(
                                            onPressed: () => _startSession(session),
                                            child: const Text('开始拍摄'),
                                          )
                                        : session.status == CloudSessionStatus.active
                                            ? const Icon(Icons.camera_alt_rounded, color: Colors.green)
                                            : const Icon(Icons.chevron_right_rounded),
                                  );
                                },
                              ),
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
