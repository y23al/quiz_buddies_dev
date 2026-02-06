// ロビー画面（参加者待機）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/services.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic> sharedSession;

  const LobbyScreen({
    super.key,
    required this.sessionId,
    required this.sharedSession,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  int _participantCount = 1;
  StreamSubscription<Map<String, dynamic>?>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _watchSession();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _startQuiz();
        }
      }
    });
  }

  void _watchSession() {
    _sessionSubscription = _sessionService.watchCurrentSession().listen((session) {
      if (mounted && session != null) {
        setState(() {
          _participantCount = session['participantCount'] ?? 1;
        });
      }
    });
  }

  void _startQuiz() {
    if (mounted) {
      // フェーズを更新
      _sessionService.updatePhase(widget.sessionId, 'quiz');

      Navigator.pushReplacementNamed(
        context,
        '/quiz',
        arguments: {
          'sessionId': widget.sessionId,
          'sharedSession': widget.sharedSession,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomCode = widget.sharedSession['roomCode'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          '参加者を待っています',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // カウントダウン表示
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 10
                            ? Colors.orange
                            : const Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      '秒',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 参加者数
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people,
                        size: 32,
                        color: Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_participantCount人',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '参加中',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ルームコード表示
              if (roomCode != null)
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'ルームコード',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          roomCode,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '友達にこのコードを共有しよう！',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // 今すぐ開始ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '今すぐ開始',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // キャンセルボタン
              TextButton(
                onPressed: () {
                  _sessionService.clearSession();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
                child: Text(
                  'キャンセル',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
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
