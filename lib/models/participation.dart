// 参加情報モデル

enum AnswerResult { correct, incorrect, timeout }

class Participation {
  final String sessionId;
  final String userId;
  final DateTime joinedAt;
  final int? answer;
  final DateTime? answeredAt;
  final AnswerResult? result;
  final String? splitRoomAssigned;
  final String? oneOnOneRoomId;
  final DateTime? commonRoomJoinedAt;

  Participation({
    required this.sessionId,
    required this.userId,
    required this.joinedAt,
    this.answer,
    this.answeredAt,
    this.result,
    this.splitRoomAssigned,
    this.oneOnOneRoomId,
    this.commonRoomJoinedAt,
  });

  factory Participation.fromMap(Map<String, dynamic> map) {
    AnswerResult? result;
    if (map['result'] != null) {
      result = AnswerResult.values.firstWhere(
        (e) => e.name.toUpperCase() == map['result'],
        orElse: () => AnswerResult.timeout,
      );
    }

    return Participation(
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      joinedAt: map['joinedAt']?.toDate() ?? DateTime.now(),
      answer: map['answer'],
      answeredAt: map['answeredAt']?.toDate(),
      result: result,
      splitRoomAssigned: map['splitRoomAssigned'],
      oneOnOneRoomId: map['oneOnOneRoomId'],
      commonRoomJoinedAt: map['commonRoomJoinedAt']?.toDate(),
    );
  }

  Participation copyWith({
    String? sessionId,
    String? userId,
    DateTime? joinedAt,
    int? answer,
    DateTime? answeredAt,
    AnswerResult? result,
    String? splitRoomAssigned,
    String? oneOnOneRoomId,
    DateTime? commonRoomJoinedAt,
  }) {
    return Participation(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
      result: result ?? this.result,
      splitRoomAssigned: splitRoomAssigned ?? this.splitRoomAssigned,
      oneOnOneRoomId: oneOnOneRoomId ?? this.oneOnOneRoomId,
      commonRoomJoinedAt: commonRoomJoinedAt ?? this.commonRoomJoinedAt,
    );
  }
}
