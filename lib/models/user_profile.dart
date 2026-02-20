// ユーザープロフィールモデル（ポイント・ランク）
class UserProfile {
  final String userId;
  final String displayName;
  final int totalPoints;
  final int totalQuizzes;
  final int correctCount;

  UserProfile({
    required this.userId,
    required this.displayName,
    this.totalPoints = 0,
    this.totalQuizzes = 0,
    this.correctCount = 0,
  });

  String get rank {
    if (totalPoints >= 1000) return 'S';
    if (totalPoints >= 500) return 'A';
    if (totalPoints >= 200) return 'B';
    if (totalPoints >= 50) return 'C';
    return 'D';
  }

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'totalPoints': totalPoints,
      'totalQuizzes': totalQuizzes,
      'correctCount': correctCount,
    };
  }

  UserProfile copyWith({
    String? displayName,
    int? totalPoints,
    int? totalQuizzes,
    int? correctCount,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      totalPoints: totalPoints ?? this.totalPoints,
      totalQuizzes: totalQuizzes ?? this.totalQuizzes,
      correctCount: correctCount ?? this.correctCount,
    );
  }
}
