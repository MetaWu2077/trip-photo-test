import '../cloudbase_client.dart';
import '../models/cloud_customer.dart';

/// 云端客户仓库。
class CloudCustomerRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 获取当前摄影师的所有客户列表。
  Future<List<CloudCustomer>> getCustomers(int userId) async {
    final resp = await _client.get('/customers', queryParams: {
      'userId': userId.toString(),
    });
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((e) => CloudCustomer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 创建客户。
  Future<CloudCustomer?> createCustomer({
    required int userId,
    required String name,
    String? phoneLast4,
    String? location,
  }) async {
    final resp = await _client.post('/customers', body: {
      'userId': userId,
      'name': name,
      'phoneLast4': phoneLast4,
      'location': location,
    });
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudCustomer.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 删除客户。
  Future<bool> deleteCustomer(int customerId) async {
    final resp = await _client.delete('/customers/$customerId');
    return resp.isSuccess;
  }
}
