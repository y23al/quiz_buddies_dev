// 復習画面（50%以上誤答の問題表示）
import 'package:flutter/material.dart';
import '../../models/models.dart';

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('復習', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: questionList.isEmpty
          ? const Center(child: Text('復習する問題はありません'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questionList.length,
              itemBuilder: (context, index) {
                final q = questionList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 問題番号
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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
                              color: isAnswer ? Colors.green[50] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAnswer ? Colors.green : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isAnswer ? Colors.green : Colors.grey[400],
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
                                      color: isAnswer ? Colors.green[800] : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isAnswer)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
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
    );
  }
}
