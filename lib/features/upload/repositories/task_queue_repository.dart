import 'package:hive_flutter/hive_flutter.dart';
import '../models/upload_task.dart';

/// 基于 Hive 的任务队列仓库。
/// 所有变更自动持久化到本地存储，APP 重启后数据仍在。
class TaskQueueRepository {
  static const String _boxName = 'upload_tasks';
  Box<UploadTask>? _box;

  /// 初始化（APP 启动时调用一次）。
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UploadStatusAdapter());
    Hive.registerAdapter(UploadTaskAdapter());
    _box = await Hive.openBox<UploadTask>(_boxName);
  }

  Box<UploadTask> get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('TaskQueueRepository 未初始化，请先调用 init()');
    }
    return _box!;
  }

  /// 添加一个任务。
  Future<void> add(UploadTask task) async {
    await _safeBox.put(task.id, task);
  }

  /// 更新任务。
  Future<void> update(UploadTask task) async {
    await task.save();
  }

  /// 删除任务。
  Future<void> delete(String id) async {
    await _safeBox.delete(id);
  }

  /// 获取所有任务（按创建时间倒序）。
  List<UploadTask> getAll() {
    final tasks = _safeBox.values.toList();
    tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
  }

  /// 只获取失败的任务（按创建时间倒序）。
  List<UploadTask> getFailed() {
    return getAll().where((t) => t.status == UploadStatus.failed).toList();
  }

  /// 任务总数。
  int get totalCount => _safeBox.length;

  /// 失败任务数。
  int get failedCount => _safeBox.values
      .where((t) => t.status == UploadStatus.failed)
      .length;

  /// 清空所有任务。
  Future<void> clearAll() async {
    await _safeBox.clear();
  }

  /// 清空成功任务（保留失败和等待中）。
  Future<void> clearSucceeded() async {
    final succeeded = _safeBox.values
        .where((t) => t.status == UploadStatus.success)
        .map((t) => t.id)
        .toList();
    for (final id in succeeded) {
      await _safeBox.delete(id);
    }
  }
}

/// 全局单例（APP 启动时初始化）。
final taskQueueRepository = TaskQueueRepository();
