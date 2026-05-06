import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: implementation_imports
import 'package:tencent_cos/src/cos_exception.dart';
import 'package:tencent_cos/tencent_cos.dart';

import 'cos_client_verbose.dart';

/// 编译期 `--dart-define` / `--dart-define-from-file` 优先，其次 flutter_dotenv，最后桌面端可读项目根 `cos.local.env`。
final Map<String, String> cosLocalFileMap = {};

void tryLoadCosLocalEnvFromDisk() {
  if (kIsWeb) return;
  if (Platform.isAndroid || Platform.isIOS) return;
  try {
    final f = File('cos.local.env');
    if (!f.existsSync()) return;
    for (final raw in f.readAsLinesSync()) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final k = line.substring(0, eq).trim();
      var v = line.substring(eq + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))) {
        v = v.substring(1, v.length - 1);
      }
      if (k.isNotEmpty) cosLocalFileMap[k] = sanitizeCosValue(v);
    }
  } catch (e, st) {
    debugPrint('[trip_photo_test] 读取 cos.local.env: $e\n$st');
  }
}

String sanitizeCosValue(String raw) {
  var s = raw.trim();
  while (s.endsWith(',') || s.endsWith('"') || s.endsWith("'")) {
    s = s.substring(0, s.length - 1).trim();
  }
  while (s.startsWith('"') || s.startsWith("'")) {
    s = s.substring(1).trim();
  }
  return s;
}

String cosEnv(String key) {
  final a = String.fromEnvironment(key, defaultValue: '').trim();
  if (a.isNotEmpty) return sanitizeCosValue(a);
  final b = dotenv.env[key]?.trim();
  if (b != null && b.isNotEmpty) return sanitizeCosValue(b);
  return sanitizeCosValue((cosLocalFileMap[key] ?? '').trim());
}

String publicCosBaseUrl() {
  final custom = cosEnv('COS_DOMAIN').trim();
  if (custom.isNotEmpty) {
    return custom.endsWith('/')
        ? custom.substring(0, custom.length - 1)
        : custom;
  }
  final b = cosEnv('COS_BUCKET');
  final r = cosEnv('COS_REGION');
  if (b.isNotEmpty && r.isNotEmpty) {
    return 'https://$b.cos.$r.myqcloud.com';
  }
  return '';
}

String cosUserFacingError(Object e) {
  if (e is COSException) {
    final msg = e.msg;
    final short =
        msg.length > 900 ? '${msg.substring(0, 900)}…（已截断，可复制后全文排查）' : msg;
    return '失败: COS 返回 HTTP ${e.statusCode}\n$short';
  }
  final s = e.toString();
  if (e is SocketException ||
      s.contains('Connection reset by peer') ||
      s.contains('Connection refused') ||
      s.contains('Network is unreachable')) {
    return '失败: $s\n\n'
        '这表示到腾讯云 COS 的 TCP/HTTPS 在途中被对端或网络设备「掐断」，通常不是桶名/Region 写错（那种多为 403/404 的 HTTP 响应）。\n'
        '可依次尝试：换 Wi‑Fi 或手机热点、关闭 VPN/系统代理/抓包软件、用真机跑同一套包、'
        '模拟器做 Cold Boot 或换镜像、确认电脑能打开桶域名（可在本机 PowerShell 执行：'
        'curl -I 你的完整桶 URL）。';
  }
  return '失败: $s';
}

COSClientVerbose get cosClient => COSClientVerbose(
      COSConfig(
        cosEnv('COS_SECRET_ID'),
        cosEnv('COS_SECRET_KEY'),
        cosEnv('COS_BUCKET'),
        cosEnv('COS_REGION'),
      ),
    );

String cosObjectPublicUrl(String domain, String objectKey) {
  final d = domain.trim();
  final base = d.endsWith('/') ? d.substring(0, d.length - 1) : d;
  final key = objectKey.startsWith('/') ? objectKey.substring(1) : objectKey;
  return '$base/$key';
}
