// クイズ画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? sharedSession;

  const QuizScreen({
    super.key,
    required this.sessionId,
    this.sharedSession,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  Timer? _timer;
  int _remainingSeconds = AppConfig.quizTimeSeconds;
  int? _selectedAnswer;
  bool _hasSubmitted = false;
  Quiz? _sharedQuiz;
  final FirebaseSessionService _sessionService = FirebaseSessionService();

  @override
  void initState() {
    super.initState();
    _loadSharedQuiz();
    _startTimer();
  }

  void _loadSharedQuiz() {
    // Firebaseから共有されたクイズデータを使用
    if (widget.sharedSession != null) {
      final session = widget.sharedSession!;
      _sharedQuiz = Quiz(
        quizId: session['quizId'] as String? ?? '',
        questionText: session['questionText'] as String? ?? '',
        choices: List<String>.from(session['choices'] as List? ?? []),
        correctChoiceIndex: session['correctChoiceIndex'] as int? ?? 0,
        explanation: session['explanation'] as String? ?? '',
        difficulty: session['difficulty'] as String? ?? 'normal',
      );
      // ローカルのセッション状態にも設定
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionProvider.notifier).setQuiz(_sharedQuiz!);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        if (!_hasSubmitted) {
          _submitAnswer();
        }
      }
    });
  }

  Future<void> _submitAnswer() async {
    if (_hasSubmitted) return;

    setState(() {
      _hasSubmitted = true;
    });
    _timer?.cancel();

    // 共有クイズまたはローカルクイズから正解を取得
    final quiz = _sharedQuiz ?? ref.read(sessionProvider).currentQuiz;
    final isCorrect = _selectedAnswer != null &&
        quiz?.correctChoiceIndex == _selectedAnswer;

    await ref.read(sessionProvider.notifier).submitAnswer(isCorrect);

    // Firebaseにも回答を送信
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      await _sessionService.submitAnswer(
        widget.sessionId,
        authState.user!.userId,
        _selectedAnswer ?? -1,
        isCorrect,
      );
    }

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/result',
        arguments: {
          'sessionId': widget.sessionId,
          'isCorrect': isCorrect,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    // 共有クイズを優先、なければローカルクイズを使用
    final quiz = _sharedQuiz ?? sessionState.currentQuiz;

    if (quiz == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          'クイズ',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // タイマー
              _buildTimer(),
              const SizedBox(height: 24),

              // 問題
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '問題',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quiz.questionText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 選択肢
              Expanded(
                child: ListView.builder(
                  itemCount: quiz.choices.length,
                  itemBuilder: (context, index) {
                    return _buildOptionButton(index, quiz.choices[index]);
                  },
                ),
              ),

              // 回答ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != null && !_hasSubmitted
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    _hasSubmitted ? '送信中...' : '回答する',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedAnswer != null && !_hasSubmitted
                          ? Colors.white
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final isLowTime = _remainingSeconds <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isLowTime ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLowTime ? Colors.red : const Color(0xFF4CAF50),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: isLowTime ? Colors.red : const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 8),
          Text(
            '$_remainingSeconds秒',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isLowTime ? Colors.red : const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, String option) {
    final isSelected = _selectedAnswer == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _hasSubmitted
            ? null
            : () {
                setState(() {
                  _selectedAnswer = index;
                });
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
