import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 索尼相机 JSON-RPC（Camera Remote API）最小封装。
/// 注意：**部分机型（尤其 α6000）不提供 avContent / 相册拉取**，仅支持遥控拍摄。
class SonyJsonRpcError implements Exception {
  SonyJsonRpcError(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'Sony API [$code]: $message';
}

class SonyCameraRemoteClient {
  SonyCameraRemoteClient({required this.host, this.port = 8080});

  final String host;
  final int port;

  String get _base => 'http://$host:$port';

  Future<Map<String, dynamic>> _rpc(
    String path,
    String method,
    List<dynamic> params,
    String version,
  ) async {
    final uri = Uri.parse('$_base$path');
    final payload = <String, dynamic>{
      'method': method,
      'params': params,
      'id': DateTime.now().millisecondsSinceEpoch % 1000000,
      'version': version,
    };
    final r = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json;charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> map;
    try {
      map = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('非 JSON 响应 HTTP ${r.statusCode}: ${r.body.substring(0, r.body.length.clamp(0, 200))}');
    }
    if (map.containsKey('error')) {
      final err = map['error'];
      if (err is List && err.isNotEmpty) {
        final code = err[0] is int ? err[0] as int : int.tryParse('${err[0]}') ?? -1;
        final msg = err.length > 1 ? '${err[1]}' : 'unknown';
        throw SonyJsonRpcError(code, msg);
      }
      throw StateError('Sony error: $err');
    }
    return map;
  }

  /// 探测相机 JSON 服务是否可达（任意成功 RPC 即可）。
  Future<List<String>> getCameraVersions() async {
    final m = await _rpc('/sony/camera', 'getVersions', [], '1.0');
    final r = m['result'];
    if (r is List) return r.map((e) => '$e').toList();
    return [];
  }

  Future<void> startRecMode() async {
    await _rpc('/sony/camera', 'startRecMode', [], '1.0');
  }

  /// 若相机支持 avContent，返回版本列表；否则抛 [SonyJsonRpcError] 或 HTTP 错误。
  Future<List<String>> getAvContentVersions() async {
    final m = await _rpc('/sony/avContent', 'getVersions', [], '1.0');
    final r = m['result'];
    if (r is List) return r.map((e) => '$e').toList();
    return [];
  }

