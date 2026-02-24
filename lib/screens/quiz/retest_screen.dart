// 再試験画面（正解5問以下→同じ問題をポイント0で再出題）
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

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
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.lineGold, width: 1.5),
        ),
        title: const Text(
          '再試験結果',
          style: TextStyle(
            color: AppColors.textOnCard,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_correctCount / ${_questions.length}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnCard,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '再試験のためポイントは加算されません',
              style: TextStyle(
                color: AppColors.textOnCard.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
            child: const Text(
              'ホームに戻る',
              style: TextStyle(color: AppColors.goldPrimary),
            ),
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
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Premium header with danger accent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.danger, width: 0.5)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '再試験 Q${_currentIndex + 1} / ${_questions.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _remainingSeconds <= 10
                            ? AppColors.danger
                            : AppColors.surfaceCard2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _remainingSeconds <= 10
                              ? AppColors.danger
                              : AppColors.lineGold,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            color: _remainingSeconds <= 10
                                ? Colors.white
                                : AppColors.goldPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_remainingSeconds秒',
                            style: TextStyle(
                              color: _remainingSeconds <= 10
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body content
              Expanded(
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
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '再試験（ポイント加算なし）',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Progress bar with danger color
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _questions.length,
                          backgroundColor: AppColors.surfaceCard2,
                          color: AppColors.danger,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 問題文
                      Expanded(
                        flex: 3,
                        child: PremiumCard(
                          type: PremiumCardType.light,
                          child: SingleChildScrollView(
                            child: Text(
                              question.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.6,
                                color: AppColors.textOnCard,
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

                            Color bgColor = AppColors.surfaceCard2;
                            Color borderColor = AppColors.lineGold;
                            Color textColor = AppColors.textPrimary;
                            Color avatarBg = AppColors.lineGold;

                            if (_isAnswered && choice == _selectedChoice) {
                              if (_isCorrect) {
                                bgColor = AppColors.goldPrimary.withValues(alpha: 0.15);
                                borderColor = AppColors.goldPrimary;
                                textColor = AppColors.goldPrimary;
                                avatarBg = AppColors.goldPrimary;
                              } else {
                                bgColor = AppColors.danger.withValues(alpha: 0.15);
                                borderColor = AppColors.danger;
                                textColor = AppColors.danger;
                                avatarBg = AppColors.danger;
                              }
                            }

                            return InkWell(
                              onTap: _isAnswered ? null : () => _selectChoice(choice),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(color: borderColor, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: avatarBg,
                                      child: Text(
                                        choice,
                                        style: TextStyle(
                                          color: _isAnswered && choice == _selectedChoice
                                              ? Colors.white
                                              : AppColors.textOnCard,
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
                            color: _isCorrect ? AppColors.goldPrimary : AppColors.danger,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isCorrect ? Icons.check_circle : Icons.cancel,
                                color: _isCorrect ? AppColors.textOnCard : Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isCorrect ? '正解！' : '不正解',
                                style: TextStyle(
                                  color: _isCorrect ? AppColors.textOnCard : Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}
