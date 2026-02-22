// 学期選択画面
import 'package:flutter/material.dart';

class TermSelectScreen extends StatelessWidget {
  final int grade;

  const TermSelectScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    // 選択可能な学期（1〜5学期）
    final terms = List.generate(5, (i) => i + 1);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: Text('$grade年生 - 学期を選択', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '学期を選んでください',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2,
                ),
                itemCount: terms.length,
                itemBuilder: (context, index) {
                  final term = terms[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/select-subject',
                          arguments: {'grade': grade, 'term': term},
                        );
                      },
                      child: Center(
                        child: Text(
                          '第$term学期',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}