  static List<String> _extractStorageUris(dynamic r) {
    final uris = <String>[];
    void walk(dynamic n) {
      if (n is Map) {
        final u = n['uri'] ?? n['URI'];
        if (u is String && u.startsWith('storage:')) uris.add(u);
        n.forEach((_, v) => walk(v));
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(r);
    return uris.toSet().toList();
  }

  /// 索尼文档与各机型差异较大，依次尝试多种参数形态。
  Future<List<String>> discoverStorageUris(List<String> avVersions) async {
    final tries = <List<dynamic>>[
      [],
      [avVersions],
      [
        {'storage': 'memoryCard1'},
      ],
    ];
    for (final params in tries) {
      try {
        final m = await _rpc('/sony/avContent', 'getSourceList', params, '1.0');
        final uris = _extractStorageUris(m['result']);
        if (uris.isNotEmpty) return uris;
      } catch (e) {
        debugPrint('[Sony] getSourceList($params) 失败: $e');
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> getContentList({
    required String storageUri,
    int stIdx = 0,
    int cnt = 30,
  }) async {
    final m = await _rpc(
      '/sony/avContent',
      'getContentList',
      [
        {
          'uri': storageUri,
          'stIdx': stIdx,
          'cnt': cnt,
          'view': 'flat',
          'sort': 'descending',
        },
      ],
      '1.3',
    );
    final r = m['result'];
    if (r is Map<String, dynamic>) return r;
    return {'_raw': r};
  }

  /// 从 getContentList / 嵌套结构里找第一条可下载的原图 URL（勿对 URL 做多余 decode）。
  static String? findFirstOriginalUrl(dynamic node) {
    if (node is Map) {
      final orig = node['original'];
      if (orig is List) {
        for (final o in orig) {
          if (o is Map && o['url'] is String) {
            return o['url'] as String;
          }
        }
      }
      for (final v in node.values) {
        final u = findFirstOriginalUrl(v);
        if (u != null) return u;
      }
    } else if (node is List) {
      for (final v in node) {
        final u = findFirstOriginalUrl(v);
        if (u != null) return u;
      }
    }
    return null;
  }

  /// 收集树中所有 `original[].url`（去重且保持大致顺序）。
  static List<String> findAllOriginalUrls(dynamic node) {
    final seen = <String>{};
    final ordered = <String>[];

    void walk(dynamic n) {
      if (n is Map) {
        final orig = n['original'];
        if (orig is List) {
          for (final o in orig) {
            if (o is Map && o['url'] is String) {
              final u = o['url'] as String;
              if (seen.add(u)) ordered.add(u);
            }
          }
        }
        for (final v in n.values) {
          walk(v);
        }
      } else if (n is List) {
        for (final v in n) {
          walk(v);
        }
      }
    }

    walk(node);
    return ordered;
  }

  static String? findLargeUrl(dynamic node) {
    if (node is Map) {
      for (final key in ['largeUrl', 'large', 'smallUrl', 'small']) {
        if (node[key] is Map && (node[key] as Map)['url'] is String) {
          return (node[key] as Map)['url'] as String;
        }
      }
      for (final v in node.values) {
        final u = findLargeUrl(v);
        if (u != null) return u;
      }
    } else if (node is List) {
      for (final v in node) {
        final u = findLargeUrl(v);
        if (u != null) return u;
      }
    }
    return null;
  }

  Future<Uint8List> downloadImageBytes(String url) async {
    final uri = Uri.parse(url);
    final r = await http.get(uri).timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) {
      throw StateError('下载失败 HTTP ${r.statusCode}');
    }
    return r.bodyBytes;
  }

  /// 完整流程：启动遥控 →（可选）切相册 → 列存储 → 列文件 → 下载最新一张。
  Future<Uint8List> fetchLatestImageBytes() async {
    await startRecMode();
    try {
      await _rpc('/sony/camera', 'setCameraFunction', ['Contents Transfer'], '1.0');
    } on SonyJsonRpcError catch (e) {
      debugPrint('[Sony] setCameraFunction 忽略: $e');
    }

    final avVers = await getAvContentVersions();
    if (avVers.isEmpty) {
      throw StateError('相机未返回 avContent 版本');
    }

    final sources = await discoverStorageUris(avVers);
    if (sources.isEmpty) {
      throw StateError('getSourceList 无可用存储（storage:*）。卡是否插入？');
    }

    final storageUri = sources.first;
    final listResult = await getContentList(storageUri: storageUri);
    var url = findFirstOriginalUrl(listResult);
    url ??= findLargeUrl(listResult);
    if (url == null || url.isEmpty) {
      debugPrint('[Sony] getContentList 原始: $listResult');
      throw StateError('未在列表中解析到图片下载 URL（机型可能返回结构不同）');
    }

    return downloadImageBytes(url);
  }

  /// 分页拉取某存储卷下全部 `original` 下载地址（依赖机型返回结构）。
  Future<List<String>> listAllOriginalUrlsPaged(String storageUri) async {
    final out = <String>[];
    final seen = <String>{};
    var stIdx = 0;
    const cnt = 50;

    while (stIdx < 10000) {
      final map = await getContentList(storageUri: storageUri, stIdx: stIdx, cnt: cnt);
      final raw = map['result'] ?? map['_raw'];
      final payload = raw is List && raw.isNotEmpty ? raw.first : raw;
      var batch = findAllOriginalUrls(payload);
      if (batch.isEmpty) {
        batch = findAllOriginalUrls(map);
      }
      if (batch.isEmpty) {
        break;
      }
      for (final u in batch) {
        if (seen.add(u)) {
          out.add(u);
        }
      }
      if (batch.length < cnt) {
        break;
      }
      stIdx += cnt;
    }

    return out;
  }

  /// 枚举存储卷并返回卡内全部照片下载 URL（用于批量上传）。
  Future<List<String>> listAllOriginalUrlsFromCamera() async {
    await startRecMode();
    try {
      await _rpc('/sony/camera', 'setCameraFunction', ['Contents Transfer'], '1.0');
    } on SonyJsonRpcError catch (e) {
      debugPrint('[Sony] setCameraFunction 忽略: $e');
    }

    final avVers = await getAvContentVersions();
    if (avVers.isEmpty) {
      throw StateError('相机未返回 avContent 版本');
    }

    final sources = await discoverStorageUris(avVers);
    if (sources.isEmpty) {
      throw StateError('getSourceList 无可用存储（storage:*)');
    }

    final all = <String>[];
    for (final storageUri in sources) {
      final part = await listAllOriginalUrlsPaged(storageUri);
      all.addAll(part);
    }
    return all;
  }
}

/// 依次尝试常见端口连接相机。
Future<SonyCameraRemoteClient?> tryConnectSony(String host) async {
  for (final p in [8080, 10000]) {
    try {
      final c = SonyCameraRemoteClient(host: host, port: p);
      await c.getCameraVersions();
      return c;
    } catch (_) {
      continue;
    }
  }
  return null;
}
