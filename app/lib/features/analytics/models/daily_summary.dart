class DailySummary {
  final String targetDate;
  final int totalNapMinutes;
  final int totalFeeds;
  final int totalDirtyDiapers;

  DailySummary({
    required this.targetDate,
    required this.totalNapMinutes,
    required this.totalFeeds,
    required this.totalDirtyDiapers,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      targetDate: json['target_date'],
      totalNapMinutes: json['total_nap_minutes'],
      totalFeeds: json['total_feeds'],
      totalDirtyDiapers: json['total_dirty_diapers'],
    );
  }
}