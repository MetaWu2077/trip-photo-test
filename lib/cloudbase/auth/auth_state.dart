import 'package:shared_preferences/shared_preferences.dart';
import '../cloudbase_client.dart';

/// 登录状态持久化管理。
class AuthState {
  static const String _keyAccessToken = 'cloud_access_token';
  static const String _keyRefreshToken = 'cloud_refresh_token';
  static const String _keyPhone = 'cloud_user_phone';
  static const String _keyUserId = 'cloud_user_id';

  /// 从本地存储恢复登录状态。
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_keyAccessToken);
    if (accessToken != null) {
      CloudBaseClient.instance.accessToken = accessToken;
    }
    final userId = prefs.getInt(_keyUserId);
    if (userId != null) {
      CloudBaseClient.instance.currentUserId = userId;
    }
  }

  /// 保存登录状态。
  static Future<void> save({
    required String accessToken,
    String? refreshToken,
    String? phone,
    int? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    CloudBaseClient.instance.accessToken = accessToken;
    if (refreshToken != null) {
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
    if (phone != null) {
      await prefs.setString(_keyPhone, phone);
    }
    if (userId != null) {
      await prefs.setInt(_keyUserId, userId);
      CloudBaseClient.instance.currentUserId = userId;
    }
  }

  /// 保存 Refresh Token（单独刷新后更新）
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    CloudBaseClient.instance.accessToken = accessToken;
    if (refreshToken != null) {
      await prefs.setString(_keyRefreshToken, refreshToken);
    }
  }

  /// 清除登录状态。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyUserId);
    CloudBaseClient.instance.accessToken = null;
    CloudBaseClient.instance.currentUserId = null;
  }

  /// 是否已登录。
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_keyAccessToken);
    final userId = prefs.getInt(_keyUserId);
    return accessToken != null && accessToken.isNotEmpty && userId != null && userId > 0;
  }

  /// 启动时向服务端校验当前用户是否仍存在。
  /// - 用户存在：返回 true
  /// - 用户不存在/鉴权失效：清理本地登录态并返回 false
  static Future<bool> validateSessionWithServer() async {
    final localLoggedIn = await isLoggedIn();
    if (!localLoggedIn) return false;

    final userId = CloudBaseClient.instance.currentUserId;
    if (userId == null || userId <= 0) {
      await clear();
      return false;
    }

    final resp = await CloudBaseClient.instance.get(
      '/users/me',
      queryParams: {'userId': userId.toString()},
    );

    // 用户已删除：接口通常返回 200 + null（当前 trip-api 逻辑）
    if (resp.statusCode == 200 && resp.data == null) {
      await clear();
      return false;
    }

    // 鉴权失效或参数错误等：一并回到登录页
    if (resp.statusCode == 401 ||
        resp.statusCode == 403 ||
        resp.statusCode == 404 ||
        resp.statusCode == 400) {
      await clear();
      return false;
    }

    // 启动必须确认服务端账号存在；网络异常也回登录页，避免“删库后仍直进”。
    if (resp.statusCode == -1) {
      await clear();
      return false;
    }

    if (!(resp.isSuccess && resp.data != null)) {
      await clear();
      return false;
    }
    return true;
  }

  /// 获取 Refresh Token。
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  /// 获取手机号。
  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    CloudBaseClient.instance.currentUserId = userId;
  }
}
