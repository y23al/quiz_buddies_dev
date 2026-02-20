// 科目マスタモデル
class Subject {
  final String subjectId;
  final int grade;
  final int term;
  final String subjectName;
  final int maxLectureNo;

  Subject({
    required this.subjectId,
    required this.grade,
    required this.term,
    required this.subjectName,
    required this.maxLectureNo,
  });

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      subjectId: map['subjectId'] as String? ?? '',
      grade: map['grade'] as int? ?? 0,
      term: map['term'] as int? ?? 0,
      subjectName: map['subjectName'] as String? ?? '',
      maxLectureNo: map['maxLectureNo'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'grade': grade,
      'term': term,
      'subjectName': subjectName,
      'maxLectureNo': maxLectureNo,
    };
  }
}
