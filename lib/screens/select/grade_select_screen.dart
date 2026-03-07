// 学年選択画面 — Premium Design
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class GradeSelectScreen extends StatelessWidget {
  const GradeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grades = [1, 2];

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text('クイズの学年を選んでください',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: grades.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final grade = grades[index];
                    return PremiumCard(
                      type: PremiumCardType.dark,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/select-term',
                        arguments: {'grade': grade},
                      ),
                      child: Row(
                        children: [
                          GoldIconCircle(
                            icon: Icons.school_rounded,
                            size: 48,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('$grade年生',
                                style: AppTextStyles.section
                                    .copyWith(fontSize: 20)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.goldPrimary, size: 28),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Text('学年を選択',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
