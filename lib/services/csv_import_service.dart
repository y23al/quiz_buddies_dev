// CSVインポートサービス
import 'package:csv/csv.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/models.dart';

class CsvImportService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // CSVをアセットから読み込みFirebaseに登録（既存データがあればスキップ）
  Future<CsvImportResult> importFromAsset(String assetPath) async {
    // 既にインポート済みか確認（subjectsが存在すればスキップ）
    final existing = await _db.child('subjects').get();
    if (existing.exists) {
      return CsvImportResult()..importedCount = -1; // スキップを示す
    }

    final csvString = await rootBundle.loadString(assetPath);
    return _importCsvString(csvString);
  }

  Future<CsvImportResult> _importCsvString(String csvString) async {
    final result = CsvImportResult();

    final rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) {
      result.errors.add('CSVが空です');
      return result;
    }

    // ヘッダーをスキップ
    final dataRows = rows.skip(1).toList();
    final subjectsMap = <String, Subject>{};
    final batchData = <String, Map<String, dynamic>>{}; // バッチ書き込み用

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final lineNo = i + 2;

      try {
        if (row.length < 11) {
          result.errors.add('行$lineNo: カラム数不足（${row.length}列）');
          continue;
        }

        final grade = _parseIntSafe(row[0]);
        final term = _parseIntSafe(row[1]);
        final subjectName = row[2].toString().trim();
        final lectureNo = _normalizeLectureNo(row[3].toString().trim());
        final questionNo = _parseIntSafe(row[4]);
        final questionText = row[5].toString().trim();
        final choiceA = row[6].toString().trim();
        final choiceB = row[7].toString().trim();
        final choiceC = row[8].toString().trim();
        final choiceD = row.length > 9 ? row[9].toString().trim() : '';
        final ans1 = row.length > 10 ? _normalizeAnswer(row[10].toString().trim()) : '';
        final ans2 = row.length > 11 ? _normalizeAnswer(row[11].toString().trim()) : '';
        final ans3 = row.length > 12 ? _normalizeAnswer(row[12].toString().trim()) : '';

        if (grade == 0 || term == 0 || subjectName.isEmpty || lectureNo == 0 || questionNo == 0) {
          result.errors.add('行$lineNo: 必須フィールドが不正');
          continue;
        }
        if (questionText.isEmpty || choiceA.isEmpty || choiceB.isEmpty) {
          result.errors.add('行$lineNo: 問題文または選択肢が空');
          continue;
        }
        if (ans1.isEmpty || !_isValidAnswer(ans1)) {
          result.errors.add('行$lineNo: ans1が不正');
          continue;
        }

        final answers = <String>[ans1];
        if (ans2.isNotEmpty && _isValidAnswer(ans2)) answers.add(ans2);
        if (ans3.isNotEmpty && _isValidAnswer(ans3)) answers.add(ans3);

        final questionId = '${grade}_${term}_${subjectName}_${lectureNo}_$questionNo';

        final question = Question(
          questionId: questionId,
          grade: grade,
          term: term,
          subjectName: subjectName,
          lectureNo: lectureNo,
          questionNo: questionNo,
          text: questionText,
          choices: {'A': choiceA, 'B': choiceB, 'C': choiceC, 'D': choiceD},
          answers: answers,
          answerMode: answers.length > 1 ? 'MULTI' : 'SINGLE',
        );

        // バッチに追加（まだ書き込まない）
        batchData['questions/$questionId'] = question.toMap();

        // 科目情報を収集
        final subjectKey = '${grade}_${term}_$subjectName';
        if (!subjectsMap.containsKey(subjectKey)) {
          subjectsMap[subjectKey] = Subject(
            subjectId: subjectKey,
            grade: grade,
            term: term,
            subjectName: subjectName,
            maxLectureNo: lectureNo,
          );
        } else {
          final existing = subjectsMap[subjectKey]!;
          if (lectureNo > existing.maxLectureNo) {
            subjectsMap[subjectKey] = Subject(
              subjectId: subjectKey,
              grade: grade,
              term: term,
              subjectName: subjectName,
              maxLectureNo: lectureNo,
            );
          }
        }

        result.importedCount++;
      } catch (e) {
        result.errors.add('行$lineNo: 予期しないエラー（$e）');
      }
    }

    // 科目マスタもバッチに追加
    for (final subject in subjectsMap.values) {
      batchData['subjects/${subject.subjectId}'] = subject.toMap();
    }
    result.subjectCount = subjectsMap.length;

    // 1回のリクエストで全データを書き込み（バッチ）
    if (batchData.isNotEmpty) {
      await _db.update(batchData);
    }

    return result;
  }

  // 授業回の正規化: "第12回" → 12, "12" → 12
  int _normalizeLectureNo(String value) {
    final cleaned = value.replaceAll('第', '').replaceAll('回', '').trim();
    return _parseIntSafe(cleaned);
  }

  // ans正規化: 1-4 → A-D
  String _normalizeAnswer(String value) {
    if (value.isEmpty) return '';
    final trimmed = value.trim().toUpperCase();
    switch (trimmed) {
      case '1': return 'A';
      case '2': return 'B';
      case '3': return 'C';
      case '4': return 'D';
      default: return trimmed;
    }
  }

  bool _isValidAnswer(String value) {
    return ['A', 'B', 'C', 'D'].contains(value.toUpperCase());
  }

  int _parseIntSafe(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    final str = value.toString().trim();
    return int.tryParse(str) ?? 0;
  }

  // Firebase DBから科目一覧を取得
  Future<List<Subject>> getSubjects() async {
    final snapshot = await _db.child('subjects').get();
    if (!snapshot.exists) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return data.values
        .map((v) => Subject.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  // 指定学年の科目一覧
  Future<List<Subject>> getSubjectsByGrade(int grade) async {
    final all = await getSubjects();
    return all.where((s) => s.grade == grade).toList();
  }

  // 指定学年・学期の科目一覧
  Future<List<Subject>> getSubjectsByGradeAndTerm(int grade, int term) async {
    final all = await getSubjects();
    return all.where((s) => s.grade == grade && s.term == term).toList();
  }

  // 指定科目の授業回一覧
  Future<List<int>> getLectureNos(String subjectId) async {
    try {
      final snapshot = await _db.child('questions').get();
      if (!snapshot.exists) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final lectureNos = <int>{};
      for (final v in data.values) {
        final q = Map<String, dynamic>.from(v as Map);
        final key = '${q['grade']}_${q['term']}_${q['subjectName']}';
        if (key == subjectId) {
          final lectureNo = q['lectureNo'];
          if (lectureNo is int) {
            lectureNos.add(lectureNo);
          } else if (lectureNo is num) {
            lectureNos.add(lectureNo.toInt());
          }
        }
      }
      return lectureNos.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // 指定授業回の問題10問を取得
  Future<List<Question>> getQuestions(String subjectId, int lectureNo) async {
    final snapshot = await _db.child('questions').get();
    if (!snapshot.exists) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final questions = <Question>[];
    for (final v in data.values) {
      final q = Question.fromMap(Map<String, dynamic>.from(v as Map));
      final key = '${q.grade}_${q.term}_${q.subjectName}';
      if (key == subjectId && q.lectureNo == lectureNo) {
        questions.add(q);
      }
    }
    questions.sort((a, b) => a.questionNo.compareTo(b.questionNo));
    return questions.take(10).toList();
  }
}

// インポート結果
class CsvImportResult {
  int importedCount = 0;
  int subjectCount = 0;
  List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() {
    return 'インポート結果: ${importedCount}問登録, ${subjectCount}科目, エラー${errors.length}件';
  }
}
