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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '旅拍 COS 测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B7D)),
      ),
      home: DefaultTabController(
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
      ),
    );
  }
}
