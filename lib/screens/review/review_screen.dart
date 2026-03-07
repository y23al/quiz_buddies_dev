// 復習画面（50%以上誤答の問題表示）
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class ReviewScreen extends StatelessWidget {
  final String sessionId;
  final List<Map<String, dynamic>> questions;

  const ReviewScreen({
    super.key,
    required this.sessionId,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    // 全問題を復習対象として表示（P0: 個人の結果ベース）
    final questionList = questions
        .map((q) => Question.fromMap(q))
        .toList();

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Premium header with back button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24),
                      ),
                    ),
                    const Text(
                      '復習',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: questionList.isEmpty
                    ? const Center(
                        child: Text(
                          '復習する問題はありません',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: questionList.length,
                        itemBuilder: (context, index) {
                          final q = questionList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PremiumCard(
                              type: PremiumCardType.light,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 問題番号
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.goldPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Q${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.goldDeep,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // 問題文
                                  Text(
                                    q.text,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.5,
                                      color: AppColors.textOnCard,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // 選択肢と正解表示
                                  ...['A', 'B', 'C', 'D'].map((choice) {
                                    final text = q.choices[choice] ?? '';
                                    if (text.isEmpty) return const SizedBox.shrink();
                                    final isAnswer = q.answers.contains(choice);
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isAnswer
                                            ? AppColors.goldPrimary.withValues(alpha: 0.12)
                                            : AppColors.textOnCard.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isAnswer
                                              ? AppColors.goldPrimary
                                              : AppColors.textOnCard.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: isAnswer
                                                ? AppColors.goldPrimary
                                                : AppColors.textOnCard.withValues(alpha: 0.3),
                                            child: Text(
                                              choice,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              text,
                                              style: TextStyle(
                                                color: isAnswer
                                                    ? AppColors.goldDeep
                                                    : AppColors.textOnCard,
                                              ),
                                            ),
                                          ),
                                          if (isAnswer)
                                            const Icon(
                                              Icons.check_circle,
                                              color: AppColors.goldPrimary,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
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
}
