import '../cloudbase_client.dart';
import '../models/cloud_photo.dart';

/// 云端照片元数据仓库。
class CloudPhotoRepository {
  final CloudBaseClient _client = CloudBaseClient.instance;

  /// 按 sessionId 获取照片列表。
  Future<List<CloudPhoto>> getPhotosBySession(int sessionId) async {
    final resp = await _client.get('/photos', queryParams: {
      'sessionId': sessionId.toString(),
    });
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((e) => CloudPhoto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 按 userId 获取照片列表。
  Future<List<CloudPhoto>> getPhotosByUser(int userId) async {
    final resp = await _client.get('/photos', queryParams: {
      'userId': userId.toString(),
    });
    if (!resp.isSuccess) return [];
    final list = resp.data as List<dynamic>? ?? [];
    return list.map((e) => CloudPhoto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 上传照片元数据（COS 已直传，这里只记 DB）。
  Future<CloudPhoto?> createPhoto({
    required int userId,
    required int sessionId,
    required String thumbKey,
    String? originalKey,
    int fileSize = 0,
  }) async {
    final resp = await _client.post('/photos', body: {
      'userId': userId,
      'sessionId': sessionId,
      'thumbKey': thumbKey,
      'originalKey': originalKey ?? '',
      'fileSize': fileSize,
    });
    if (!resp.isSuccess || resp.data == null) return null;
    return CloudPhoto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// 删除照片元数据。
  Future<bool> deletePhoto(int photoId) async {
    final resp = await _client.delete('/photos/$photoId');
    return resp.isSuccess;
  }
}
