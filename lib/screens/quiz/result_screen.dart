// 結果画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isCorrect;

  const ResultScreen({
    super.key,
    required this.sessionId,
    required this.isCorrect,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  Timer? _timer;
  int _remainingSeconds = 5;

  @override
  void initState() {
    super.initState();
    _startTimer();
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
        _navigateToRoom();
      }
    });
  }

  void _navigateToRoom() {
    Navigator.pushReplacementNamed(
      context,
      '/group-room',
      arguments: {
        'sessionId': widget.sessionId,
        'isCorrect': widget.isCorrect,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isCorrect ? Colors.green[50] : Colors.red[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アイコン
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: widget.isCorrect ? const Color(0xFF4CAF50) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isCorrect ? Icons.check : Icons.close,
                    size: 64,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // 結果テキスト
                Text(
                  widget.isCorrect ? '正解！' : '不正解...',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: widget.isCorrect ? const Color(0xFF4CAF50) : Colors.red,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  widget.isCorrect
                      ? 'おめでとうございます！\n正解者ルームに移動します'
                      : 'ドンマイ！\n不正解者ルームに移動します',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // カウントダウン
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$_remainingSeconds秒後に移動...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // スキップボタン
                TextButton(
                  onPressed: _navigateToRoom,
                  child: Text(
                    '今すぐ移動',
                    style: TextStyle(
                      color: widget.isCorrect ? const Color(0xFF4CAF50) : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
