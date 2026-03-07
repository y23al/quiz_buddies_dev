// ユーザープロフィールモデル（ポイント・ティア）
class UserProfile {
  final String userId;
  final String displayName;
  final int totalPoints;
  final int totalQuizzes;
  final int correctCount;
  final String? avatarUrl;

  UserProfile({
    required this.userId,
    required this.displayName,
    this.totalPoints = 0,
    this.totalQuizzes = 0,
    this.correctCount = 0,
    this.avatarUrl,
  });

  // ティア判定
  String get tier {
    if (totalPoints >= 1501) return 'Platinum';
    if (totalPoints >= 1001) return 'Gold';
    if (totalPoints >= 501) return 'Silver';
    return 'Bronze';
  }

  // ティアカラー値
  int get tierColorValue {
    if (totalPoints >= 1501) return 0xFF00BCD4;
    if (totalPoints >= 1001) return 0xFFFFD700;
    if (totalPoints >= 501) return 0xFF9E9E9E;
    return 0xFFCD7F32;
  }

  // 次ティアまでのポイント
  int get pointsToNextTier {
    if (totalPoints >= 1501) return 0;
    if (totalPoints >= 1001) return 1501 - totalPoints;
    if (totalPoints >= 501) return 1001 - totalPoints;
    return 501 - totalPoints;
  }

  // 現ティア内の進捗 (0.0〜1.0)
  double get tierProgress {
    if (totalPoints >= 1501) return 1.0;
    if (totalPoints >= 1001) return (totalPoints - 1001) / 500;
    if (totalPoints >= 501) return (totalPoints - 501) / 500;
    return totalPoints / 501;
  }

  // 後方互換: rankはtierのエイリアス
  String get rank => tier;

  double get correctRate {
    if (totalQuizzes == 0) return 0;
    return correctCount / totalQuizzes;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      totalPoints: map['totalPoints'] as int? ?? 0,
      totalQuizzes: map['totalQuizzes'] as int? ?? 0,
      correctCount: map['correctCount'] as int? ?? 0,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'totalPoints': totalPoints,
      'totalQuizzes': totalQuizzes,
      'correctCount': correctCount,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  UserProfile copyWith({
    String? displayName,
    int? totalPoints,
    int? totalQuizzes,
    int? correctCount,
    String? avatarUrl,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      totalPoints: totalPoints ?? this.totalPoints,
      totalQuizzes: totalQuizzes ?? this.totalQuizzes,
      correctCount: correctCount ?? this.correctCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
