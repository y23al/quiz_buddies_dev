// セッションサービス
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'ai_service.dart';

// デモデータストレージ
final Map<String, Session> _demoSessions = {};
final Map<String, Quiz> _demoQuizzes = {};
final Map<String, Participation> _demoParticipations = {};

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // 現在のセッションを取得
  Future<Session?> getCurrentSession() async {
    if (isDemoMode) {
      for (final session in _demoSessions.values) {
        if ([
          SessionPhase.joinable,
          SessionPhase.quiz,
          SessionPhase.splitRoom,
          SessionPhase.matching,
          SessionPhase.oneOnOne,
          SessionPhase.common,
        ].contains(session.phase)) {
          return session;
        }
      }
      return null;
    }
    // TODO: Firestore実装
    return null;
  }

  // セッションを取得
  Session? getSession(String sessionId) {
    return _demoSessions[sessionId];
  }

  // クイズを取得
  Quiz? getQuiz(String quizId) {
    return _demoQuizzes[quizId];
  }

  // セッションに参加
  Future<Participation> joinSession(String sessionId, String userId) async {
    final participationId = '${sessionId}_$userId';

    if (_demoParticipations.containsKey(participationId)) {
      return _demoParticipations[participationId]!;
    }

    final participation = Participation(
      sessionId: sessionId,
      userId: userId,
      joinedAt: DateTime.now(),
    );
    _demoParticipations[participationId] = participation;
    return participation;
  }

  // 参加情報を取得
  Participation? getParticipation(String sessionId, String userId) {
    return _demoParticipations['${sessionId}_$userId'];
  }

  // 回答を送信
  Future<AnswerResult> submitAnswer(
    String sessionId,
    String userId,
    int answerIndex,
  ) async {
    final participationId = '${sessionId}_$userId';
    final session = _demoSessions[sessionId];
    if (session == null) throw Exception('Session not found');

    final quiz = _demoQuizzes[session.quizId];
    if (quiz == null) throw Exception('Quiz not found');

    final isCorrect = answerIndex == quiz.correctChoiceIndex;
    final result = isCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    final splitRoomAssigned = isCorrect ? 'correct' : 'incorrect';

    final participation = _demoParticipations[participationId];
    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        answer: answerIndex,
        answeredAt: DateTime.now(),
        result: result,
        splitRoomAssigned: splitRoomAssigned,
      );
    }

    return result;
  }

  // タイムアウト処理
  Future<void> handleTimeout(String sessionId, String userId) async {
    final participationId = '${sessionId}_$userId';
    final participation = _demoParticipations[participationId];
    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        result: AnswerResult.timeout,
        splitRoomAssigned: 'incorrect',
      );
    }
  }

  // サンプルクイズを作成
  Future<Quiz> createSampleQuiz() async {
    final quiz = Quiz(
      quizId: const Uuid().v4(),
      questionText: '日本で一番高い山は？',
      choices: ['富士山', '北岳', '奥穂高岳', '槍ヶ岳'],
      correctChoiceIndex: 0,
      explanation: '富士山は標高3,776mで日本一高い山です。2番目は北岳（3,193m）です。',
    );
    _demoQuizzes[quiz.quizId] = quiz;
    return quiz;
  }

  // サンプルセッションを作成
  Future<Session> createSampleSession(String quizId) async {
    final now = DateTime.now();
    final sessionId = const Uuid().v4();

    final session = Session(
      sessionId: sessionId,
      scheduledAt: now,
      joinableUntil: now.add(Duration(seconds: AppConfig.joinDeadlineSeconds)),
      phase: SessionPhase.joinable,
      quizId: quizId,
      createdAt: now,
      phaseStartAt: now,
      correctRoomId: '${sessionId}_correct',
      incorrectRoomId: '${sessionId}_incorrect',
      commonRoomId: '${sessionId}_common',
    );

    _demoSessions[sessionId] = session;
    return session;
  }

  // セッションを更新
  void updateSession(String sessionId, Session Function(Session) update) {
    final session = _demoSessions[sessionId];
    if (session != null) {
      _demoSessions[sessionId] = update(session);
    }
  }

  // マッチング相手を見つける
  Future<({String partnerId, String roomId, bool isAI})> findOrCreateMatch(
    String sessionId,
    String userId,
    AnswerResult userResult,
  ) async {
    final participationId = '${sessionId}_$userId';
    final participation = _demoParticipations[participationId];

    if (participation?.oneOnOneRoomId != null) {
      return (
        partnerId: '',
        roomId: participation!.oneOnOneRoomId!,
        isAI: false,
      );
    }

    // 相手を探す
    final targetResult =
        userResult == AnswerResult.correct ? AnswerResult.incorrect : AnswerResult.correct;

    for (final entry in _demoParticipations.entries) {
      if (!entry.key.startsWith(sessionId)) continue;
      if (entry.value.userId == userId) continue;
      if (entry.value.result != targetResult) continue;
      if (entry.value.oneOnOneRoomId != null) continue;

      // マッチング成功
      final roomId = '${sessionId}_1on1_${const Uuid().v4().substring(0, 8)}';

      if (participation != null) {
        _demoParticipations[participationId] = participation.copyWith(
          oneOnOneRoomId: roomId,
        );
      }
      _demoParticipations[entry.key] = entry.value.copyWith(
        oneOnOneRoomId: roomId,
      );

      return (partnerId: entry.value.userId, roomId: roomId, isAI: false);
    }

    // AIとマッチング
    final aiPartner = AiService.createAIPartner(userResult != AnswerResult.correct);
    final roomId = '${sessionId}_1on1_ai_${const Uuid().v4().substring(0, 8)}';

    final aiParticipationId = '${sessionId}_${aiPartner.userId}';
    _demoParticipations[aiParticipationId] = Participation(
      sessionId: sessionId,
      userId: aiPartner.userId,
      joinedAt: DateTime.now(),
      result: targetResult,
      splitRoomAssigned: targetResult == AnswerResult.correct ? 'correct' : 'incorrect',
      oneOnOneRoomId: roomId,
    );

    if (participation != null) {
      _demoParticipations[participationId] = participation.copyWith(
        oneOnOneRoomId: roomId,
      );
    }

    return (partnerId: aiPartner.userId, roomId: roomId, isAI: true);
  }
}
