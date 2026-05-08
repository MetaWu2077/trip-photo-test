import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cloudbase/cloudbase_client.dart';
import '../../cloudbase/repositories/cloud_shift_repository.dart';

/// 上工/收工页面。
class WorkShiftPage extends StatefulWidget {
  const WorkShiftPage({super.key});

  @override
  State<WorkShiftPage> createState() => _WorkShiftPageState();
}

class _WorkShiftPageState extends State<WorkShiftPage> {
  static const String _keyShiftId = 'active_shift_id';

  final _repo = CloudShiftRepository();
  CloudShift? _activeShift;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    // 先尝试从本地缓存恢复
    final prefs = await SharedPreferences.getInstance();
    final cachedShiftId = prefs.getInt(_keyShiftId);
    if (cachedShiftId != null) {
      // 验证服务器端状态
      final active = await _repo.getActiveShift(userId);
      if (active != null && active.id == cachedShiftId) {
        setState(() { _activeShift = active; _loading = false; });
        return;
      } else {
        // 已收工或 id 不匹配，清缓存
        await prefs.remove(_keyShiftId);
      }
    }
    // 检查服务器端是否还有未收工班次
    final active = await _repo.getActiveShift(userId);
    setState(() {
      _activeShift = active;
      _loading = false;
    });
  }

  Future<void> _clockIn() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final shift = await _repo.clockIn(userId);
    if (shift == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上工失败，请重试'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyShiftId, shift.id);
    setState(() => _activeShift = shift);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('上工成功，开始接单！'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _clockOut() async {
    if (_activeShift == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认收工'),
        content: Text('确定结束今日工作？今日已上传 ${_activeShift!.photoCount} 张照片。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('收工')),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = await _repo.clockOut(_activeShift!.id);
    if (!mounted) return;
    if (updated != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyShiftId);
      setState(() => _activeShift = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收工成功，辛苦了！'), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收工失败，请重试'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _shiftDuration(CloudShift shift) {
    final start = shift.startedAt;
    final end = shift.endedAt ?? DateTime.now();
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('上工/收工'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _init,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  // 主按钮区
                  if (_activeShift != null) ...[
                    // 进行中状态
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.timer_rounded, size: 48, color: Colors.green[600]),
                          const SizedBox(height: 12),
                          Text(
                            '工作中',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '已工作 ${_shiftDuration(_activeShift!)}',
                            style: TextStyle(color: Colors.green[600]),
                          ),
                          if (_activeShift!.photoCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '今日已上传 ${_activeShift!.photoCount} 张照片',
                              style: TextStyle(color: Colors.green[600], fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _clockOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('收    工', style: TextStyle(fontSize: 18)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ] else ...[
                    // 空闲状态
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.wb_sunny_outlined, size: 48, color: scheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            '今日未上工',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateTime.now().toIso8601String().substring(0, 10),
                            style: TextStyle(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _clockIn,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('上    工', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // 今日历史（下方小列表）
                  _buildTodayHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayHistory() {
    return FutureBuilder<List<CloudShift>>(
      future: _loadTodayShifts(),
      builder: (context, snapshot) {
        final shifts = snapshot.data ?? [];
        if (shifts.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日班次', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              ...shifts.map((s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.isActive ? Icons.circle : Icons.check_circle,
                  size: 16,
                  color: s.isActive ? Colors.green : Colors.grey,
                ),
                title: Text('${_formatTime(s.startedAt)} - ${s.endedAt != null ? _formatTime(s.endedAt!) : '进行中'}'),
                trailing: Text('${s.photoCount} 张', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<List<CloudShift>> _loadTodayShifts() async {
    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null) return [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _repo.getShifts(userId, date: today);
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
