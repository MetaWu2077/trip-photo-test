import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 顾客端 API 客户端。
/// 连接到 trip-api 后端。
class ApiClient {
  // TODO: 替换为实际部署的 trip-api 地址
  static String get baseUrl {
    if (kIsWeb) {
      // Web 端使用相对路径或云开发环境变量
      return 'https://trip-api.example.com'; // 示例，生产环境替换
    }
    return 'http://localhost:3000';
  }

  final String? _accessToken;

  ApiClient({String? accessToken}) : _accessToken = accessToken;

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_accessToken != null) {
      h['Authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final resp = await http.get(uri, headers: _headers);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(resp);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.patch(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw ApiException(resp.statusCode, data['error'] ?? 'Unknown error');
    }
    return data;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
