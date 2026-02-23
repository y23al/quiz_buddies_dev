// 学期選択画面 — Premium Design
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class TermSelectScreen extends StatelessWidget {
  final int grade;
  const TermSelectScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final terms = List.generate(5, (i) => i + 1);

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text('学期を選んでください',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2,
                  ),
                  itemCount: terms.length,
                  itemBuilder: (context, index) {
                    final term = terms[index];
                    return PremiumCard(
                      type: PremiumCardType.dark,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/select-subject',
                        arguments: {'grade': grade, 'term': term},
                      ),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Text('第$term学期',
                            style: AppTextStyles.section),
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
          Text('$grade年生 - 学期を選択',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
