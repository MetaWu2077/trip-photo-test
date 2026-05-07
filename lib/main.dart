import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'cos/cos_shared.dart';
import 'features/sony/sony_wifi_upload_page.dart';
import 'features/upload/upload_page.dart';
import 'features/upload/repositories/task_queue_repository.dart';
import 'features/upload/repositories/order_session_repository.dart';
import 'features/upload/order_page.dart';
import 'features/upload/task_queue_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;
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
  } catch (e, st) {
    debugPrint('[trip_photo_test] 启动初始化失败: $e');
    debugPrint('$st');
    startupError = e.toString();
  }
  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  final String? startupError;

  const MyApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅拍 COS 测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B7D)),
      ),
      home: startupError == null
          ? DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('旅拍 COS'),
                  bottom: const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.photo_library_outlined), text: '相册上传'),
                      Tab(icon: Icon(Icons.wifi_tethering), text: '索尼 WiFi'),
                      Tab(icon: Icon(Icons.queue_rounded), text: '任务队列'),
                      Tab(icon: Icon(Icons.list_alt_rounded), text: '订单'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: [
                    UploadTestPage(),
                    SonyWifiUploadPage(),
                    TaskQueuePage(),
                    OrderPage(),
                  ],
                ),
              ),
            )
          : _StartupErrorPage(error: startupError!),
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
