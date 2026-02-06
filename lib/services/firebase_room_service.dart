// Firebase Realtime Database を使用したルームサービス
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/models.dart';

class FirebaseRoomService {
  static final FirebaseRoomService _instance = FirebaseRoomService._internal();
  factory FirebaseRoomService() => _instance;
  FirebaseRoomService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // メッセージをリアルタイムで監視
  Stream<List<Message>> watchMessages(String roomId) {
    return _db
        .child('rooms')
        .child(roomId)
        .child('messages')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Message>[];

      final messages = data.entries.map((entry) {
        final msgData = Map<String, dynamic>.from(entry.value as Map);
        return Message(
          messageId: entry.key.toString(),
          roomId: roomId,
          senderUserId: msgData['senderUserId'] ?? '',
          type: MessageType.text,
          text: msgData['text'] ?? '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(msgData['createdAt'] ?? 0),
        );
      }).toList();

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    });
  }

  // メッセージを送信
  Future<void> sendMessage(String roomId, String userId, String text, {String? displayName}) async {
    final messageRef = _db.child('rooms').child(roomId).child('messages').push();
    await messageRef.set({
      'senderUserId': userId,
      'text': text,
      'displayName': displayName ?? '',
      'createdAt': ServerValue.timestamp,
    });
  }

  // ルームに参加（プレゼンス登録）
  Future<void> joinRoom(String roomId, String userId, String displayName) async {
    final memberRef = _db.child('rooms').child(roomId).child('members').child(userId);
    await memberRef.set({
      'displayName': displayName,
      'joinedAt': ServerValue.timestamp,
      'online': true,
    });

    // 切断時に自動でオフラインにする
    memberRef.child('online').onDisconnect().set(false);
  }

  // ルームを退出
  Future<void> leaveRoom(String roomId, String userId) async {
    await _db.child('rooms').child(roomId).child('members').child(userId).child('online').set(false);
  }

  // ルームメンバーを監視
  Stream<List<Map<String, dynamic>>> watchMembers(String roomId) {
    return _db
        .child('rooms')
        .child(roomId)
        .child('members')
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Map<String, dynamic>>[];

      return data.entries
          .where((e) => (e.value as Map)['online'] == true)
          .map((e) => {
                'userId': e.key,
                'displayName': (e.value as Map)['displayName'] ?? '',
              })
          .toList();
    });
  }

  // 表示名を取得
  Future<String?> getDisplayName(String roomId, String userId) async {
    final snapshot = await _db
        .child('rooms')
        .child(roomId)
        .child('members')
        .child(userId)
        .child('displayName')
        .get();
    return snapshot.value as String?;
  }

  // セッション情報を保存
  Future<void> saveSession(String sessionId, Map<String, dynamic> sessionData) async {
    await _db.child('sessions').child(sessionId).set(sessionData);
  }

  // セッション情報を取得
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final snapshot = await _db.child('sessions').child(sessionId).get();
    if (snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  // クイズ情報を保存
  Future<void> saveQuiz(String quizId, Map<String, dynamic> quizData) async {
    await _db.child('quizzes').child(quizId).set(quizData);
  }

  // クイズ情報を取得
  Future<Map<String, dynamic>?> getQuiz(String quizId) async {
    final snapshot = await _db.child('quizzes').child(quizId).get();
    if (snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }
}
