// クイズ画面（10問対応・即判定）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? roomCode;
  final int grade;
  final int term;
  final String subjectId;
  final String subjectName;
  final int lectureNo;

  const QuizScreen({
    super.key,
    required this.sessionId,
    this.roomCode,
    this.grade = 0,
    this.term = 0,
    this.subjectId = '',
    this.subjectName = '',
    this.lectureNo = 0,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final CsvImportService _csvService = CsvImportService();
  final FirebaseSessionService _sessionService = FirebaseSessionService();

  List<Question> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalPoints = 0;
  bool _isLoading = true;
  String? _selectedChoice;
  bool _isAnswered = false;
  bool _isCorrect = false;
  int _remainingSeconds = AppConfig.quizTimeSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions = await _csvService.getQuestions(
      widget.subjectId,
      widget.lectureNo,
    );

    if (mounted) {
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この授業回には問題がありません')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return;
      }
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      _startTimer();
    }
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
    _recordAnswer(null);
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
      if (correct) {
        _correctCount++;
        _totalPoints += AppConfig.pointsPerCorrect;
      }
    });

    _recordAnswer(choice);
    _showResultAndNext();
  }

  void _recordAnswer(String? choice) {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    _sessionService.submitAnswer(
      widget.sessionId,
      authState.user!.userId,
      choice != null ? ['A', 'B', 'C', 'D'].indexOf(choice) : -1,
      _isCorrect,
    );
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
        // Firebaseにクイズ完了を記録
        final authState = ref.read(authProvider);
        if (authState.user != null) {
          _sessionService.markQuizCompleted(
            widget.sessionId,
            authState.user!.userId,
            _correctCount,
            _questions.length,
          );
        }
        Navigator.pushReplacementNamed(context, '/result', arguments: {
          'sessionId': widget.sessionId,
          'roomCode': widget.roomCode,
          'subjectName': widget.subjectName,
          'lectureNo': widget.lectureNo,
          'correctCount': _correctCount,
          'totalQuestions': _questions.length,
          'totalPoints': _totalPoints,
          'questions': _questions.map((q) => q.toMap()).toList(),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
      );
    }

    final question = _questions[_currentIndex];
    final choices = ['A', 'B', 'C', 'D'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        automaticallyImplyLeading: false,
        title: Text(
          'Q${_currentIndex + 1} / ${_questions.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 10 ? Colors.red : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  color: _remainingSeconds <= 10 ? Colors.white : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_remainingSeconds秒',
                  style: TextStyle(
                    color: _remainingSeconds <= 10 ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                backgroundColor: Colors.grey[300],
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),

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
