// 再試験画面（正解5問以下→同じ問題をポイント0で再出題）
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';

class RetestScreen extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> questions;
  final String subjectName;
  final int lectureNo;

  const RetestScreen({
    super.key,
    required this.sessionId,
    required this.questions,
    required this.subjectName,
    required this.lectureNo,
  });

  @override
  State<RetestScreen> createState() => _RetestScreenState();
}

class _RetestScreenState extends State<RetestScreen> {
  late List<Question> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  String? _selectedChoice;
  bool _isAnswered = false;
  bool _isCorrect = false;
  int _remainingSeconds = AppConfig.quizTimeSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _questions = widget.questions.map((q) => Question.fromMap(q)).toList();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = AppConfig.quizTimeSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      }
    });
  }

  void _handleTimeout() {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
      _isCorrect = false;
    });
    _showResultAndNext();
  }

  void _selectChoice(String choice) {
    if (_isAnswered) return;
    _timer?.cancel();

    final question = _questions[_currentIndex];
    final correct = question.isCorrect(choice);

    setState(() {
      _selectedChoice = choice;
      _isAnswered = true;
      _isCorrect = correct;
      if (correct) _correctCount++;
    });

    _showResultAndNext();
  }

  void _showResultAndNext() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedChoice = null;
          _isAnswered = false;
          _isCorrect = false;
        });
        _startTimer();
      } else {
        _showRetestResult();
      }
    });
  }

  void _showRetestResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('再試験結果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_correctCount / ${_questions.length}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '再試験のためポイントは加算されません',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
            child: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentIndex];
    final choices = ['A', 'B', 'C', 'D'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        automaticallyImplyLeading: false,
        title: Text(
          '再試験 Q${_currentIndex + 1} / ${_questions.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 10 ? Colors.yellow : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_remainingSeconds秒',
              style: TextStyle(
                color: _remainingSeconds <= 10 ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ポイント0の警告
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '再試験（ポイント加算なし）',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                backgroundColor: Colors.grey[300],
                color: Colors.red,
              ),
              const SizedBox(height: 20),

              // 問題文
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Text(
                        question.text,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 選択肢
              Expanded(
                flex: 4,
                child: ListView.separated(
                  itemCount: choices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    final choiceText = question.choices[choice] ?? '';
                    if (choiceText.isEmpty) return const SizedBox.shrink();

                    Color bgColor = Colors.white;
                    Color borderColor = Colors.grey[300]!;
                    Color textColor = Colors.black87;

                    if (_isAnswered && choice == _selectedChoice) {
                      if (_isCorrect) {
                        bgColor = Colors.green[50]!;
                        borderColor = Colors.green;
                        textColor = Colors.green[800]!;
                      } else {
                        bgColor = Colors.red[50]!;
                        borderColor = Colors.red;
                        textColor = Colors.red[800]!;
                      }
                    }

                    return InkWell(
                      onTap: _isAnswered ? null : () => _selectChoice(choice),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: borderColor,
                              child: Text(
                                choice,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                choiceText,
                                style: TextStyle(fontSize: 16, color: textColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_isAnswered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isCorrect ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCorrect ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCorrect ? '正解！' : '不正解',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
