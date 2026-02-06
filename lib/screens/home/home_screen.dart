// ホーム画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  StreamSubscription<Map<String, dynamic>?>? _sessionSubscription;
  Map<String, dynamic>? _activeSession;
  int _remainingJoinTime = 0;
  Timer? _joinTimer;
  bool _isJoining = false;
  int _participantCount = 0;
  bool _hasJoinedSession = false;

  @override
  void initState() {
    super.initState();
    _watchActiveSession();
    // 自動的にセッションに参加（フレーム描画後に実行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoJoinSession();
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _joinTimer?.cancel();
    super.dispose();
  }

  void _watchActiveSession() {
    _sessionSubscription = _sessionService.watchActiveSession().listen((session) {
      if (mounted) {
        setState(() {
          _activeSession = session;
        });
        if (session != null) {
          _updateJoinTimer(session);
          _participantCount = session['participantCount'] ?? 0;
        }
      }
    });
  }

  void _updateJoinTimer(Map<String, dynamic> session) {
    final createdAt = session['createdAt'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - createdAt) / 1000;
    final remaining = (FirebaseSessionService.joinWindowSeconds - elapsed).ceil();

    if (remaining > 0 && remaining != _remainingJoinTime) {
      _joinTimer?.cancel();
      _remainingJoinTime = remaining;

      _joinTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _remainingJoinTime--;
          });
          if (_remainingJoinTime <= 0) {
            timer.cancel();
          }
        }
      });
    }
  }

  Future<void> _autoJoinSession() async {
    if (_isJoining || _hasJoinedSession) return;

    setState(() => _isJoining = true);

    try {
      final authState = ref.read(authProvider);
      if (authState.user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザー情報がありません')),
          );
          setState(() => _isJoining = false);
        }
        return;
      }

      // セッションを取得または作成
      final session = await _sessionService.getOrCreateActiveSession();
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('セッションを作成できませんでした')),
          );
          setState(() => _isJoining = false);
        }
        return;
      }

      // セッションに参加
      await _sessionService.joinSession(
        session['sessionId'],
        authState.user!.userId,
        authState.user!.displayName,
      );

      _hasJoinedSession = true;

      if (mounted) {
        // クイズ画面に遷移
        Navigator.pushNamed(
          context,
          '/quiz',
          arguments: {
            'sessionId': session['sessionId'],
            'sharedSession': session,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('接続エラー: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text(
          'Quiz Buddies',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ユーザー情報
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF4CAF50),
                        radius: 24,
                        child: Text(
                          authState.user?.displayName.substring(0, 1) ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.user?.displayName ?? 'ゲスト',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'ようこそ！',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // セッション状態表示
              _buildSessionStatusCard(),

              const Expanded(child: SizedBox()),

              // ネットワーク情報
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '同じWiFiの人と一緒にプレイ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              '自動的に同じクイズに参加します',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
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

  Widget _buildSessionStatusCard() {
    if (_isJoining) {
      // 接続中
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF4CAF50),
              ),
              const SizedBox(height: 24),
              const Text(
                'セッションに接続中...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '同じWiFiの参加者を探しています',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_activeSession != null && _remainingJoinTime > 0) {
      // アクティブセッションあり
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '参加募集中 $_remainingJoinTime秒',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_participantCount人参加中',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'クイズセッションが開催中！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '自動的にクイズ画面に移動します...',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                color: Colors.orange,
              ),
            ],
          ),
        ),
      );
    }

    // セッションなし - 再試行ボタン
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              '接続できませんでした',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ネットワークを確認してください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _hasJoinedSession = false;
                  _autoJoinSession();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '再接続する',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
