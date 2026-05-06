import 'package:flutter/material.dart';
import 'models/upload_task.dart';
import 'repositories/task_queue_repository.dart';
import 'task_queue_notifier.dart';
import 'upload_retry.dart';

/// 任务队列 Tab：显示所有任务状态，支持一键重试失败任务。
class TaskQueuePage extends StatefulWidget {
  const TaskQueuePage({super.key});

  @override
  State<TaskQueuePage> createState() => _TaskQueuePageState();
}

class _TaskQueuePageState extends State<TaskQueuePage> with WidgetsBindingObserver {
  List<UploadTask> _tasks = [];
  bool _isRetrying = false;
  final Set<String> _retryingTaskIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    taskQueueChangeNotifier.addListener(_onTaskQueueChange);
    _loadTasks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    taskQueueChangeNotifier.removeListener(_onTaskQueueChange);
    super.dispose();
  }

  void _onTaskQueueChange() {
    if (mounted) {
      _loadTasks();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // APP 从后台回来时自动刷新队列。
    if (state == AppLifecycleState.resumed) {
      _loadTasks();
    }
  }

  void _loadTasks() {
    setState(() {
      _tasks = taskQueueRepository.getAll();
    });
  }

  Future<void> _retryTask(String taskId) async {
    setState(() => _retryingTaskIds.add(taskId));
    await retryUploadTask(taskId);
    setState(() => _retryingTaskIds.remove(taskId));
  }

  Future<void> _retryFailed() async {
    final failed = taskQueueRepository.getFailed();
    if (failed.isEmpty) return;

    setState(() => _isRetrying = true);
    // TODO(阶段 B)：实现批量重试逻辑（当前仅清空失败任务标记）
    // 阶段 B 前这里先不做实际重试，仅提供"清空"功能用于演示
    for (final task in failed) {
      task.status = UploadStatus.pending;
      task.retryCount = 0;
      task.errorMessage = null;
      await taskQueueRepository.update(task);
    }
    _loadTasks();
    setState(() => _isRetrying = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${failed.length} 个失败任务重置为等待状态'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _clearSucceeded() async {
    await taskQueueRepository.clearSucceeded();
    _loadTasks();
  }

  String _statusIcon(UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
        return '⏳';
      case UploadStatus.uploading:
        return '⬆️';
      case UploadStatus.success:
        return '✅';
      case UploadStatus.failed:
        return '❌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failedCount = _tasks.where((t) => t.status == UploadStatus.failed).length;
    final successCount = _tasks.where((t) => t.status == UploadStatus.success).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 统计栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatChip(label: '总计', value: '${_tasks.length}', color: scheme.primary),
                  const SizedBox(width: 8),
                  _StatChip(label: '成功', value: '$successCount', color: Colors.green),
                  const SizedBox(width: 8),
                  _StatChip(label: '失败', value: '$failedCount', color: scheme.error),
                ],
              ),
            ),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: failedCount == 0 || _isRetrying ? null : _retryFailed,
                      icon: _isRetrying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                      label: Text(failedCount == 0 ? '无失败任务' : '重试失败 ($failedCount)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: successCount == 0 ? null : _clearSucceeded,
                    child: Text(successCount == 0 ? '无成功记录' : '清空成功'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // 任务列表
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: scheme.outline),
                          const SizedBox(height: 8),
                          Text('暂无上传任务', style: TextStyle(color: scheme.outline)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return ListTile(
                          leading: Text(_statusIcon(task.status), style: const TextStyle(fontSize: 20)),
                          title: Text(
                            task.filePath.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${task.statusLabel} · 重试 ${task.retryCount} 次',
                                style: TextStyle(
                                  color: task.status == UploadStatus.failed
                                      ? scheme.error
                                      : null,
                                ),
                              ),
                              if (task.errorMessage != null)
                                Text(
                                  task.errorMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: scheme.error),
                                ),
                            ],
                          ),
                          trailing: task.status == UploadStatus.failed
                              ? (_retryingTaskIds.contains(task.id)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.refresh_rounded),
                                      tooltip: '重新上传',
                                      onPressed: () => _retryTask(task.id),
                                    ))
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
