/// 年度报告可访问时间配置
class AnnualReportConfig {
  AnnualReportConfig._();

  /// 活动开始时间：2026-01-20 00:00:00（本地时间）
  static final DateTime startTime = DateTime(2026, 1, 20, 0, 0, 0);

  /// 活动结束时间：2026-02-27 23:59:59（本地时间）
  static final DateTime endTime = DateTime(2026, 2, 27, 23, 59, 59);

  /// 当前是否在年度报告可访问时间内
  static bool get isWithinAccessPeriod {
    final now = DateTime.now();
    return !now.isBefore(startTime) && !now.isAfter(endTime);
  }
}
