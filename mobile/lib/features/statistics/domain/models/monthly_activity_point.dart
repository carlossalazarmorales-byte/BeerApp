/// One point in the trailing-12-UTC-month, zero-filled activity window --
/// always exactly 12 of these, even for a brand-new user with zero logs.
class MonthlyActivityPoint {
  const MonthlyActivityPoint({required this.month, required this.logCount});

  /// First day of a UTC calendar month, e.g. 2026-09-01. Only `.year`/
  /// `.month` are ever read from this -- parsed via `DateTime.parse` on a
  /// bare date string, which yields local midnight, not UTC midnight, but
  /// that has no effect on which calendar month/year is reported.
  final DateTime month;
  final int logCount;

  factory MonthlyActivityPoint.fromJson(Map<String, dynamic> json) =>
      MonthlyActivityPoint(
        month: DateTime.parse(json['month'] as String),
        logCount: json['log_count'] as int,
      );
}
