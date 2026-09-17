/// One UTC calendar year with >=1 log. All-time, NOT zero-filled --
/// deliberately a different shape from [MonthlyActivityPoint]'s rolling
/// zero-filled window (see docs/DECISIONS.md).
class YearlyActivityPoint {
  const YearlyActivityPoint({required this.year, required this.logCount});

  final int year;
  final int logCount;

  factory YearlyActivityPoint.fromJson(Map<String, dynamic> json) =>
      YearlyActivityPoint(
        year: json['year'] as int,
        logCount: json['log_count'] as int,
      );
}
