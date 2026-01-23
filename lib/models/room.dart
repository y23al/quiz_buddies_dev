// ルームモデル

enum RoomType { correct, incorrect, oneOnOne, common }

class Room {
  final String roomId;
  final RoomType type;
  final String sessionId;
  final List<String> memberUserIds;
  final DateTime createdAt;
  final bool isActive;

  Room({
    required this.roomId,
    required this.type,
    required this.sessionId,
    required this.memberUserIds,
    required this.createdAt,
    this.isActive = true,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      roomId: map['roomId'] ?? '',
      type: RoomType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RoomType.common,
      ),
      sessionId: map['sessionId'] ?? '',
      memberUserIds: List<String>.from(map['memberUserIds'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }
}
