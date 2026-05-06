import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cos/cos_shared.dart';
import '../../image/pipeline.dart';
import '../../sony/sony_client.dart';

/// 与相机同一局域网时，通过索尼 Camera Remote API 拉取照片并上传 COS。
/// **α6000 等老机型常不提供 avContent（无法 API 读卡）**，仅「相册上传」页可用。
class SonyWifiUploadPage extends StatefulWidget {
  const SonyWifiUploadPage({super.key});

  @override
  State<SonyWifiUploadPage> createState() => _SonyWifiUploadPageState();
}

class _SonyWifiUploadPageState extends State<SonyWifiUploadPage> {
  final _ipCtrl = TextEditingController(text: '192.168.43.1');
  final _portCtrl = TextEditingController(text: '8080');

  String _status =
      '手机与相机连同一 Wi‑Fi 后，填写相机 IP（可在相机网络菜单或路由器里查看），先「检测连接」再上传。';
  bool _busy = false;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _busy = true;
      _status = '正在连接相机…';
    });
    try {
      final auto = await tryConnectSony(ip);
      if (auto != null) {
        final v = await auto.getCameraVersions();
        if (!mounted) return;
        setState(() {
          _portCtrl.text = '${auto.port}';
          _status = '已连接 Camera 服务，版本: ${v.join(", ")}。\n'
              '若拉取照片失败，多半是机型不支持 avContent（见下方说明）。';
        });
        return;
      }
      final port = int.tryParse(_portCtrl.text.trim()) ?? 8080;
      final c = SonyCameraRemoteClient(host: ip, port: port);
      final v = await c.getCameraVersions();
      if (!mounted) return;
      setState(() {
        _status = '已连接（端口 $port），Camera API 版本: ${v.join(", ")}。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '连接失败: $e\n请确认 IP、端口（常见 8080 / 10000），且相机已开启「智能手机遥控」等 PC 遥控模式。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SonyCameraRemoteClient> _resolveClient(String ip) async {
    final auto = await tryConnectSony(ip);
    final client = auto ??
        SonyCameraRemoteClient(
          host: ip,
          port: int.tryParse(_portCtrl.text.trim()) ?? 8080,
        );
    if (auto != null) {
      _portCtrl.text = '${auto.port}';
    }
    return client;
  }

  Future<void> _fetchAllAndUpload() async {
    if (cosEnv('COS_SECRET_ID').isEmpty ||
        cosEnv('COS_SECRET_KEY').isEmpty ||
        cosEnv('COS_BUCKET').isEmpty ||
        cosEnv('COS_REGION').isEmpty) {
      setState(() => _status = 'COS 未配置，请先配置 cos.local.env 或使用调试启动参数。');
      return;
    }

    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _status = '请填写相机 IP');
      return;
    }

    setState(() {
      _busy = true;
      _status = '正在扫描存储卡并枚举照片 URL…';
    });

    try {
      final client = await _resolveClient(ip);
      List<String> urls;
      try {
        urls = await client.listAllOriginalUrlsFromCamera();
      } on SonyJsonRpcError catch (e) {
        throw StateError(
          '索尼 API: $e\n'
          '若机型为 ILCE-6000，通常不支持 avContent 列目录，无法 WiFi 自动拉卡内照片；'
          '请使用「相册上传」或换机/接 USB 方案。',
        );
      }

      if (urls.isEmpty) {
        throw StateError('未扫描到任何 original 下载地址（卡内可能无 JPEG，或 API 结构与本解析器不匹配）。');
      }

      final base = publicCosBaseUrl();
      final lines = <String>[];

      for (var i = 0; i < urls.length; i++) {
        if (!mounted) return;
        setState(() => _status = '下载并上传 ${i + 1}/${urls.length} …');

        final bytes = await client.downloadImageBytes(urls[i]);
        final processed = await compute(processPickedImageForUpload, bytes);
        if (!mounted) return;

        final ts = DateTime.now().millisecondsSinceEpoch;
        final thumbKey = 'sony/thumb_${ts}_$i.jpg';
        final originalKey = 'sony/original_${ts}_$i.jpg';

        await cosClient.putObjectWithFileDataOrThrow(thumbKey, processed.thumb);
        await cosClient.putObjectWithFileDataOrThrow(originalKey, bytes);

        lines.add(cosObjectPublicUrl(base, originalKey));
      }

      if (!mounted) return;
      setState(() {
        _status = '已全部上传完成，共 ${urls.length} 张。\n${lines.join('\n')}';
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (!mounted) return;
      setState(() {
        _status = cosUserFacingError(e);
        _busy = false;
      });
    }
  }

  Future<void> _fetchAndUpload() async {
    if (cosEnv('COS_SECRET_ID').isEmpty ||
        cosEnv('COS_SECRET_KEY').isEmpty ||
        cosEnv('COS_BUCKET').isEmpty ||
        cosEnv('COS_REGION').isEmpty) {
      setState(() => _status = 'COS 未配置，请先配置 cos.local.env 或使用调试启动参数。');
      return;
    }

    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _status = '请填写相机 IP');
      return;
    }

    setState(() {
      _busy = true;
      _status = '正在从相机获取照片…';
    });

    try {
      final client = await _resolveClient(ip);

      Uint8List bytes;
      try {
        bytes = await client.fetchLatestImageBytes();
      } on SonyJsonRpcError catch (e) {
        throw StateError(
          '索尼 API 拒绝: $e\n'
          'ILCE-6000 等机型常不支持「Contents Transfer / avContent」读卡，官方多为「发到智能手机」走 Imaging Edge，无法用本 JSON API 自动列目录。\n'
          '可选：换支持 API 传图的机型、或使用 USB OTG + 后续工程接入。',
        );
      }

      setState(() => _status = '已下载 ${bytes.length} 字节，处理并上传 COS…');

      final processed = await compute(processPickedImageForUpload, bytes);
      if (!mounted) return;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final thumbKey = 'sony/thumb_$ts.jpg';
      final originalKey = 'sony/original_$ts.jpg';

      await cosClient.putObjectWithFileDataOrThrow(thumbKey, processed.thumb);
      await cosClient.putObjectWithFileDataOrThrow(originalKey, bytes);

      final base = publicCosBaseUrl();
      final thumbUrl = cosObjectPublicUrl(base, thumbKey);
      final originalUrl = cosObjectPublicUrl(base, originalKey);

      if (!mounted) return;
      setState(() {
        _status = '上传完成。\n缩略图: $thumbUrl\n原图: $originalUrl';
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (!mounted) return;
      setState(() {
        _status = cosUserFacingError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('相机 IP', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ipCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: '与手机同网段，如 192.168.43.1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('端口（可选，默认尝试 8080 / 10000）',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '8080',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _testConnection,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('检测连接'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _fetchAndUpload,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('拉取最新一张并上传 COS'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _fetchAllAndUpload,
              icon: const Icon(Icons.collections_outlined),
              label: const Text('扫描并上传存储卡内全部照片'),
            ),
            const SizedBox(height: 16),
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    color: _status.startsWith('失败') ? scheme.error : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '说明：索尼官方远程协议为局域网 HTTP（明文）。Android 需开启允许明文流量（已在 Manifest 配置）。'
              ' α6000 若无法拉片属机型限制，并非配置错误。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
