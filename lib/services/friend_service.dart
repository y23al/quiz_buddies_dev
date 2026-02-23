// フレンドサービス（Firebase RTDB）
import 'package:firebase_database/firebase_database.dart';

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// 2人のユーザーIDからフレンドチャット用ルームIDを生成（決定的）
  static String friendRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'friend_${sorted[0]}_${sorted[1]}';
  }

  /// フレンド申請を送信
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    required String fromDisplayName,
    required String toDisplayName,
    required String sessionId,
  }) async {
    // 既にフレンドなら何もしない
    if (await areFriends(fromUserId, toUserId)) return;
    // 既にpendingの申請があれば何もしない
    if (await hasExistingRequest(fromUserId, toUserId)) return;

    await _db.child('friend_requests').push().set({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'fromDisplayName': fromDisplayName,
      'toDisplayName': toDisplayName,
      'sessionId': sessionId,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
    });
  }

  /// pending状態のリクエストが存在するか（どちらの方向でも）
  Future<bool> hasExistingRequest(String uid1, String uid2) async {
    final snapshot = await _db
        .child('friend_requests')
        .orderByChild('fromUserId')
        .equalTo(uid1)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in data.values) {
        final req = Map<String, dynamic>.from(entry as Map);
        if (req['toUserId'] == uid2 && req['status'] == 'pending') return true;
      }
    }

    // 逆方向もチェック
    final snapshot2 = await _db
        .child('friend_requests')
        .orderByChild('fromUserId')
        .equalTo(uid2)
        .get();

    if (snapshot2.exists) {
      final data = Map<String, dynamic>.from(snapshot2.value as Map);
      for (final entry in data.values) {
        final req = Map<String, dynamic>.from(entry as Map);
        if (req['toUserId'] == uid1 && req['status'] == 'pending') return true;
      }
    }

    return false;
  }

  /// 2人が既にフレンドかどうか
  Future<bool> areFriends(String uid1, String uid2) async {
    final snapshot =
        await _db.child('friends').child(uid1).child(uid2).get();
    return snapshot.exists;
  }

  /// 自分宛の受信フレンド申請を監視（pending のみ）
  Stream<List<Map<String, dynamic>>> watchIncomingRequests(String userId) {
    return _db
        .child('friend_requests')
        .orderByChild('toUserId')
        .equalTo(userId)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final requests = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        final req = Map<String, dynamic>.from(value as Map);
        if (req['status'] == 'pending') {
          req['requestId'] = key;
          requests.add(req);
        }
      });
      // 新しい順
      requests.sort((a, b) =>
          (b['createdAt'] as int? ?? 0).compareTo(a['createdAt'] as int? ?? 0));
      return requests;
    });
  }

  /// フレンド申請を承認
  Future<void> acceptRequest(String requestId) async {
    final snapshot = await _db.child('friend_requests').child(requestId).get();
    if (!snapshot.exists) return;

    final req = Map<String, dynamic>.from(snapshot.value as Map);
    final fromUserId = req['fromUserId'] as String;
    final toUserId = req['toUserId'] as String;
    final fromDisplayName = req['fromDisplayName'] as String;
    final toDisplayName = req['toDisplayName'] as String;

    // ステータス更新 + 双方向フレンド登録を一括書き込み
    final updates = <String, dynamic>{
      'friend_requests/$requestId/status': 'accepted',
      'friends/$fromUserId/$toUserId': {
        'displayName': toDisplayName,
        'friendSince': ServerValue.timestamp,
      },
      'friends/$toUserId/$fromUserId': {
        'displayName': fromDisplayName,
        'friendSince': ServerValue.timestamp,
      },
    };
    await _db.update(updates);
  }

  /// フレンド申請を拒否
  Future<void> rejectRequest(String requestId) async {
    await _db
        .child('friend_requests')
        .child(requestId)
        .child('status')
        .set('rejected');
  }

  /// フレンド一覧を監視
  Stream<List<Map<String, dynamic>>> watchFriends(String userId) {
    return _db.child('friends').child(userId).onValue.map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) {
        final friend = Map<String, dynamic>.from(e.value as Map);
        friend['userId'] = e.key;
        return friend;
      }).toList();
    });
  }
}
