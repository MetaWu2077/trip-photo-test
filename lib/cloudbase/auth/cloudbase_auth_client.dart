import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_state.dart';
import 'package:flutter/foundation.dart';
import '../cloudbase_client.dart';

/// CloudBase Auth v1 HTTP API 客户端。
/// 用于 Flutter 原生 App（手机号 + 短信验证码登录/注册）。
///
/// 流程：
/// 1. sendCode(phone)       → 发送短信验证码，返回 verification_id
/// 2. verifyCode(phone, code, verification_id) → 验证通过后登录/注册，返回 access_token + refresh_token
///
/// 环境：xinpan-6gx80api83a29c6b
/// Base URL: https://xinpan-6gx80api83a29c6b.ap-shanghai.tcb-api.tencentcloudapi.com/auth/v1
class CloudBaseAuthClient {
  static const String _baseUrl =
      'https://xinpan-6gx80api83a29c6b.ap-shanghai.tcb-api.tencentcloudapi.com/auth/v1';

  final http.Client _httpClient = http.Client();

  /// 发送短信验证码。
  /// [phone] 国内手机号如 "18225062787"（自动加 +86）
  /// 返回 verification_id（5 分钟有效）
  Future<AuthResult> sendCode(String phone) async {
    // 规范化为国际格式
    final normalized = _normalizePhone(phone);

    try {
      final uri = Uri.parse('$_baseUrl/verification');
      final resp = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-device-id': 'trip-photo-flutter',
        },
        body: jsonEncode({'phone_number': normalized}),
      );

      if (resp.statusCode != 200) {
        final body = _parseErrorBody(resp.body);
        if (body != null && body.contains('用户已存在')) {
          return AuthResult.failure('该手机号已注册，请直接登录（输入任意验证码即可登录）');
        }
        return AuthResult.failure(body ?? '发送验证码失败 (${resp.statusCode})');
      }

