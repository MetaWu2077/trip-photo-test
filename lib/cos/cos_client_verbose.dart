// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:tencent_cos/tencent_cos.dart';
import 'package:tencent_cos/src/cos_clientbase.dart';
import 'package:tencent_cos/src/cos_comm.dart';
import 'package:tencent_cos/src/cos_exception.dart';

import 'cos_shared.dart';

/// 与 [COSClient] 相同上传逻辑，但失败时抛出 [COSException]（含状态码与 COS 返回体），便于排查 403/签名/策略等问题。
class COSClientVerbose extends COSClientBase {
  final COSConfig _cfg;

  COSClientVerbose(this._cfg) : super(_cfg);

  Future<String> putObjectWithFileDataOrThrow(
    String objectKey,
    List<int> fileData, {
    String? token,
    String? contentType = 'image/jpeg',
  }) async {
    cosLog('putObject');
    final fileLength = fileData.length;
    final req = await getRequest(
      'PUT',
      objectKey,
      headers: {
        'content-type': contentType,
        'content-length': fileLength.toString(),
      },
      token: token,
    );
    req.add(fileData);
    final response = await req.close();
    cosLog('request-id:${response.headers['x-cos-request-id']?.first ?? ''}');
    if (response.statusCode != 200) {
      final content = await response.transform(utf8.decoder).join('');
      cosLog('putObject error content: $content');
      throw COSException(response.statusCode, content);
    }
    return objectKey;
  }

  Future<String> putObjectOrThrow(
    String objectKey,
    String filePath, {
    String? token,
    String? contentType = 'image/jpeg',
  }) async {
    cosLog('putObject');
    final f = File(filePath);
    final flength = await f.length();
    final req = await getRequest(
      'PUT',
      objectKey,
      headers: {
        'content-type': contentType,
        'content-length': flength.toString(),
      },
      token: token,
    );
    final fs = f.openRead();
    await req.addStream(fs);
    final response = await req.close();
    cosLog('request-id:${response.headers['x-cos-request-id']?.first ?? ''}');
    if (response.statusCode != 200) {
      final content = await response.transform(utf8.decoder).join('');
      cosLog('putObject error content: $content');
      throw COSException(response.statusCode, content);
    }
    return objectKey;
  }

  /// 生成对象的下载 URL（临时签名，支持私有桶读取）。
  String getSignedDownloadUrl(String objectKey) {
    final normalizedKey = objectKey.startsWith('/') ? objectKey : '/$objectKey';
    final host = Uri.parse(_cfg.uri).host;
    final sign = getSign(
      'GET',
      normalizedKey,
      headers: {'host': host},
    );
    final baseUrl = cosObjectPublicUrl(publicCosBaseUrl(), objectKey);
    return '$baseUrl?$sign';
  }
}