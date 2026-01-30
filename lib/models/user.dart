// ユーザーモデル
class AppUser {
  final String userId;
  final String displayName;
  final DateTime createdAt;
  final List<String> blockedUserIds;

  AppUser({
    required this.userId,
    required this.displayName,
    required this.createdAt,
    this.blockedUserIds = const [],
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      blockedUserIds: List<String>.from(map['blockedUserIds'] ?? []),
    );
  }

  AppUser copyWith({
    String? displayName,
    List<String>? blockedUserIds,
  }) {
    return AppUser(
      userId: userId,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'createdAt': createdAt,
      'blockedUserIds': blockedUserIds,
    };
  }
}
