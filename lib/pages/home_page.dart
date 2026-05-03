import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/cos_uploader.dart';

/// Runs image decode + resize + encode in a separate isolate to avoid jank.
Future<Uint8List?> _compressImageInIsolate(String filePath) async {
  return compute(_doCompress, filePath);
}

Uint8List? _doCompress(String filePath) {
  final bytes = File(filePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(decoded, width: 1080);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  // Selected / processed image
  File? _selectedImage;
  Uint8List? _thumbnailBytes;

  // Upload state
  bool _isUploading = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _thumbnailUrl;
  String? _originalUrl;

  // COS config (loaded once)
  late final CosEnvConfig _cosConfig;
  late final CosUploader _uploader;

  @override
  void initState() {
    super.initState();
    _cosConfig = CosEnvConfig.fromDotenv();
    _uploader = CosUploader(_cosConfig);
    _requestPermissions();
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    // On Android 13+ READ_MEDIA_IMAGES replaces READ_EXTERNAL_STORAGE.
    // permission_handler handles this automatically via the photos permission.
    final statuses = await [
      Permission.photos,
      Permission.storage,
    ].request();

    final denied =
        statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied);

    if (denied && mounted) {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('权限不足'),
        content: const Text(
          '请在系统设置中允许访问相册，否则无法选择照片。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // ── Pick & compress ───────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _statusMessage = '正在压缩图片…';
      _statusIsError = false;
      _thumbnailUrl = null;
      _originalUrl = null;
    });

    try {
      // Offload heavy image work to a separate isolate (avoid UI jank)
      final jpegBytes = await _compressImageInIsolate(picked.path);
      if (jpegBytes == null) throw Exception('无法解析图片格式');

      setState(() {
        _selectedImage = File(picked.path);
        _thumbnailBytes = jpegBytes;
        _statusMessage = '图片已就绪，点击上传按钮开始上传';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '处理图片失败：$e';
        _statusIsError = true;
      });
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_selectedImage == null || _thumbnailBytes == null) return;

    setState(() {
      _isUploading = true;
      _statusMessage = '正在上传缩略图…';
      _statusIsError = false;
    });

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Upload compressed thumbnail
      final thumbKey = 'trip-photos/thumb_$ts.jpg';
      final thumbUrl = await _uploader.uploadBytes(_thumbnailBytes!, thumbKey);

      setState(() => _statusMessage = '正在上传原图…');

      // Upload original file
      final origKey = 'trip-photos/original_$ts.jpg';
      final origUrl = await _uploader.uploadFile(_selectedImage!.path, origKey);

      setState(() {
        _isUploading = false;
        _thumbnailUrl = thumbUrl;
        _originalUrl = origUrl;
        _statusMessage = '✅ 上传成功！';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _statusMessage = '❌ 上传失败：$e';
        _statusIsError = true;
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅拍照片上传'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Config warning banner
            if (!_cosConfig.isConfigured) _buildConfigWarning(),

            // Image preview
            _buildImagePreview(),

            const SizedBox(height: 16),

            // Status card
            if (_statusMessage != null) _buildStatusCard(),

            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(),

            // Result URLs
            if (_thumbnailUrl != null || _originalUrl != null) ...[
              const SizedBox(height: 24),
              _buildResultUrls(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigWarning() {
    final missing = _cosConfig.missingFields;
    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '未配置腾讯 COS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('请在项目根目录创建 .env 文件并填写以下字段：'),
            const SizedBox(height: 4),
            for (final field in missing)
              Text('  • $field',
                  style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 4),
            const Text(
              '参考 .env.example 文件。配置完成前上传功能将被禁用。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: _thumbnailBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_thumbnailBytes!, fit: BoxFit.cover),
            )
          : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('尚未选择照片',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _statusIsError
          ? Colors.red[50]
          : _statusMessage!.contains('✅')
              ? Colors.green[50]
              : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (_isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_isUploading) const SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusIsError
                      ? Colors.red[700]
                      : _statusMessage!.contains('✅')
                          ? Colors.green[700]
                          : Colors.blue[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickImage,
          icon: const Icon(Icons.photo_library),
          label: const Text('从相册选择照片'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: (_isUploading ||
                  _selectedImage == null ||
                  !_cosConfig.isConfigured)
              ? null
              : _upload,
          icon: const Icon(Icons.cloud_upload),
          label: Text(_isUploading ? '上传中…' : '上传到腾讯 COS'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildResultUrls() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('上传结果',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (_thumbnailUrl != null) ...[
              const Text('缩略图 URL:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              SelectableText(_thumbnailUrl!,
                  style: const TextStyle(
                      color: Colors.blue, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            if (_originalUrl != null) ...[
              const Text('原图 URL:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              SelectableText(_originalUrl!,
                  style: const TextStyle(
                      color: Colors.blue, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
