import 'dart:convert';
import 'package:http/http.dart' as http;

/// CloudBase HTTP Service 客户端单例。
/// Flutter 原生 App 通过 HTTP Service 访问 trip-api 云函数。
/// HTTP Service 地址: https://xinpan-6gx80api83a29c6b-1257084760.ap-shanghai.app.tcloudbase.com/trip-api
class CloudBaseClient {
  /// 云函数 HTTP Service 基础地址（trip-api）
  static const String _fnBaseUrl =
      'https://xinpan-6gx80api83a29c6b-1257084760.ap-shanghai.app.tcloudbase.com/trip-api';

  /// 当前登录用户的云端 userId（MySQL 自增 ID）
  int? currentUserId;

  /// 当前 Access Token（JWT，来自 AuthClient）
  String? accessToken;

  final http.Client _client;

  CloudBaseClient._() : _client = http.Client();

  static final CloudBaseClient _instance = CloudBaseClient._();
  static CloudBaseClient get instance => _instance;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  /// 通用 GET 请求。
  Future<CloudBaseResponse> get(String path,
      {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('$_fnBaseUrl$path');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final resp = await _client.get(uri, headers: _headers);
      return _parseResponse(resp);
    } catch (e) {
      return CloudBaseResponse.error(e.toString());
    }
  }

  /// 通用 POST 请求。
  Future<CloudBaseResponse> post(String path,
      {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$_fnBaseUrl$path');
      final resp = await _client.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _parseResponse(resp);
    } catch (e) {
      return CloudBaseResponse.error(e.toString());
    }
  }

  /// 通用 PATCH 请求。
  Future<CloudBaseResponse> patch(String path,
      {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$_fnBaseUrl$path');
      final resp = await _client.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _parseResponse(resp);
    } catch (e) {
      return CloudBaseResponse.error(e.toString());
    }
  }

  /// 通用 DELETE 请求。
  Future<CloudBaseResponse> delete(String path) async {
    try {
      final uri = Uri.parse('$_fnBaseUrl$path');
      final resp = await _client.delete(uri, headers: _headers);
      return _parseResponse(resp);
    } catch (e) {
      return CloudBaseResponse.error(e.toString());
    }
  }

  CloudBaseResponse _parseResponse(http.Response resp) {
    if (resp.body.isEmpty) {
      return CloudBaseResponse(
        statusCode: resp.statusCode,
        data: null,
        message: 'Empty response',
      );
    }
    try {
      final data = jsonDecode(resp.body);
      return CloudBaseResponse(
        statusCode: resp.statusCode,
        data: data,
        message: data is Map ? data['message'] as String? ?? data['error'] as String? : null,
      );
    } catch (_) {
      return CloudBaseResponse(
        statusCode: resp.statusCode,
        data: resp.body,
        message: null,
      );
    }
  }
}

/// HTTP 响应包装。
class CloudBaseResponse {
  final int statusCode;
  final dynamic data;
  final String? message;

  CloudBaseResponse({
    required this.statusCode,
    required this.data,
    this.message,
  });

  factory CloudBaseResponse.error(String error) {
    return CloudBaseResponse(
      statusCode: -1,
      data: null,
      message: error,
    );
  }

  bool get isSuccess =>
      statusCode >= 200 && statusCode < 300 && data != null;

  String? get errorMessage =>
      message ?? (data is Map ? data['message'] as String? ?? data['error'] as String? : null);
}
