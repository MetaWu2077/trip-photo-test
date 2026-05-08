import '../cloudbase_client.dart';
import '../models/cloud_stats.dart';

/// 统计仓库。
class CloudStatsRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 获取每日统计。
  Future<DailyStats?> getDailyStats(int userId, {String? date}) async {
    final params = <String, String>{'userId': userId.toString()};
    if (date != null) params['date'] = date;
    final resp = await _client.get('/stats/daily', queryParams: params);
    if (!resp.isSuccess || resp.data == null) return null;
    return DailyStats.fromJson(resp.data as Map<String, dynamic>);
  }
}
