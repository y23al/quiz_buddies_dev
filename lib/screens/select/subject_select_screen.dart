// 科目選択画面 — Premium Design
import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

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
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.grade}年 第${widget.term}学期',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldPrimary),
      );
    }
    if (_subjects == null || _subjects!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined,
                size: 64, color: AppColors.textPrimary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('科目が見つかりません',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('この学年・学期にはまだ問題が登録されていません',
                style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _subjects!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final subject = _subjects![index];
        return PremiumCard(
          type: PremiumCardType.dark,
          onTap: () {
            Navigator.pushNamed(context, '/lobby', arguments: {
              'grade': widget.grade,
              'term': widget.term,
              'subjectId': subject.subjectId,
              'subjectName': subject.subjectName,
              'isHost': true,
            });
          },
          child: Row(
            children: [
              GoldIconCircle(
                icon: _getSubjectIcon(subject.subjectName),
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.subjectName,
                        style: AppTextStyles.section.copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text('授業回: 全${subject.maxLectureNo}回',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.goldPrimary, size: 28),
            ],
          ),
        );
      },
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
