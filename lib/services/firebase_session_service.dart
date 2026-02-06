// Firebase Realtime Database を使用したセッション共有サービス
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'session_service.dart';

class FirebaseSessionService {
  static final FirebaseSessionService _instance = FirebaseSessionService._internal();
  factory FirebaseSessionService() => _instance;
  FirebaseSessionService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final SessionService _localSessionService = SessionService();
  static const int joinWindowSeconds = 30; // 参加可能時間

  // 現在アクティブなセッションを取得（または新規作成）
  Future<Map<String, dynamic>?> getOrCreateActiveSession() async {
    try {
      // アクティブなセッションを探す
      final snapshot = await _db.child('active_session').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final createdAt = data['createdAt'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = (now - createdAt) / 1000;

        // まだ参加可能時間内なら、このセッションを返す
        if (elapsed < joinWindowSeconds) {
          return data;
        }

        // 参加時間が過ぎていて、まだクイズフェーズなら参加させない
        final phase = data['phase'] as String?;
        if (phase != 'joinable') {
          return null; // 既存セッションは進行中なので参加不可
        }
      }

      // 新しいセッションを作成
      return await _createNewSession();
    } catch (e) {
      // エラー時はローカルで作成
      return await _createNewSession();
    }
  }

  // 新しいセッションを作成
  Future<Map<String, dynamic>> _createNewSession() async {
    final quiz = await _localSessionService.createSampleQuiz();
    final sessionId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final sessionData = {
      'sessionId': sessionId,
      'quizId': quiz.quizId,
      'questionText': quiz.questionText,
      'choices': quiz.choices,
      'correctChoiceIndex': quiz.correctChoiceIndex,
      'explanation': quiz.explanation,
      'difficulty': quiz.difficulty,
      'createdAt': now,
      'phase': 'joinable',
      'participantCount': 0,
    };

    // Firebaseに保存
    await _db.child('active_session').set(sessionData);

    return sessionData;
  }

  // セッションに参加
  Future<void> joinSession(String sessionId, String odId, String displayName) async {
    final participantRef = _db.child('sessions').child(sessionId).child('participants').child(odId);
    await participantRef.set({
      'odId': odId,
      'displayName': displayName,
      'joinedAt': ServerValue.timestamp,
      'answered': false,
    });

    // 参加者数をインクリメント
    await _db.child('active_session').child('participantCount').set(ServerValue.increment(1));
  }

  // セッション情報をリアルタイムで監視
  Stream<Map<String, dynamic>?> watchActiveSession() {
    return _db.child('active_session').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }

  // 参加者数を監視
  Stream<int> watchParticipantCount(String sessionId) {
    return _db
        .child('sessions')
        .child(sessionId)
        .child('participants')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;
      final data = event.snapshot.value as Map?;
      return data?.length ?? 0;
    });
  }

  // セッションフェーズを更新
  Future<void> updatePhase(String sessionId, String phase) async {
    await _db.child('active_session').child('phase').set(phase);
  }

  // 回答を送信
  Future<void> submitAnswer(String sessionId, String userId, int answerIndex, bool isCorrect) async {
    await _db.child('sessions').child(sessionId).child('participants').child(userId).update({
      'answered': true,
      'answerIndex': answerIndex,
      'isCorrect': isCorrect,
      'answeredAt': ServerValue.timestamp,
    });
  }

  // 参加者の回答状態を監視
  Stream<List<Map<String, dynamic>>> watchParticipants(String sessionId) {
    return _db
        .child('sessions')
        .child(sessionId)
        .child('participants')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <Map<String, dynamic>>[];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
    });
  }

  // マッチング相手を探す（正解者と不正解者をペアリング）
  Future<Map<String, dynamic>?> findMatch(String sessionId, String odId, bool isCorrect) async {
    final snapshot = await _db
        .child('sessions')
        .child(sessionId)
        .child('participants')
        .get();

    if (!snapshot.exists) return null;

    final participants = Map<String, dynamic>.from(snapshot.value as Map);

    // 相手を探す（自分と逆の結果の人）
    for (final entry in participants.entries) {
      if (entry.key == odId) continue;
      final p = Map<String, dynamic>.from(entry.value as Map);
      if (p['answered'] != true) continue;
      if (p['isCorrect'] == isCorrect) continue; // 同じ結果の人はスキップ
      if (p['matchedWith'] != null) continue; // 既にマッチング済み

      // マッチング成功
      final roomId = '${sessionId}_1on1_${const Uuid().v4().substring(0, 8)}';

      // 両者のマッチング情報を更新
      await _db.child('sessions').child(sessionId).child('participants').child(odId).update({
        'matchedWith': entry.key,
        'oneOnOneRoomId': roomId,
      });
      await _db.child('sessions').child(sessionId).child('participants').child(entry.key).update({
        'matchedWith': odId,
        'oneOnOneRoomId': roomId,
      });

      return {
        'partnerId': entry.key,
        'partnerName': p['displayName'],
        'roomId': roomId,
        'isAI': false,
      };
    }

    // マッチング相手がいない場合はnull（1対1はAIなしなので待機）
    return null;
  }

  // セッションをクリア（新しいゲーム開始時）
  Future<void> clearSession() async {
    await _db.child('active_session').remove();
  }
}
