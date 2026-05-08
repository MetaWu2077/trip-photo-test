import 'package:flutter/material.dart';
import '../../cloudbase/cloudbase_client.dart';
import '../../cloudbase/models/cloud_stats.dart';
import '../../cloudbase/repositories/cloud_stats_repository.dart';

/// 每日统计仪表盘页面。
class DailyStatsPage extends StatefulWidget {
  const DailyStatsPage({super.key});

  @override
  State<DailyStatsPage> createState() => _DailyStatsPageState();
}

class _DailyStatsPageState extends State<DailyStatsPage> {
  final _repo = CloudStatsRepository();
  DailyStats? _stats;
  bool _loading = true;
  String? _error;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) {
      setState(() { _loading = false; _error = '请先登录'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await _repo.getDailyStats(userId, date: _selectedDate);
      setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _selectedDate = picked.toIso8601String().substring(0, 10);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日统计'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDate,
            tooltip: '选择日期',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
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
              : _stats == null
                  ? const Center(child: Text('暂无数据'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 日期选择提示
                          Center(
                            child: TextButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today_rounded, size: 18),
                              label: Text(_selectedDate),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 主统计卡片
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.wb_sunny_rounded, color: scheme.primary),
                                      const SizedBox(width: 8),
                                      Text('当日概况', style: Theme.of(context).textTheme.titleMedium),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(child: _StatBox(label: '上班次数', value: '${_stats!.shiftCount}', color: Colors.blue)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _StatBox(label: '进行中', value: '${_stats!.activeShiftCount}', color: Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _StatBox(label: '上传照片', value: '${_stats!.totalPhotos}', color: Colors.orange)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _StatBox(label: '订单数', value: '${_stats!.sessionCount}', color: Colors.purple)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _StatBox(label: '服务客户数', value: '${_stats!.customerCount}', color: Colors.teal),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 说明
                          Text(
                            '统计说明',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Card(
                            color: scheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ExplainRow(label: '上班次数', text: '已完成收工的班次数量'),
                                  const SizedBox(height: 4),
                                  _ExplainRow(label: '进行中', text: '当前上工但尚未收工的班次'),
                                  const SizedBox(height: 4),
                                  _ExplainRow(label: '上传照片', text: '当日所有班次累计上传照片总数'),
                                  const SizedBox(height: 4),
                                  _ExplainRow(label: '订单数', text: '当日创建的拍摄会话数量'),
                                  const SizedBox(height: 4),
                                  _ExplainRow(label: '服务客户', text: '当日有客户关联的订单去重数'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _ExplainRow extends StatelessWidget {
  final String label;
  final String text;

  const _ExplainRow({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
