// セッションプロバイダー
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// マッチ結果
class MatchResult {
  final String userId;
  final bool isAI;

  MatchResult({required this.userId, required this.isAI});
}

// セッション状態
class SessionState {
  final Session? currentSession;
  final Quiz? currentQuiz;
  final Participation? participation;
  final List<Message> messages;
  final bool isLoading;

  SessionState({
    this.currentSession,
    this.currentQuiz,
    this.participation,
    this.messages = const [],
    this.isLoading = false,
  });

  SessionState copyWith({
    Session? currentSession,
    Quiz? currentQuiz,
    Participation? participation,
    List<Message>? messages,
    bool? isLoading,
  }) {
    return SessionState(
      currentSession: currentSession ?? this.currentSession,
      currentQuiz: currentQuiz ?? this.currentQuiz,
      participation: participation ?? this.participation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// セッション状態管理
class SessionNotifier extends StateNotifier<SessionState> {
  final SessionService _sessionService;
  final RoomService _roomService;

  SessionNotifier(this._sessionService, this._roomService) : super(SessionState());

  // テストセッションを作成
  Future<void> createTestSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final quiz = await _sessionService.createSampleQuiz();
      final session = await _sessionService.createSampleSession(quiz.quizId);
      state = state.copyWith(
        currentSession: session,
        currentQuiz: quiz,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // セッションに参加
  Future<void> joinSession(String sessionId, String userId) async {
    final participation = await _sessionService.joinSession(sessionId, userId);
    state = state.copyWith(participation: participation);
  }

  // 回答を送信（詳細版）
  Future<AnswerResult> submitAnswerWithDetails(String sessionId, String userId, int answerIndex) async {
    final result = await _sessionService.submitAnswer(sessionId, userId, answerIndex);
    final participation = _sessionService.getParticipation(sessionId, userId);
    state = state.copyWith(participation: participation);
    return result;
  }

  // 回答を送信（簡易版 - 画面から呼び出し）
  Future<void> submitAnswer(bool isCorrect) async {
    if (state.currentSession == null) return;

    final participation = Participation(
      userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: state.currentSession!.sessionId,
      joinedAt: DateTime.now(),
      result: isCorrect ? AnswerResult.correct : AnswerResult.incorrect,
      splitRoomAssigned: isCorrect ? 'correct' : 'incorrect',
    );
    state = state.copyWith(participation: participation);
  }

  // セッションフェーズを更新
  void updateSessionPhase(SessionPhase phase) {
    if (state.currentSession != null) {
      _sessionService.updateSession(state.currentSession!.sessionId, (s) => s.copyWith(phase: phase));
      state = state.copyWith(
        currentSession: state.currentSession!.copyWith(phase: phase),
      );
    }
  }

  // マッチングを実行（詳細版）
  Future<({String partnerId, String roomId, bool isAI})> findMatchWithDetails(
    String sessionId,
    String userId,
    AnswerResult result,
  ) async {
    return await _sessionService.findOrCreateMatch(sessionId, userId, result);
  }

  // マッチングを実行（簡易版 - 画面から呼び出し）
  Future<MatchResult?> findMatch(bool isCorrectSide) async {
    // デモモード: ランダムでAIまたは人間パートナーを返す
    final random = DateTime.now().millisecondsSinceEpoch % 3;
    if (random == 0) {
      // 人間パートナーが見つかった（デモ）
      return MatchResult(
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        isAI: false,
      );
    } else {
      // AIパートナー
      return MatchResult(
        userId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        isAI: true,
      );
    }
  }

  // メッセージを更新
  void updateMessages(String roomId) {
    final messages = _roomService.getMessages(roomId);
    state = state.copyWith(messages: messages);
  }

  // リセット
  void reset() {
    state = SessionState();
  }
}

// プロバイダー
final sessionServiceProvider = Provider((ref) => SessionService());
final roomServiceProvider = Provider((ref) => RoomService());

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(
    ref.watch(sessionServiceProvider),
    ref.watch(roomServiceProvider),
  );
});
