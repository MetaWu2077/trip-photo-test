/// 每日统计模型（来自 /stats/daily API）。
class DailyStats {
  final String date;
  final int shiftCount;
  final int totalPhotos;
  final int activeShiftCount;
  final int sessionCount;
  final int customerCount;

  DailyStats({
    required this.date,
    this.shiftCount = 0,
    this.totalPhotos = 0,
    this.activeShiftCount = 0,
    this.sessionCount = 0,
    this.customerCount = 0,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] as String? ?? '',
      shiftCount: (json['shiftCount'] as num?)?.toInt() ?? 0,
      totalPhotos: (json['totalPhotos'] as num?)?.toInt() ?? 0,
      activeShiftCount: (json['activeShiftCount'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      customerCount: (json['customerCount'] as num?)?.toInt() ?? 0,
    );
  }
}
