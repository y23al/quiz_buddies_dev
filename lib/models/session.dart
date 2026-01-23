// セッションモデル

enum SessionPhase {
  scheduled,
  joinable,
  quiz,
  splitRoom,
  matching,
  oneOnOne,
  common,
  finished,
}

class Session {
  final String sessionId;
  final DateTime scheduledAt;
  final DateTime joinableUntil;
  final SessionPhase phase;
  final String quizId;
  final DateTime createdAt;
  final DateTime phaseStartAt;
  final String? correctRoomId;
  final String? incorrectRoomId;
  final String? commonRoomId;

  Session({
    required this.sessionId,
    required this.scheduledAt,
    required this.joinableUntil,
    required this.phase,
    required this.quizId,
    required this.createdAt,
    required this.phaseStartAt,
    this.correctRoomId,
    this.incorrectRoomId,
    this.commonRoomId,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['sessionId'] ?? '',
      scheduledAt: map['scheduledAt']?.toDate() ?? DateTime.now(),
      joinableUntil: map['joinableUntil']?.toDate() ?? DateTime.now(),
      phase: SessionPhase.values.firstWhere(
        (e) => e.name.toUpperCase() == (map['phase'] ?? 'SCHEDULED'),
        orElse: () => SessionPhase.scheduled,
      ),
      quizId: map['quizId'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      phaseStartAt: map['phaseStartAt']?.toDate() ?? DateTime.now(),
      correctRoomId: map['correctRoomId'],
      incorrectRoomId: map['incorrectRoomId'],
      commonRoomId: map['commonRoomId'],
    );
  }

  Session copyWith({
    String? sessionId,
    DateTime? scheduledAt,
    DateTime? joinableUntil,
    SessionPhase? phase,
    String? quizId,
    DateTime? createdAt,
    DateTime? phaseStartAt,
    String? correctRoomId,
    String? incorrectRoomId,
    String? commonRoomId,
  }) {
    return Session(
      sessionId: sessionId ?? this.sessionId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      joinableUntil: joinableUntil ?? this.joinableUntil,
      phase: phase ?? this.phase,
      quizId: quizId ?? this.quizId,
      createdAt: createdAt ?? this.createdAt,
      phaseStartAt: phaseStartAt ?? this.phaseStartAt,
      correctRoomId: correctRoomId ?? this.correctRoomId,
      incorrectRoomId: incorrectRoomId ?? this.incorrectRoomId,
      commonRoomId: commonRoomId ?? this.commonRoomId,
    );
  }
}
