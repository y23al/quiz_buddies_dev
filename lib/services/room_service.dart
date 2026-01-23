// ルームサービス
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'auth_service.dart';

// デモデータストレージ
final Map<String, Room> _demoRooms = {};
final Map<String, List<Message>> _demoMessages = {};

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  // ルームを取得
  Room? getRoom(String roomId) {
    return _demoRooms[roomId];
  }

  // ルームに参加
  Future<void> joinRoom(String roomId, String userId) async {
    if (!_demoRooms.containsKey(roomId)) {
      _demoRooms[roomId] = Room(
        roomId: roomId,
        type: _getRoomType(roomId),
        sessionId: roomId.split('_').first,
        memberUserIds: [userId],
        createdAt: DateTime.now(),
      );
    } else {
      final room = _demoRooms[roomId]!;
      if (!room.memberUserIds.contains(userId)) {
        _demoRooms[roomId] = Room(
          roomId: room.roomId,
          type: room.type,
          sessionId: room.sessionId,
          memberUserIds: [...room.memberUserIds, userId],
          createdAt: room.createdAt,
        );
      }
    }

    if (!_demoMessages.containsKey(roomId)) {
      _demoMessages[roomId] = [];
    }
  }

  RoomType _getRoomType(String roomId) {
    if (roomId.contains('correct') && !roomId.contains('incorrect')) {
      return RoomType.correct;
    } else if (roomId.contains('incorrect')) {
      return RoomType.incorrect;
    } else if (roomId.contains('1on1')) {
      return RoomType.oneOnOne;
    } else {
      return RoomType.common;
    }
  }

  // メッセージを取得
  List<Message> getMessages(String roomId) {
    return _demoMessages[roomId] ?? [];
  }

  // メッセージを送信
  Future<void> sendMessage(String roomId, String userId, String text) async {
    final message = Message(
      messageId: const Uuid().v4(),
      roomId: roomId,
      senderUserId: userId,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
    );

    _demoMessages[roomId] ??= [];
    _demoMessages[roomId]!.add(message);
  }

  // AIメッセージを追加
  void addAIMessage(String roomId, Message message) {
    _demoMessages[roomId] ??= [];
    _demoMessages[roomId]!.add(message);
  }

  // 通報
  Future<void> reportMessage(
    String roomId,
    String messageId,
    String reporterUserId,
    String reportedUserId,
    String reason,
  ) async {
    // デモモードでは何もしない
    print('Report: $reason from $reporterUserId about $reportedUserId');
  }
}
