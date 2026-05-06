import 'package:flutter/foundation.dart';

/// 任务队列刷新通知器（供 TaskQueuePage 监听）。
/// [retryUploadTask] 在开始时和结束时各调用一次 [notifyTaskQueueRefresh]。
class TaskQueueChangeNotifier extends ChangeNotifier {
  int _epoch = 0;

  int get epoch => _epoch;

  /// 通知所有监听者刷新任务列表。
  void refresh() {
    _epoch++;
    notifyListeners();
  }
}

/// 全局通知器单例。
final taskQueueChangeNotifier = TaskQueueChangeNotifier();

/// 供外部调用以触发队列刷新。
void notifyTaskQueueRefresh() {
  taskQueueChangeNotifier.refresh();
}
