import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'cos/cos_shared.dart';
import 'features/sony/sony_wifi_upload_page.dart';
import 'features/upload/upload_page.dart';
import 'features/upload/repositories/task_queue_repository.dart';
import 'features/upload/repositories/order_session_repository.dart';
import 'features/upload/order_page.dart';
import 'features/upload/task_queue_page.dart';
import 'features/work/work_shift_page.dart';
import 'features/stats/daily_stats_page.dart';
import 'cloudbase/auth/auth_state.dart';
import 'cloudbase/cloudbase_client.dart';
import 'cloudbase/repositories/cloud_user_repository.dart';
import 'cloudbase/screens/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
  bool isLoggedIn = false;
  try {
    await dotenv.load(fileName: 'cos.local.env', isOptional: true);
    tryLoadCosLocalEnvFromDisk();
    if (cosEnv('COS_BUCKET').isEmpty || cosEnv('COS_REGION').isEmpty) {
      debugPrint(
        '[trip_photo_test] COS Bucket/Region 仍为空：检查 cos.local.env 是否已加入 assets、是否已填值，'
        '或用 launch.json / --dart-define-from-file 编译注入。',
      );
    }
    // 初始化 Hive 持久化。
    await taskQueueRepository.init();
    await orderSessionRepository.init();
    await orderSessionRepository.ensureMockOrders();
    // 恢复登录状态。
    await AuthState.restore();
    isLoggedIn = await AuthState.isLoggedIn();
    if (isLoggedIn) {
      isLoggedIn = await AuthState.validateSessionWithServer();
    }
  } catch (e, st) {
    debugPrint('[trip_photo_test] 启动初始化失败: $e');
    debugPrint('$st');
    startupError = e.toString();
  }
  runApp(MyApp(startupError: startupError, isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final String? startupError;
  final bool isLoggedIn;

  const MyApp({super.key, this.startupError, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _loggedIn = false;
  String _displayNickName = '';
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loggedIn = widget.isLoggedIn;
    if (_loggedIn) {
      _loadHeaderNickName();
    }
  }

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
    _loadHeaderNickName();
  }

  Future<void> _deleteAccount(BuildContext pageContext) async {
    try {
      final userId = CloudBaseClient.instance.currentUserId;
      if (userId == null || userId <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(pageContext).showSnackBar(
          const SnackBar(content: Text('当前未登录，无法删除账号'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
            context: pageContext,
            builder: (context) => AlertDialog(
              title: const Text('删除账号'),
              content: const Text('删除后将清空该账号下的会话和客户数据，且无法恢复。确认继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认删除'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed || !mounted) return;
      setState(() => _deletingAccount = true);
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('正在删除账号...'), behavior: SnackBarBehavior.floating),
      );

      final resp = await CloudUserRepository().deleteMyAccount(userId);
      debugPrint(
        '[trip_photo_test] delete account result: status=${resp.statusCode}, ok=${resp.isSuccess}, data=${resp.data}',
      );
      if (!mounted) return;

      if (resp.isSuccess) {
        await AuthState.clear();
        if (!mounted) return;
        if (!pageContext.mounted) return;
        setState(() {
          _loggedIn = false;
          _displayNickName = '';
          _deletingAccount = false;
        });
        ScaffoldMessenger.of(pageContext).showSnackBar(
          const SnackBar(content: Text('账号已删除，请重新登录/注册'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      setState(() => _deletingAccount = false);
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text('删除失败：${resp.errorMessage ?? '请稍后重试'}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[trip_photo_test] delete account exception: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text('删除异常：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadHeaderNickName() async {
    String fallback = '';
    final phone = await AuthState.getPhone();
    if (phone != null && phone.trim().isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 11) {
        fallback = digits.substring(digits.length - 11);
      } else {
        fallback = digits;
      }
    }

    final userId = CloudBaseClient.instance.currentUserId;
    if (userId != null) {
      final user = await CloudUserRepository().getCurrentUser(userId);
      final nick = user?.nickName?.trim();
      if (nick != null && nick.isNotEmpty) {
        if (mounted) {
          setState(() => _displayNickName = nick);
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _displayNickName = fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅拍 COS 测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B7D)),
      ),
      home: widget.startupError != null
          ? _StartupErrorPage(error: widget.startupError!)
          : _loggedIn
              ? _buildMainApp()
              : LoginPage(onLoginSuccess: _onLoginSuccess),
    );
  }

  Widget _buildMainApp() {
    return Builder(
      builder: (pageContext) => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _displayNickName.isEmpty ? '青青旅拍' : '青青旅拍 + $_displayNickName',
            ),
            actions: [
              IconButton(
                onPressed: _deletingAccount ? null : () => _deleteAccount(pageContext),
                icon: _deletingAccount
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove_alt_1_rounded),
                tooltip: '删除账号',
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.photo_library_outlined), text: '相册上传'),
                Tab(icon: Icon(Icons.wifi_tethering), text: '索尼 WiFi'),
                Tab(icon: Icon(Icons.queue_rounded), text: '任务队列'),
                Tab(icon: Icon(Icons.list_alt_rounded), text: '订单'),
                Tab(icon: Icon(Icons.access_time_rounded), text: '上工'),
                Tab(icon: Icon(Icons.bar_chart_rounded), text: '统计'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              UploadTestPage(),
              SonyWifiUploadPage(),
              TaskQueuePage(),
              OrderPage(),
              WorkShiftPage(),
              DailyStatsPage(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  final String error;

  const _StartupErrorPage({required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 42),
              const SizedBox(height: 12),
              Text(
                '应用启动失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SelectableText(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 12),
              Text(
                '请完全退出 App 后重试；若仍失败，把这段错误发我排查。',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
