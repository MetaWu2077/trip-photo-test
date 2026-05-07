import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../cos/cos_shared.dart';
import '../../image/pipeline.dart';
import 'models/upload_task.dart';
import 'repositories/task_queue_repository.dart';
import 'session_manager.dart';
import 'task_queue_notifier.dart';

class UploadTestPage extends StatefulWidget {
  const UploadTestPage({super.key});

  @override
  State<UploadTestPage> createState() => _UploadTestPageState();
}

class _UploadTestPageState extends State<UploadTestPage> {
  final ImagePicker _picker = ImagePicker();

  /// 上传策略：true = 缩略图+原图，false = 仅缩略图（默认）。
  bool _uploadOriginal = false;
  String? _thumbnailUrl;
  String? _originalUrl;
  Uint8List? _previewJpeg;
  bool _isUploading = false;
  String _status = '选一张图，点按钮上传到 COS';
  String? _readCheck;

  /// 浏览用 URL：优先 COS_DOMAIN，否则按 Bucket+Region 拼腾讯云默认域名。
  String get _publicBaseUrl => publicCosBaseUrl();

  /// 不在 initState 里弹权限（模拟器上易与首帧抢占，表现为按钮点了没反应）。改在点上传时再申请。
  /// Windows/macOS/Linux 不走 permission_handler 的相册权限（易异常或无效），直接交给系统文件选择器。
  /// Android：image_picker 走系统 Photo Picker，不必先调 [Permission.photos.request]；在部分模拟器上
  /// 该请求会长时间挂起或挡住触摸层，表现为按钮与系统导航键都无响应。
  Future<bool> _ensureMediaPermission() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    if (Platform.isAndroid) return true;

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;
    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;
    if (photos.isPermanentlyDenied || storage.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  /// 缩略图体积小，用 GET 拉正文校验。
  Future<String> _checkHttpGetSmall(String label, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '「$label」URL 无效';
    }
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        return '「$label」GET ${r.statusCode} · ${r.bodyBytes.length} 字节（可读取）';
      }
      return '「$label」GET ${r.statusCode} · ${r.bodyBytes.length} 字节';
    } catch (e) {
      return '「$label」GET 失败（私有桶或未开公读时常见）: $e';
    }
  }

  /// 原图可能很大，只用 HEAD，避免整文件下载把模拟器拖死。
  Future<String> _checkHttpHead(String label, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return '「$label」URL 无效';
    }
    try {
      final r = await http.head(uri).timeout(const Duration(seconds: 20));
      final len = r.headers['content-length'] ?? '（无 Content-Length）';
      if (r.statusCode == 200) {
        return '「$label」HEAD ${r.statusCode} · Content-Length: $len（未下载正文）';
      }
      return '「$label」HEAD ${r.statusCode} · Content-Length: $len';
    } catch (e) {
      return '「$label」HEAD 失败（部分网关不支持 HEAD 或私有桶）: $e';
    }
  }

  Future<void> _runReadChecks() async {
    if (_thumbnailUrl == null) return;
    setState(() => _readCheck = '正在检测 HTTP…');
    final a = await _checkHttpGetSmall('缩略图', _thumbnailUrl!);
    String b = '';
    if (_originalUrl != null) {
      b = '\n${await _checkHttpHead('原图', _originalUrl!)}';
    }
    if (!mounted) return;
    setState(() => _readCheck = '$a$b');
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _isUploading = true;
      _status = Platform.isIOS ? '检查相册权限…' : '打开相册…';
      _readCheck = null;
      _thumbnailUrl = null;
      _originalUrl = null;
      _previewJpeg = null;
    });

    // task 声明在 try 外面，供 catch 块访问。
    UploadTask? task;

    try {
      if (cosEnv('COS_SECRET_ID').isEmpty ||
          cosEnv('COS_SECRET_KEY').isEmpty ||
          cosEnv('COS_BUCKET').isEmpty ||
          cosEnv('COS_REGION').isEmpty) {
        if (!mounted) return;
        setState(() {
          _isUploading = false;
          _status = '失败: COS 未配置（SecretId、SecretKey、Bucket、Region 不能为空）。\n'
              '模拟器/真机不会读取磁盘上的 cos.local.env，需将其列入 pubspec.yaml 的 assets（已配置），'
              '并在修改该文件后执行一次完整重新运行（非仅热重载）。'
              '也可使用「trip_photo_test（本地调试）」或 flutter run --dart-define-from-file=cos.local.env。';
        });
        return;
      }

      final ok = await _ensureMediaPermission();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isUploading = false;
          _status = '需要相册/存储权限后才能选图，可在系统设置中开启';
        });
        return;
      }

      setState(() => _status = '打开相册…');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (image == null) {
        setState(() {
          _isUploading = false;
          _status = '已取消';
        });
        return;
      }

      // 创建队列任务（使用时间戳+随机数保证唯一性）。
      if (!sessionManager.hasActiveSession) {
        setState(() {
          _isUploading = false;
          _status = '失败: 当前没有进行中的订单。\n请先在"订单"标签页选择一个订单开始拍摄。';
        });
        return;
      }
      final taskId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final currentSessionId = sessionManager.activeSessionId;
      task = UploadTask(
        id: taskId,
        sessionId: currentSessionId,
        filePath: image.path,
        uploadOriginal: _uploadOriginal,
        status: UploadStatus.pending,
        createdAt: DateTime.now(),
      );
      await taskQueueRepository.add(task);

      setState(() => _status = '处理图片（后台，不卡界面）…');
      final originalBytes = await File(image.path).readAsBytes();
      final processed =
          await compute(processPickedImageForUpload, originalBytes);
      if (!mounted) return;

      // 更新状态为上传中。
      task.status = UploadStatus.uploading;
      await taskQueueRepository.update(task);

      setState(() {
        _previewJpeg = processed.preview;
        _status = '图片已就绪，开始上传…';
      });

      final thumbnailBytes = processed.thumb;

      setState(() => _status = '上传缩略图到 COS…');
      final thumbKey = sessionManager.thumbKey(taskId);
      await cosClient.putObjectWithFileDataOrThrow(thumbKey, thumbnailBytes);

      final thumbUrl = cosObjectPublicUrl(_publicBaseUrl, thumbKey);

      String? originalUrl;
      String? originalKey;
      if (_uploadOriginal) {
        originalKey = sessionManager.originalKey(taskId);
        setState(() => _status = '上传原图到 COS…');
        await cosClient.putObjectOrThrow(originalKey, image.path);
        originalUrl = cosObjectPublicUrl(_publicBaseUrl, originalKey);
      }

      // 上传成功，更新队列任务。
      task.thumbKey = thumbKey;
      task.originalKey = originalKey;
      task.status = UploadStatus.success;
      await taskQueueRepository.update(task);
      notifyTaskQueueRefresh();

      setState(() {
        _thumbnailUrl = thumbUrl;
        _originalUrl = originalUrl;
        _isUploading = false;
        _status = '上传完成';
      });
      unawaited(_runReadChecks());
    } catch (e, st) {
      debugPrint('[trip_photo_test] COS 失败: $e');
      debugPrint('$st');

      // 上传失败，更新队列任务。
      task?.status = UploadStatus.failed;
      task?.errorMessage = e.toString();
      task?.retryCount++;
      await taskQueueRepository.update(task!);
      notifyTaskQueueRefresh();

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _status = cosUserFacingError(e);
        _readCheck = null;
      });
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget linkRow(String title, String url) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => _copy(url),
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: '复制链接',
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(url, style: TextStyle(fontSize: 12, color: scheme.primary)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('COS 存取测试'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('状态', style: Theme.of(context).textTheme.labelLarge),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: () => _copy(_status),
                            icon: const Icon(Icons.content_copy_rounded, size: 20),
                            tooltip: '复制整段状态/错误',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _status,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: _status.startsWith('失败')
                                  ? scheme.error
                                  : null,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_previewJpeg != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(
                      _previewJpeg!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _uploadOriginal ? Icons.cloud_upload_rounded : Icons.image_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '上传策略',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              _uploadOriginal ? '缩略图 + 原图' : '仅缩略图',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _uploadOriginal,
                        onChanged: (v) => setState(() => _uploadOriginal = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isUploading ? '处理中…' : '选图并上传到 COS'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
              if (_thumbnailUrl != null) ...[
                const SizedBox(height: 20),
                Text('链接', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        linkRow('缩略图', _thumbnailUrl!),
                        const Divider(height: 24),
                        if (_originalUrl != null) linkRow('原图', _originalUrl!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_readCheck != null)
                  Card(
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'HTTP 检测',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                onPressed: () => _copy(_readCheck!),
                                icon: const Icon(Icons.content_copy_rounded, size: 20),
                                tooltip: '复制检测结果',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _readCheck!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _thumbnailUrl == null ? null : _runReadChecks,
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: const Text('重新检测 HTTP 读取'),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '说明：上传成功后缩略图用 GET、原图用 HEAD（不下载整文件）做检测；私有桶可能仍失败，对象或已在 COS。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
