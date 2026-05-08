import 'package:flutter/material.dart';
import '../../cloudbase/models/cloud_session.dart';
import '../../cloudbase/repositories/cloud_photo_repository.dart';
import '../../cos/cos_shared.dart';

/// 订单详情页：展示已完成云端订单的照片（从 MySQL photos 表加载）。
class CloudSessionDetailPage extends StatefulWidget {
  final CloudSession session;

  const CloudSessionDetailPage({super.key, required this.session});

  @override
  State<CloudSessionDetailPage> createState() => _CloudSessionDetailPageState();
}

class _CloudSessionDetailPageState extends State<CloudSessionDetailPage> {
  final _photoRepo = CloudPhotoRepository();
  List<dynamic> _photos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final photos = await _photoRepo.getPhotosBySession(widget.session.id);
      if (mounted) setState(() { _photos = photos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String get _publicBaseUrl => publicCosBaseUrl();

  String _thumbUrl(String thumbKey) {
    return cosObjectPublicUrl(_publicBaseUrl, thumbKey);
  }

  String _formatDateTime(String? dtStr) {
    if (dtStr == null) return '—';
    try {
      final dt = DateTime.parse(dtStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dtStr;
    }
  }

  String _statusLabel(CloudSessionStatus status) {
    switch (status) {
      case CloudSessionStatus.pending: return '待开始';
      case CloudSessionStatus.active: return '进行中';
      case CloudSessionStatus.completed: return '已完成';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.customerName ?? '订单 #${session.id}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
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
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 基本信息卡片
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: '客户姓名', value: session.customerName ?? '—'),
                              const Divider(height: 16),
                              _InfoRow(label: '订单状态', value: _statusLabel(session.status)),
                              const Divider(height: 16),
                              _InfoRow(label: '创建时间', value: _formatDateTime(session.createdAt?.toIso8601String())),
                              if (session.startedAt != null) ...[
                                const Divider(height: 16),
                                _InfoRow(label: '开始时间', value: _formatDateTime(session.startedAt!.toIso8601String())),
                              ],
                              if (session.endedAt != null) ...[
                                const Divider(height: 16),
                                _InfoRow(label: '结束时间', value: _formatDateTime(session.endedAt!.toIso8601String())),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 照片列表
                      Text(
                        '上传图片（${_photos.length} 张）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_photos.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.image_not_supported_rounded, size: 48, color: scheme.outline),
                                  const SizedBox(height: 8),
                                  Text('暂无上传记录', style: TextStyle(color: scheme.outline)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _photos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            final thumbKey = photo['thumb_key'] as String? ?? '';
                            final url = _thumbUrl(thumbKey);
                            return _PhotoThumbnail(
                              url: url,
                              onTap: () => _openGallery(index),
                            );
                          },
                        ),
                    ],
                  ),
      ),
    );
  }

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoGalleryPage(
          photos: _photos,
          initialIndex: initialIndex,
          publicBaseUrl: _publicBaseUrl,
        ),
      ),
    );
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
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String url;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.broken_image_rounded, color: scheme.error),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }
}

class _PhotoGalleryPage extends StatefulWidget {
  final List<dynamic> photos;
  final int initialIndex;
  final String publicBaseUrl;

  const _PhotoGalleryPage({
    required this.photos,
    required this.initialIndex,
    required this.publicBaseUrl,
  });

  @override
  State<_PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<_PhotoGalleryPage> {
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

  String _thumbUrl(String thumbKey) {
    return cosObjectPublicUrl(widget.publicBaseUrl, thumbKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final thumbKey = photo['thumb_key'] as String? ?? '';
          final url = _thumbUrl(thumbKey);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 44),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