      final data = jsonDecode(resp.body);
      // 成功响应直接是 JWT 字符串
      if (data is String) {
        return AuthResult.success(verificationId: data);
      }
      // 也可能是 { token: "..." } 或 { verification_id: "..." }
      if (data is Map) {
        final token = data['token'] ?? data['verification_id'];
        if (token is String) {
          return AuthResult.success(verificationId: token);
        }
      }
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('网络异常：$e');
    }
  }

  /// 验证短信验证码并登录。
  /// [phone] 国内手机号如 "18225062787"
  /// [code] 用户收到的 6 位短信验证码
  /// [verificationId] sendCode 返回的 verification_id
  Future<AuthResult> verifyCode(
    String phone,
    String code,
    String verificationId,
  ) async {
    final normalized = _normalizePhone(phone);

    try {
      final uri = Uri.parse('$_baseUrl/verification/verify');
      final resp = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-device-id': 'trip-photo-flutter',
        },
        body: jsonEncode({
          'phone_number': normalized,
          'verification_code': code,
          'verification_id': verificationId,
        }),
      );

      if (resp.statusCode != 200) {
        final body = _parseErrorBody(resp.body);
        return AuthResult.failure(body ?? '验证码验证失败 (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return AuthResult.failure('登录失败：服务端返回格式异常');
      }
      final data = decoded;
      debugPrint('CloudBase verify response: $data');

      // 兼容后端直接在 verify 返回 token 的场景。
      final tokenSaved = await _trySaveTokensFromPayload(data, normalized);
      if (tokenSaved) {
        final userId = await _syncTripApiUser(normalized);
        if (userId == null) {
          return AuthResult.failure('登录成功，但业务用户同步失败（users 表未写入）');
        }
        return AuthResult.success(phone: normalized, userId: userId);
      }

      // verify 返回 { verification_token: "...", expires_in: 600 }
      // 需要第三步 /signup 用 verification_token 换取真正的 access_token + refresh_token
      final verificationToken = _extractString(data, const [
        ['verification_token'],
        ['verificationToken'],
        ['token'],
        ['data', 'verification_token'],
        ['result', 'verification_token'],
      ]);
      if (verificationToken == null) {
        return AuthResult.failure('登录失败：未获取到 verification_token');
      }

      // 先尝试 signin（老用户），失败再尝试 signup（新用户）。
      final signInResult = await _signInWithVerificationToken(
        phone: normalized,
        verificationToken: verificationToken,
      );
      if (signInResult.isSuccess) {
        return signInResult;
      }

      final signUpResult = await _signUp(normalized, verificationToken);
      if (signUpResult.isSuccess) {
        return signUpResult;
      }

      final signInRetry = await _signInWithVerificationToken(
        phone: normalized,
        verificationToken: verificationToken,
      );
      if (signInRetry.isSuccess) {
        return signInRetry;
      }

      return AuthResult.failure(
        signUpResult.errorMessage ??
            signInResult.errorMessage ??
            '登录失败：注册/登录均未成功',
      );
    } catch (e) {
      return AuthResult.failure('登录异常：$e');
    }
  }

  Future<AuthResult> _signInWithVerificationToken({
    required String phone,
    required String verificationToken,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/signin');
      final resp = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-device-id': 'trip-photo-flutter',
        },
        body: jsonEncode({
          'verification_token': verificationToken,
        }),
      );
      debugPrint('CloudBase signin status: ${resp.statusCode}');
      debugPrint('CloudBase signin body: ${resp.body}');

      if (resp.statusCode != 200) {
        final body = _parseErrorBody(resp.body);
        if (body != null && body.contains('用户已存在')) {
          return AuthResult.failure('该手机号已注册，请直接登录（输入任意验证码即可登录）');
        }
        return AuthResult.failure(body ?? '登录失败 (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return AuthResult.failure('登录失败：服务端返回格式异常');
      }
      final data = decoded;
      final tokenSaved = await _trySaveTokensFromPayload(data, phone);
      if (!tokenSaved) {
        return AuthResult.failure('登录失败：未获取到 token');
      }
      final userId = await _syncTripApiUser(phone);
      if (userId == null) {
        return AuthResult.failure('登录成功，但业务用户同步失败（users 表未写入）');
      }
      return AuthResult.success(phone: phone, userId: userId);
    } catch (e) {
      return AuthResult.failure('登录异常：$e');
    }
  }

  /// 第三步：用已验证的 verification_token 向 /signup 换取正式 access_token + refresh_token
  Future<AuthResult> _signUp(String phone, String verificationToken) async {
    try {
      final uri = Uri.parse('$_baseUrl/signup');
      for (var attempt = 0; attempt < 4; attempt++) {
        final username = _buildSignupUsername(phone, attempt: attempt);
        final resp = await _httpClient.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-device-id': 'trip-photo-flutter',
            // Flutter App 前端没有 clientSecret，不使用 HTTP Basic Auth
          },
          body: jsonEncode({
            'phone_number': phone,
            'verification_token': verificationToken,
            // username 需满足 ^$|^[a-z][0-9a-z_-]{5,24}$ ，不能数字开头。
            'username': username,
            'password': '',
            'name': '手机用户',
          }),
        );

        debugPrint('CloudBase signup attempt=$attempt status=${resp.statusCode}');
        debugPrint('CloudBase signup body: ${resp.body}');

        if (resp.statusCode != 200) {
          final body = _parseErrorBody(resp.body);
          // "用户已存在" = 手机号已注册，应直接跳 signin，不要重试
          if (body != null && body.contains('用户已存在')) {
            return AuthResult.failure('该手机号已注册，请直接登录');
          }
          final mayUsernameConflict = body != null &&
              (body.contains('Username') ||
                  body.contains('username') ||
                  body.contains('用户名') ||
                  body.contains('used'));
          if (attempt < 3 && mayUsernameConflict) {
            continue;
          }
          return AuthResult.failure(body ?? '注册失败 (${resp.statusCode})');
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map<String, dynamic>) {
          return AuthResult.failure('注册失败：服务端返回格式异常');
        }
        final data = decoded;
        debugPrint('CloudBase signup response: $data');
        final tokenSaved = await _trySaveTokensFromPayload(data, phone);
        if (!tokenSaved) {
          return AuthResult.failure('注册失败：未获取到 token');
        }
        final userId = await _syncTripApiUser(phone);
        if (userId == null) {
          return AuthResult.failure('注册成功，但业务用户同步失败（users 表未写入）');
        }
        return AuthResult.success(phone: phone, userId: userId);
      }
      return AuthResult.failure('注册失败：用户名冲突重试后仍失败');
    } catch (e) {
      return AuthResult.failure('注册异常：$e');
    }
  }

  /// 登出。
  Future<void> signOut() async {
    await AuthState.clear();
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    // 国内手机号自动加 +86
    if (trimmed.startsWith('1') && trimmed.length == 11) {
      return '+86 $trimmed';
    }
    return trimmed;
  }

  String? _parseErrorBody(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        // 兼容 CloudBase Auth 常见错误格式
        final topLevel = data['error_description'] as String? ??
            data['error'] as String? ??
            data['message'] as String?;
        if (topLevel != null && topLevel.isNotEmpty) return topLevel;
        // { "Error": { "Code": "...", "Message": "..." } }
        final err = data['Error'] as Map?;
        if (err != null) {
          return (err['Message'] ?? err['Code'] ?? err['message'])?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _trySaveTokensFromPayload(
    Map<String, dynamic> data,
    String phone,
  ) async {
    final accessToken = _extractString(data, const [
      ['token_info', 'access_token'],
      ['tokenInfo', 'accessToken'],
      ['access_token'],
      ['accessToken'],
      ['data', 'token_info', 'access_token'],
      ['data', 'access_token'],
      ['result', 'token_info', 'access_token'],
      ['result', 'access_token'],
      ['token', 'access_token'],
      ['tokens', 'access_token'],
    ]);
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }
    final refreshToken = _extractString(data, const [
      ['token_info', 'refresh_token'],
      ['tokenInfo', 'refreshToken'],
      ['refresh_token'],
      ['refreshToken'],
      ['data', 'token_info', 'refresh_token'],
      ['data', 'refresh_token'],
      ['result', 'token_info', 'refresh_token'],
      ['result', 'refresh_token'],
      ['token', 'refresh_token'],
      ['tokens', 'refresh_token'],
    ]);

    await AuthState.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      phone: phone,
    );
    return true;
  }

  Future<int?> _syncTripApiUser(String phone) async {
    final resp = await CloudBaseClient.instance.post('/auth/verify', body: {
      'phone': phone,
      'code': 'cloudbase',
    });
    if (!resp.isSuccess || resp.data == null) {
      debugPrint('trip-api user sync failed: status=${resp.statusCode}, data=${resp.data}');
      return null;
    }
    final data = resp.data is Map ? resp.data as Map<String, dynamic> : {};
    final user = data['user'] is Map ? data['user'] as Map<String, dynamic> : null;
    final rawId = user?['id'];
    final userId = rawId is int ? rawId : int.tryParse('$rawId');
    if (userId == null) {
      debugPrint('trip-api user sync missing user.id: $data');
      return null;
    }
    final phone11 = _extractPhone11(phone);
    if (phone11.isNotEmpty) {
      final patchResp = await CloudBaseClient.instance.patch('/users/$userId', body: {
        'nick_name': phone11,
      });
      debugPrint(
        'trip-api nick sync: userId=$userId status=${patchResp.statusCode} ok=${patchResp.isSuccess}',
      );
    }
    await AuthState.saveUserId(userId);
    debugPrint('trip-api user sync success: userId=$userId, phone=$phone');
    return userId;
  }

  String? _extractString(
    Map<String, dynamic> root,
    List<List<String>> candidatePaths,
  ) {
    for (final path in candidatePaths) {
      dynamic cursor = root;
      var ok = true;
      for (final segment in path) {
        if (cursor is Map && cursor.containsKey(segment)) {
          cursor = cursor[segment];
        } else {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      if (cursor is String && cursor.isNotEmpty) return cursor;
    }
    return null;
  }

  String _buildSignupUsername(String phone, {int attempt = 0}) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    final tail = digits.isEmpty ? '000000' : digits;
    final suffix = attempt == 0 ? '' : '_$attempt';
    final raw = 'u$tail$suffix';
    final normalized = raw.toLowerCase().replaceAll(RegExp(r'[^0-9a-z_-]'), '');
    if (normalized.length >= 6 && normalized.length <= 25) {
      return normalized;
    }
    if (normalized.length > 25) {
      return normalized.substring(0, 25);
    }
    return normalized.padRight(6, '0');
  }

  String _extractPhone11(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 11) {
      return digits.substring(digits.length - 11);
    }
    return digits;
  }
}

/// 认证结果。
class AuthResult {
  final bool isSuccess;
  final String? verificationId;
  final String? phone;
  final int? userId;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    this.verificationId,
    this.phone,
    this.userId,
    this.errorMessage,
  });

  factory AuthResult.success({
    String? verificationId,
    String? phone,
    int? userId,
  }) {
    return AuthResult._(
      isSuccess: true,
      verificationId: verificationId,
      phone: phone,
      userId: userId,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
