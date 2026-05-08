import '../cloudbase_client.dart';
import '../models/cloud_user.dart';

/// 云端用户仓库。
class CloudUserRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 获取当前用户信息。
  Future<CloudUser?> getCurrentUser(int userId) async {
    final resp = await _client.get('/users/me', queryParams: {
      'userId': userId.toString(),
    });
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudUser.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 更新昵称。
  Future<bool> updateNickName(int userId, String nickName) async {
    final resp = await _client.patch('/users/$userId', body: {
      'nick_name': nickName,
    });
    return resp.isSuccess;
  }

  /// 删除当前账号（同时清理该用户关联的客户/会话）。
  Future<CloudBaseResponse> deleteMyAccount(int userId) async {
    return _client
        .delete('/users/me?userId=$userId')
        .timeout(const Duration(seconds: 20), onTimeout: () {
      return CloudBaseResponse.error('请求超时，请检查网络后重试');
    });
  }
}
