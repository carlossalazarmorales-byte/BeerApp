import 'achievement_category.dart';

/// One achievement, mirroring the backend's `AchievementOut` field-for-field.
/// [progressCurrent]/[progressTarget] are null only for an achievement type
/// with no meaningful bar at all -- the Phase 10 starter catalog always sets
/// both (see backend `AchievementsService`'s permanence display rule: once
/// [unlocked], progress always shows as complete and never regresses even if
/// the underlying live state later changes).
class Achievement {
  const Achievement({
    required this.key,
    required this.category,
    required this.unlocked,
    required this.unlockedAt,
    required this.progressCurrent,
    required this.progressTarget,
  });

  final String key;
  final AchievementCategory category;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int? progressCurrent;
  final int? progressTarget;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    key: json['key'] as String,
    category: AchievementCategory.fromApiValue(json['category'] as String),
    unlocked: json['unlocked'] as bool,
    unlockedAt: json['unlocked_at'] == null
        ? null
        : DateTime.parse(json['unlocked_at'] as String),
    progressCurrent: json['progress_current'] as int?,
    progressTarget: json['progress_target'] as int?,
  );
}
