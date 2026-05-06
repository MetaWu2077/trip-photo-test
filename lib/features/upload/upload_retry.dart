import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../cos/cos_shared.dart';
import '../../image/pipeline.dart';
import 'models/upload_task.dart';
import 'repositories/task_queue_repository.dart';
import 'task_queue_notifier.dart';

/// 模块级上传锁，防止多个任务同时上传。
bool _isUploadingShared = false;

/// 根据 taskId 重试队列中的失败任务（使用本地原图路径重新上传）。
/// 由 TaskQueuePage 的刷新按钮调用。
Future<void> retryUploadTask(String taskId) async {
  if (_isUploadingShared) return;
  _isUploadingShared = true;

  try {
    final tasks = taskQueueRepository.getFailed();
    final task = tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('任务不存在或不是失败状态'),
    );

    final f = File(task.filePath);
    if (!f.existsSync()) {
      task.status = UploadStatus.failed;
      task.errorMessage = '文件已不存在：${task.filePath}';
      await taskQueueRepository.update(task);
      notifyTaskQueueRefresh();
      return;
    }

    task.status = UploadStatus.uploading;
    await taskQueueRepository.update(task);
    notifyTaskQueueRefresh();

    final originalBytes = await f.readAsBytes();
    final processed = await compute(processPickedImageForUpload, originalBytes);
    final thumbnailBytes = processed.thumb;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final thumbKey = 'test/thumb_$ts.jpg';
    await cosClient.putObjectWithFileDataOrThrow(thumbKey, thumbnailBytes);

    String? originalKey;
    if (task.uploadOriginal) {
      originalKey = 'test/original_$ts.jpg';
      await cosClient.putObjectOrThrow(originalKey, task.filePath);
    }

    task.thumbKey = thumbKey;
    task.originalKey = originalKey;
    task.status = UploadStatus.success;
    task.errorMessage = null;
    await taskQueueRepository.update(task);
  } catch (e, st) {
    debugPrint('[retryUploadTask] 失败: $e');
    debugPrint('$st');
    final tasks = taskQueueRepository.getAll();
    final task = tasks.firstWhere((t) => t.id == taskId, orElse: () => throw StateError('任务不存在'));
    task.status = UploadStatus.failed;
    task.errorMessage = e.toString();
    task.retryCount++;
    await taskQueueRepository.update(task);
  } finally {
    _isUploadingShared = false;
    notifyTaskQueueRefresh();
  }
}
