// ユーザーモデル
class AppUser {
  final String userId;
  final String displayName;
  final String? email;
  final bool emailVerified;
  final bool isGuest;
  final DateTime createdAt;
  final List<String> blockedUserIds;

  AppUser({
    required this.userId,
    required this.displayName,
    this.email,
    this.emailVerified = false,
    this.isGuest = true,
    required this.createdAt,
    this.blockedUserIds = const [],
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'],
      emailVerified: map['emailVerified'] ?? false,
      isGuest: map['isGuest'] ?? true,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      blockedUserIds: List<String>.from(map['blockedUserIds'] ?? []),
    );
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    bool? emailVerified,
    bool? isGuest,
    List<String>? blockedUserIds,
  }) {
    return AppUser(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'emailVerified': emailVerified,
      'isGuest': isGuest,
      'createdAt': createdAt,
      'blockedUserIds': blockedUserIds,
    };
  }
}
