// 結果画面（正解数・ポイント・再試験判定・全員完了でチャット遷移）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? roomCode;
  final String subjectName;
  final int lectureNo;
  final int correctCount;
  final int totalQuestions;
  final int totalPoints;
  final List<Map<String, dynamic>> questions;

  const ResultScreen({
    super.key,
    required this.sessionId,
    this.roomCode,
    required this.subjectName,
    required this.lectureNo,
    required this.correctCount,
    required this.totalQuestions,
    required this.totalPoints,
    required this.questions,
    bool isCorrect = false,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  bool _showExitButton = false;
  bool _allCompleted = false;
  int _completedCount = 0;
  int _totalParticipants = 0;
  Timer? _exitTimer;
  StreamSubscription? _participantSubscription;

  bool get _needsRetest => widget.correctCount <= AppConfig.retestThreshold;

  @override
  void initState() {
    super.initState();
    _savePoints();
    _watchAllCompleted();
    // 退出ボタンを10秒後に表示
    _exitTimer = Timer(Duration(seconds: AppConfig.exitButtonDelaySeconds), () {
      if (mounted) setState(() => _showExitButton = true);
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _participantSubscription?.cancel();
    super.dispose();
  }

  Future<void> _savePoints() async {
    final authState = ref.read(authProvider);
    if (authState.user == null) return;

    await _sessionService.addPoints(
      authState.user!.userId,
      authState.user!.displayName,
      widget.totalPoints,
      widget.correctCount,
      widget.totalQuestions,
    );
  }

  void _watchAllCompleted() {
    _participantSubscription = _sessionService
        .watchParticipants(widget.sessionId)
        .listen((participants) {
      if (!mounted) return;

      final total = participants.length;
      final completed = participants
          .where((p) => p['quizCompleted'] == true)
          .length;

      setState(() {
        _totalParticipants = total;
        _completedCount = completed;
      });

      if (total > 0 && completed >= total && !_allCompleted) {
        setState(() => _allCompleted = true);
        // 全員完了 → 2秒後にチャットへ自動遷移（再試験情報も渡す）
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/chat', arguments: {
              'sessionId': widget.sessionId,
              'correctCount': widget.correctCount,
              'totalQuestions': widget.totalQuestions,
              'questions': widget.questions,
              'subjectName': widget.subjectName,
              'lectureNo': widget.lectureNo,
            });
          }
        });
      }
    });
  }

  void _goToReview() {
    Navigator.pushNamed(context, '/review', arguments: {
      'sessionId': widget.sessionId,
      'questions': widget.questions,
      'correctCount': widget.correctCount,
      'totalQuestions': widget.totalQuestions,
    });
  }

  void _exit() {
    if (_needsRetest) {
      Navigator.pushReplacementNamed(context, '/retest', arguments: {
        'sessionId': widget.sessionId,
        'questions': widget.questions,
        'subjectName': widget.subjectName,
        'lectureNo': widget.lectureNo,
      });
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.correctCount / widget.totalQuestions * 100).round();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text('結果', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // スコア表示
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text(
                        widget.subjectName,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '第${widget.lectureNo}回',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${widget.correctCount} / ${widget.totalQuestions}',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: percentage >= 50 ? const Color(0xFF4CAF50) : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$percentage%正解',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              '+${widget.totalPoints}pt',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 再試験通知
              if (_needsRetest)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '再試験対象です',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '正解数${AppConfig.retestThreshold}問以下のため、退出後に再試験があります',
                                style: TextStyle(color: Colors.red[700], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 全員完了ステータス
              Card(
                color: _allCompleted ? Colors.green[50] : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_allCompleted)
                        const Icon(Icons.check_circle, color: Colors.green)
                      else
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _allCompleted
                            ? const Text(
                                '全員回答完了！チャットに移動します...',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : Text(
                                '回答完了: $_completedCount / $_totalParticipants人',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 復習ボタン（待ち時間中に復習可能）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToReview,
                  icon: const Icon(Icons.school, color: Colors.white),
                  label: const Text(
                    '待ち時間に復習する',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 退出ボタン（10秒後に表示）
              if (_showExitButton)
                TextButton(
                  onPressed: _exit,
                  child: Text(
                    _needsRetest ? '退出して再試験へ' : '退出する',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              if (!_showExitButton)
                Text(
                  '退出ボタンは10秒後に表示されます',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
