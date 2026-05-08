import '../cloudbase_client.dart';

/// 手机号认证（简化版，对接 trip-api /auth/* 端点）。
///
/// 简化流程说明（真实项目请替换为正式的 CloudBase SMS 认证）：
/// - sendCode: 调用 /auth/send-code（模拟发送验证码）
/// - verifyCode: 调用 /auth/verify（验证并登录，返回 userId）
///
/// 真实短信验证需在 CloudBase 控制台配置短信模板，
/// Flutter 端目前通过简化流程（跳过真实短信）进行测试。
class PhoneAuth {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 发送验证码（模拟）。
  /// 真实项目：接入 CloudBase SMS 模板后替换此实现。
  Future<AuthResult> sendCode(String phoneNumber) async {
    final resp = await _client.post('/auth/send-code', body: {
      'phone_number': phoneNumber,
      'target': 'ANY',
    });

    if (!resp.isSuccess) {
      return AuthResult.failure(resp.errorMessage ?? '发送验证码失败');
    }

    return AuthResult.success(
      message: (resp.data is Map) ? resp.data['message'] as String? : '验证码已发送',
    );
  }

  /// 验证验证码并登录。
  /// [phoneNumber] 国际格式，如 "+86 13800138000"
  /// [code] 用户输入的 6 位验证码（简化版：任意 6 位数字均可通过）
  Future<AuthResult> verifyCode(String phoneNumber, String code) async {
    final resp = await _client.post('/auth/verify', body: {
      'phone': phoneNumber,
      'code': code,
    });

    if (!resp.isSuccess) {
      return AuthResult.failure(resp.errorMessage ?? '验证失败');
    }

    final data = resp.data is Map ? resp.data as Map<String, dynamic> : {};
    final user = data['user'] as Map<String, dynamic>?;

    if (user != null) {
      final userId = user['id'] as int;
      _client.currentUserId = userId;
      return AuthResult.success(
        userId: userId,
        phone: user['phone'] as String?,
      );
    }

    return AuthResult.success();
  }

  /// 完整流程（简化版）。
  /// 发送验证码后直接用固定验证码 "123456" 完成验证。
  /// 真实项目：拆分为 sendCode -> 用户输入code -> verifyCode 两步。
  Future<AuthResult> signInWithPhone(String phoneNumber) async {
    // 简化：直接验证，code "123456" 是测试验证码
    return verifyCode(phoneNumber, '123456');
  }

  /// 登出。
  void signOut() {
    _client.currentUserId = null;
  }
}

/// 认证结果。
class AuthResult {
  final bool isSuccess;
  final int? userId;
  final String? phone;
  final String? verificationId;
  final String? message;
  final String? errorMessage;

  AuthResult._({
    required this.isSuccess,
    this.userId,
    this.phone,
    this.verificationId,
    this.message,
    this.errorMessage,
  });

  factory AuthResult.success({
    int? userId,
    String? phone,
    String? verificationId,
    String? message,
  }) {
    return AuthResult._(
      isSuccess: true,
      userId: userId,
      phone: phone,
      verificationId: verificationId,
      message: message,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}
