// クイズモデル

class Quiz {
  final String quizId;
  final String questionText;
  final List<String> choices;
  final int correctChoiceIndex;
  final String? explanation;
  final String? difficulty;

  Quiz({
    required this.quizId,
    required this.questionText,
    required this.choices,
    required this.correctChoiceIndex,
    this.explanation,
    this.difficulty,
  });

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      quizId: map['quizId'] ?? '',
      questionText: map['questionText'] ?? '',
      choices: List<String>.from(map['choices'] ?? []),
      correctChoiceIndex: map['correctChoiceIndex'] ?? 0,
      explanation: map['explanation'],
      difficulty: map['difficulty'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'questionText': questionText,
      'choices': choices,
      'correctChoiceIndex': correctChoiceIndex,
      'explanation': explanation,
      'difficulty': difficulty,
    };
  }
}
