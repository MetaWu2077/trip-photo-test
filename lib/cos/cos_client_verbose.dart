// ignore_for_file: implementation_imports — 需复用包内签名与请求逻辑以抛出详细 COSException

import 'dart:convert';
import 'dart:io';

import 'package:tencent_cos/src/cos_clientbase.dart';
import 'package:tencent_cos/src/cos_comm.dart';
import 'package:tencent_cos/src/cos_exception.dart';

/// 与 [COSClient] 相同上传逻辑，但失败时抛出 [COSException]（含状态码与 COS 返回体），便于排查 403/签名/策略等问题。
class COSClientVerbose extends COSClientBase {
  COSClientVerbose(super.config);

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
}
