// 問題モデル（CSVベース）
class Question {
  final String questionId;
  final int grade;
  final int term;
  final String subjectName;
  final int lectureNo;
  final int questionNo;
  final String text;
  final Map<String, String> choices; // {A: "...", B: "...", C: "...", D: "..."}
  final List<String> answers; // ["A"] or ["A", "C", "D"]
  final String answerMode; // SINGLE or MULTI

  Question({
    required this.questionId,
    required this.grade,
    required this.term,
    required this.subjectName,
    required this.lectureNo,
    required this.questionNo,
    required this.text,
    required this.choices,
    required this.answers,
    required this.answerMode,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      questionId: map['questionId'] as String? ?? '',
      grade: map['grade'] as int? ?? 0,
      term: map['term'] as int? ?? 0,
      subjectName: map['subjectName'] as String? ?? '',
      lectureNo: map['lectureNo'] as int? ?? 0,
      questionNo: map['questionNo'] as int? ?? 0,
      text: map['text'] as String? ?? '',
      choices: Map<String, String>.from(map['choices'] as Map? ?? {}),
      answers: List<String>.from(map['answers'] as List? ?? []),
      answerMode: map['answerMode'] as String? ?? 'SINGLE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'grade': grade,
      'term': term,
      'subjectName': subjectName,
      'lectureNo': lectureNo,
      'questionNo': questionNo,
      'text': text,
      'choices': choices,
      'answers': answers,
      'answerMode': answerMode,
    };
  }

  // P0: 単一正解判定（ans1のみ使用）
  bool isCorrect(String selectedChoice) {
    return answers.isNotEmpty && answers[0] == selectedChoice;
  }
}
