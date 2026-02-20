// 科目選択画面
import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';

class SubjectSelectScreen extends StatefulWidget {
  final int grade;
  final int term;

  const SubjectSelectScreen({
    super.key,
    required this.grade,
    required this.term,
  });

  @override
  State<SubjectSelectScreen> createState() => _SubjectSelectScreenState();
}

class _SubjectSelectScreenState extends State<SubjectSelectScreen> {
  final CsvImportService _csvService = CsvImportService();
  List<Subject>? _subjects;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subjects = await _csvService.getSubjectsByGradeAndTerm(
      widget.grade,
      widget.term,
    );
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: Text(
          '${widget.grade}年 第${widget.term}学期 - 科目選択',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : _subjects == null || _subjects!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        '科目が見つかりません',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'この学年・学期にはまだ問題が登録されていません',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '科目を選んでください',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _subjects!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final subject = _subjects![index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  radius: 24,
                                  child: Icon(
                                    _getSubjectIcon(subject.subjectName),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  subject.subjectName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('授業回: 全${subject.maxLectureNo}回'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  // ルーム作成に遷移
                                  Navigator.pushNamed(
                                    context,
                                    '/lobby',
                                    arguments: {
                                      'grade': widget.grade,
                                      'term': widget.term,
                                      'subjectId': subject.subjectId,
                                      'subjectName': subject.subjectName,
                                      'isHost': true,
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  IconData _getSubjectIcon(String name) {
    if (name.contains('データベース')) return Icons.storage;
    if (name.contains('プログラ')) return Icons.code;
    if (name.contains('ネットワーク')) return Icons.lan;
    if (name.contains('セキュリティ')) return Icons.security;
    if (name.contains('数学')) return Icons.calculate;
    return Icons.book;
  }
}
