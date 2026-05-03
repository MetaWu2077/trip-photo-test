import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tencent_cos/tencent_cos.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  COS.init(
    config: COSConfig(
      appId: const String.fromEnvironment('COS_APP_ID'),
      secretId: const String.fromEnvironment('COS_SECRET_ID'),
      secretKey: const String.fromEnvironment('COS_SECRET_KEY'),
      region: const String.fromEnvironment('COS_REGION'),
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '照片上传测试',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UploadTestPage(),
    );
  }
}

class UploadTestPage extends StatefulWidget {
  const UploadTestPage({super.key});

  @override
  State<UploadTestPage> createState() => _UploadTestPageState();
}

class _UploadTestPageState extends State<UploadTestPage> {
  final ImagePicker _picker = ImagePicker();
  String? _thumbnailUrl;
  String? _originalUrl;
  bool _isUploading = false;
  String _status = '点击下方按钮开始测试';

  Future<void> _requestPermissions() async {
    await [Permission.storage, Permission.photos].request();
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _isUploading = true;
      _status = '正在选择照片...';
    });

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _status = '已取消选择');
        return;
      }

      setState(() => _status = '正在生成缩略图...');
      final originalBytes = await File(image.path).readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) throw '无法解析图片';

      final thumbnail = img.copyResize(originalImage, width: 1080);
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);

      setState(() => _status = '正在上传缩略图...');
      final thumbKey = 'test/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await COS().putObject(
        bucket: const String.fromEnvironment('COS_BUCKET'),
        objectKey: thumbKey,
        data: thumbnailBytes,
      );

      final thumbUrl = '${const String.fromEnvironment('COS_DOMAIN')}/$thumbKey';

      setState(() => _status = '正在上传原图...');
      final originalKey = 'test/original_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await COS().putObject(
        bucket: const String.fromEnvironment('COS_BUCKET'),
        objectKey: originalKey,
        filePath: image.path,
      );

      final originalUrl = '${const String.fromEnvironment('COS_DOMAIN')}/$originalKey';

      setState(() {
        _thumbnailUrl = thumbUrl;
        _originalUrl = originalUrl;
        _isUploading = false;
        _status = '✅ 上传成功！';
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _status = '❌ 上传失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('照片上传测试 v1.0')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _status.contains('成功') ? Colors.green[50] : 
                     _status.contains('失败') ? Colors.red[50] : Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 18,
                    color: _status.contains('成功') ? Colors.green :
                           _status.contains('失败') ? Colors.red : Colors.blue[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isUploading ? null : _pickAndUpload,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isUploading ? '⏳ 上传中...' : '📸 选择照片并上传',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 40),
            if (_thumbnailUrl != null) ...[
              const Text('缩略图链接:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SelectableText(_thumbnailUrl!, style: const TextStyle(color: Colors.blue, fontSize: 12)),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
