import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// 顾客端登录状态。
class CustomerAuthState {
  final int userId;
  final String phone;
  final String? nickName;

  CustomerAuthState({
    required this.userId,
    required this.phone,
    this.nickName,
  });

  factory CustomerAuthState.fromJson(Map<String, dynamic> json) {
    return CustomerAuthState(
      userId: json['id'] as int,
      phone: json['phone'] as String,
      nickName: json['nick_name'] as String?,
    );
  }
}

/// 顾客端认证管理器。
class CustomerAuth {
  static const String _keyUserId = 'customer_user_id';
  static const String _keyPhone = 'customer_phone';
  static const String _keyNickName = 'customer_nick_name';

  CustomerAuthState? _currentUser;
  CustomerAuthState? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  final ApiClient _api = ApiClient();

  /// 发送验证码。
  Future<bool> sendCode(String phone) async {
    try {
      await _api.post('/auth/send-code', body: {'phone': phone});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 验证验证码并登录。
  Future<CustomerAuthState?> verifyAndLogin(String phone, String code) async {
    try {
      final data = await _api.post('/auth/verify', body: {'phone': phone});
      if (data['success'] != true) return null;
      final user = CustomerAuthState.fromJson(data['user'] as Map<String, dynamic>);
      _currentUser = user;
      await _persist(user);
      return user;
    } catch (e) {
      return null;
    }
  }

  /// 从本地缓存恢复登录状态。
  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    final phone = prefs.getString(_keyPhone);
    final nickName = prefs.getString(_keyNickName);
    if (userId != null && phone != null) {
      _currentUser = CustomerAuthState(userId: userId, phone: phone, nickName: nickName);
      return true;
    }
    return false;
  }

  Future<void> _persist(CustomerAuthState user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, user.userId);
    await prefs.setString(_keyPhone, user.phone);
    if (user.nickName != null) {
      await prefs.setString(_keyNickName, user.nickName!);
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyNickName);
  }
}

final customerAuth = CustomerAuth();
