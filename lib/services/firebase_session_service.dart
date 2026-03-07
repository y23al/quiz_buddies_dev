// Firebase Realtime Database を使用したセッション共有サービス
import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';
import 'session_service.dart';
import 'wifi_service.dart';

class FirebaseSessionService {
  static final FirebaseSessionService _instance = FirebaseSessionService._internal();
  factory FirebaseSessionService() => _instance;
  FirebaseSessionService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final SessionService _localSessionService = SessionService();
  final WifiService _wifiService = WifiService();
  static const int joinWindowSeconds = 30; // 参加可能時間

  String? _currentWifiKey;
  String? _currentRoomCode;

  // 現在のセッションキーを取得
  String? get currentSessionKey => _currentWifiKey ?? (_currentRoomCode != null ? 'code_$_currentRoomCode' : null);

  // WiFiキーを取得（キャッシュ）
  Future<String?> getWifiKey() async {
    _currentWifiKey ??= await _wifiService.getWifiKey();
    return _currentWifiKey;
  }

  // 6桁のルームコードを生成
  String _generateRoomCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // セッションパスを取得
  String _getSessionPath(String key) {
    return 'active_sessions/$key';
  }

  // 現在アクティブなセッションを取得（WiFi自動検出 or ルームコード）
  // wifiKey: WiFiキー（nullの場合は自動取得を試みる）
  // roomCode: ルームコード（指定された場合はこちらを優先）
  Future<Map<String, dynamic>?> getOrCreateActiveSession({String? roomCode}) async {
    try {
      String sessionKey;

      if (roomCode != null) {
        // ルームコードで参加
        sessionKey = 'code_$roomCode';
        _currentRoomCode = roomCode;
        _currentWifiKey = null;
      } else {
        // WiFiキーを取得
        final wifiKey = await getWifiKey();
        if (wifiKey == null) {
          // WiFi情報が取得できない場合はnullを返す（ルームコード入力が必要）
          return null;
        }
        sessionKey = wifiKey;
        _currentRoomCode = null;
      }

      final sessionPath = _getSessionPath(sessionKey);
      final snapshot = await _db.child(sessionPath).get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        // フェーズをチェック
        final phase = data['phase'] as String?;

        // lobby または joinable なら参加可能
        if (phase == 'lobby' || phase == 'joinable') {
          _currentRoomCode = data['roomCode'] as String?;
          return data;
        }

        // クイズ進行中は参加不可
        return null;
      }

      // 新しいセッションを作成
      return await _createNewSession(sessionKey);
    } catch (e) {
      // エラー時はnullを返す
      return null;
    }
  }

  // 新しいルームを作成（ルームコードを自動生成）
  Future<Map<String, dynamic>?> createNewRoom() async {
    try {
      final roomCode = _generateRoomCode();
      final sessionKey = 'code_$roomCode';
      return await _createNewSession(sessionKey);
    } catch (e) {
      return null;
    }
  }

  // ルーム作成（学年/学期/科目指定）
  Future<Map<String, dynamic>?> createRoomSession({
    required int grade,
    required int term,
    required String subjectId,
    required String subjectName,
  }) async {
    try {
      final roomCode = _generateRoomCode();
      final sessionId = const Uuid().v4();

      final sessionData = {
        'sessionId': sessionId,
        'roomCode': roomCode,
        'grade': grade,
        'term': term,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'createdAt': ServerValue.timestamp,
        'phase': 'lobby',
        'participantCount': 0,
      };

      // Firebaseに保存
      final sessionPath = _getSessionPath('code_$roomCode');
      await _db.child(sessionPath).set(sessionData);

      _currentRoomCode = roomCode;

      // createdAtをローカル時刻で補完
      final now = DateTime.now().millisecondsSinceEpoch;
      sessionData['createdAt'] = now;

      return sessionData;
    } catch (e) {
      return null;
    }
  }

  // ルームコードでセッションに参加
  Future<Map<String, dynamic>?> joinByRoomCode(String roomCode) async {
    try {
      final sessionKey = 'code_$roomCode';
      final sessionPath = _getSessionPath(sessionKey);
      final snapshot = await _db.child(sessionPath).get();

      if (!snapshot.exists) {
        return null; // セッションが存在しない
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      // フェーズをチェック（lobby または joinable なら参加可能）
      final phase = data['phase'] as String?;
      if (phase != 'lobby' && phase != 'joinable') {
        return null; // クイズ開始後は参加不可
      }

      _currentRoomCode = roomCode;
      _currentWifiKey = null;
      return data;
    } catch (e) {
      return null;
    }
  }

  // 新しいセッションを作成
  Future<Map<String, dynamic>> _createNewSession(String sessionKey) async {
    final quiz = await _localSessionService.createSampleQuiz();
    final sessionId = const Uuid().v4();

    // ルームコードを生成（code_で始まる場合はそのコードを使う）
    String roomCode;
    if (sessionKey.startsWith('code_')) {
      roomCode = sessionKey.substring(5); // "code_" を除去
    } else {
      roomCode = _generateRoomCode();
    }

    final sessionData = {
      'sessionId': sessionId,
      'sessionKey': sessionKey,
      'roomCode': roomCode,
      'quizId': quiz.quizId,
      'questionText': quiz.questionText,
      'choices': quiz.choices,
      'correctChoiceIndex': quiz.correctChoiceIndex,
      'explanation': quiz.explanation,
      'difficulty': quiz.difficulty,
      'createdAt': ServerValue.timestamp,
      'phase': 'lobby', // ロビー待機中
      'participantCount': 0,
    };

    // Firebaseに保存（ルームコードのパスにも保存）
    final sessionPath = _getSessionPath(sessionKey);
    await _db.child(sessionPath).set(sessionData);

    // ルームコードでもアクセスできるようにする
    if (!sessionKey.startsWith('code_')) {
      final codePath = _getSessionPath('code_$roomCode');
      await _db.child(codePath).set(sessionData);
    }

    // createdAtをローカル時刻で補完（表示用）
    final now = DateTime.now().millisecondsSinceEpoch;
    sessionData['createdAt'] = now;

    _currentRoomCode = roomCode;

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
    final sessionKey = currentSessionKey;
    if (sessionKey != null) {
      final sessionPath = _getSessionPath(sessionKey);
      await _db.child(sessionPath).child('participantCount').set(ServerValue.increment(1));
    }
  }

  // セッション情報をリアルタイムで監視（WiFiキーまたはルームコードベース）
  Stream<Map<String, dynamic>?> watchActiveSession({String? roomCode}) {
    return Stream.fromFuture(_getWatchPath(roomCode: roomCode)).asyncExpand((path) {
      if (path == null) {
        return Stream.value(null);
      }
      return _db.child(path).onValue.map((event) {
        if (!event.snapshot.exists) return null;
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      });
    });
  }

  Future<String?> _getWatchPath({String? roomCode}) async {
    if (roomCode != null) {
      return _getSessionPath('code_$roomCode');
    }
    final wifiKey = await getWifiKey();
    if (wifiKey == null) return null;
    return _getSessionPath(wifiKey);
  }

  // 現在のセッションを監視
  Stream<Map<String, dynamic>?> watchCurrentSession() {
    final key = currentSessionKey;
    if (key == null) {
      return Stream.value(null);
    }
    return _db.child(_getSessionPath(key)).onValue.map((event) {
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
  Future<void> updatePhase(String sessionId, String phase, {String? roomCode}) async {
    // roomCodeが渡された場合はそれを使う（singleton状態に依存しない）
    final key = roomCode != null ? 'code_$roomCode' : currentSessionKey;
    if (key != null) {
      final sessionPath = _getSessionPath(key);
      await _db.child(sessionPath).child('phase').set(phase);
    }
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

  // クイズ完了をマーク
  Future<void> markQuizCompleted(String sessionId, String userId, int correctCount, int totalQuestions) async {
    await _db.child('sessions').child(sessionId).child('participants').child(userId).update({
      'quizCompleted': true,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'completedAt': ServerValue.timestamp,
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
    final sessionKey = currentSessionKey;
    if (sessionKey != null) {
      final sessionPath = _getSessionPath(sessionKey);
      await _db.child(sessionPath).remove();
    }
    _currentWifiKey = null;
    _currentRoomCode = null;
  }

  // WiFi情報が利用可能かどうか
  Future<bool> isWifiAvailable() async {
    return await _wifiService.isWifiAvailable();
  }

  // WiFi名を取得（表示用）
  Future<String?> getWifiName() async {
    return await _wifiService.getWifiName();
  }

  // ユーザープロフィールを取得
  Future<UserProfile?> getUserProfile(String userId) async {
    final snapshot = await _db.child('user_profiles').child(userId).get();
    if (!snapshot.exists) return null;
    return UserProfile.fromMap(Map<String, dynamic>.from(snapshot.value as Map));
  }

  // ユーザープロフィールを更新
  Future<void> updateUserProfile(UserProfile profile) async {
    await _db.child('user_profiles').child(profile.userId).set(profile.toMap());
  }

  // ポイントを加算
  Future<void> addPoints(String userId, String displayName, int points, int correctCount, int totalQuestions) async {
    final existing = await getUserProfile(userId);
    final profile = existing ?? UserProfile(userId: userId, displayName: displayName);
    final updated = profile.copyWith(
      totalPoints: profile.totalPoints + points,
      totalQuizzes: profile.totalQuizzes + totalQuestions,
      correctCount: profile.correctCount + correctCount,
    );
    await updateUserProfile(updated);
  }

  // 全ユーザープロフィールを取得（ランキング用、totalPoints降順）
  Future<List<UserProfile>> getAllUserProfiles() async {
    final snapshot = await _db.child('user_profiles').get();
    if (!snapshot.exists) return [];
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final profiles = data.entries
        .map((e) => UserProfile.fromMap(Map<String, dynamic>.from(e.value as Map)))
        .toList();
    profiles.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    return profiles;
  }

  // 全ユーザープロフィールをリアルタイム監視
  Stream<List<UserProfile>> watchAllUserProfiles() {
    return _db.child('user_profiles').onValue.map((event) {
      if (!event.snapshot.exists) return <UserProfile>[];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final profiles = data.entries
          .map((e) => UserProfile.fromMap(Map<String, dynamic>.from(e.value as Map)))
          .toList();
      profiles.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
      return profiles;
    });
  }

  // ルーレット状態を更新
  Future<void> updateRouletteState(String sessionId, String userId, int currentDisplay, bool isDone) async {
    await _db
        .child('sessions')
        .child(sessionId)
        .child('participants')
        .child(userId)
        .update({
      'rouletteDisplay': currentDisplay,
      'rouletteDone': isDone,
    });
  }
}
