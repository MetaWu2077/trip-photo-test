import 'package:flutter/material.dart';

import '../../cos/cos_shared.dart';
import 'models/order_session.dart';
import 'models/upload_task.dart';
import 'repositories/task_queue_repository.dart';

/// 订单详情页：查看已完成订单的详细信息与图片预览。
class OrderDetailPage extends StatefulWidget {
  final OrderSession order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  List<UploadTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final tasks = taskQueueRepository.getAll()
        .where((t) => t.sessionId == widget.order.id)
        .toList();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  List<_PhotoPreviewItem> get _previewItems {
    return _tasks
        .where((t) => t.status == UploadStatus.success && t.thumbKey != null)
        .map(
          (t) => _PhotoPreviewItem(
            fileName: _fileNameFromPath(t.filePath),
            thumbKey: t.thumbKey!,
          ),
        )
        .toList();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  void _openGallery(List<_PhotoPreviewItem> items, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoGalleryViewerPage(
          items: items,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = widget.order;
    final previewItems = _previewItems;
    final hiddenCount = _tasks.length - previewItems.length;

    String formatDateTime(DateTime? dt) {
      if (dt == null) return '—';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order.customerName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 订单基本信息卡片
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: '客户姓名', value: order.customerName),
                          const Divider(height: 16),
                          _InfoRow(label: '拍摄地点', value: order.location),
                          const Divider(height: 16),
                          _InfoRow(label: '手机尾号', value: order.phoneLast4),
                          const Divider(height: 16),
                          _InfoRow(label: '订单状态', value: order.statusLabel),
                          const Divider(height: 16),
                          _InfoRow(label: '创建时间', value: formatDateTime(order.createdAt)),
                          if (order.startedAt != null) ...[
                            const Divider(height: 16),
                            _InfoRow(label: '开始时间', value: formatDateTime(order.startedAt)),
                          ],
                          if (order.endedAt != null) ...[
                            const Divider(height: 16),
                            _InfoRow(label: '结束时间', value: formatDateTime(order.endedAt)),
                          ],
                          if (order.startedAt != null && order.endedAt != null) ...[
                            const Divider(height: 16),
                            _InfoRow(
                              label: '拍摄时长',
                              value: _formatDuration(order.endedAt!.difference(order.startedAt!)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 图片预览列表
                  Text(
                    '上传图片（${previewItems.length} 张）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_tasks.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.image_not_supported_rounded,
                                  size: 48, color: scheme.outline),
                              const SizedBox(height: 8),
                              Text('暂无上传记录', style: TextStyle(color: scheme.outline)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (previewItems.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '当前没有可预览的成功图片',
                            style: TextStyle(color: scheme.outline),
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: previewItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = previewItems[index];
                        return _PhotoThumbnailTile(
                          item: item,
                          onTap: () => _openGallery(previewItems, index),
                        );
                      },
                    ),
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '其余 $hiddenCount 张为未完成或失败任务，已隐藏',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h小时$m分钟';
    if (m > 0) return '$m分钟$s秒';
    return '$s秒';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _PhotoPreviewItem {
  final String fileName;
  final String thumbKey;

  const _PhotoPreviewItem({
    required this.fileName,
    required this.thumbKey,
  });

  String signedUrl() => cosClient.getSignedDownloadUrl(thumbKey);
}

class _PhotoThumbnailTile extends StatelessWidget {
  final _PhotoPreviewItem item;
  final VoidCallback onTap;

  const _PhotoThumbnailTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = item.signedUrl();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_rounded, color: scheme.error),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black45,
                child: Text(
                  item.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGalleryViewerPage extends StatefulWidget {
  final List<_PhotoPreviewItem> items;
  final int initialIndex;

  const _PhotoGalleryViewerPage({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_PhotoGalleryViewerPage> createState() => _PhotoGalleryViewerPageState();
}

class _PhotoGalleryViewerPageState extends State<_PhotoGalleryViewerPage> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.items.length}'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    item.signedUrl(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 44,
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                current.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 280,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Icon(Icons.chevron_left_rounded, color: Colors.white38, size: 30),
                      Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}