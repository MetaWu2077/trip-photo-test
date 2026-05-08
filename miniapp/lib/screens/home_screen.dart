import 'package:flutter/material.dart';
import '../api_client.dart';
import '../auth_state.dart';

/// 顾客端首页：查看订单和照片。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _sessions = [];
  Map<int, List<dynamic>> _photosBySession = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = customerAuth.currentUser;
    if (user == null) return;

    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiClient();
      // 获取该用户作为客户的会话（通过 customer_id 关联，但当前 API 按 user_id 查询）
      // 顾客端查询：使用 customerId = userId 的 sessions
      // 暂时显示所有 sessions，后续按 customer_id 过滤
      final data = await api.get('/sessions', queryParams: {'userId': user.userId.toString()});
      final sessions = data as List<dynamic>? ?? [];

      // 加载每个 session 的照片
      final photosMap = <int, List<dynamic>>{};
      for (final s in sessions) {
        final sessionId = s['id'] as int;
        try {
          final photosData = await api.get('/photos', queryParams: {'sessionId': sessionId.toString()});
          photosMap[sessionId] = photosData as List<dynamic>? ?? [];
        } catch (_) {
          photosMap[sessionId] = [];
        }
      }

      setState(() {
        _sessions = sessions;
        _photosBySession = photosMap;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return '进行中';
      case 'completed': return '已完成';
      default: return '待开始';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = customerAuth.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.nickName ?? user?.phone ?? '我的订单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await customerAuth.logout();
              if (!mounted) return;
              setState(() {});
            },
            tooltip: '退出登录',
          ),
        ],
      ),
      body: _loading
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
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 64, color: scheme.outline),
                          const SizedBox(height: 16),
                          Text('暂无订单', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.outline)),
                          const SizedBox(height: 8),
                          Text('联系摄影师创建订单', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final sessionId = session['id'] as int;
                          final photos = _photosBySession[sessionId] ?? [];
                          final status = session['status'] as String? ?? 'pending';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 订单头
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              session['customer_name'] as String? ?? '订单 #$sessionId',
                                              style: Theme.of(context).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              session['created_at'] as String? ?? '',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 照片预览
                                if (photos.isNotEmpty) ...[
                                  SizedBox(
                                    height: 100,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: photos.length,
                                      itemBuilder: (context, i) {
                                        final thumbKey = photos[i]['thumb_key'] as String? ?? '';
                                        // TODO: 使用 COS 域名拼接缩略图 URL
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Icon(Icons.image_rounded, color: Colors.grey[400]),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                // 照片数
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Text(
                                    '${photos.length} 张照片',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
