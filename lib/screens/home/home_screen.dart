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
  bool? _isWifiAvailable;
  String? _wifiName;
  String? _currentRoomCode;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // WiFi情報をチェックしてから処理を開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWifiAndStart();
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _joinTimer?.cancel();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkWifiAndStart() async {
    final isAvailable = await _sessionService.isWifiAvailable();
    final wifiName = await _sessionService.getWifiName();

    if (mounted) {
      setState(() {
        _isWifiAvailable = isAvailable;
        _wifiName = wifiName;
      });

      if (isAvailable) {
        // WiFi利用可能：自動でセッションに参加
        _watchActiveSession();
        _autoJoinSession();
      }
      // WiFi利用不可：ルームコード入力を待つ
    }
  }

  void _watchActiveSession({String? roomCode}) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _sessionService.watchActiveSession(roomCode: roomCode).listen((session) {
      if (mounted) {
        setState(() {
          _activeSession = session;
          if (session != null) {
            _currentRoomCode = session['roomCode'] as String?;
          }
        });
        if (session != null) {
          _updateJoinTimer(session);
          _participantCount = session['participantCount'] ?? 0;
        }
      }
    });
  }

  void _updateJoinTimer(Map<String, dynamic> session) {
    final createdAt = session['createdAt'] as int?;
    if (createdAt == null) return;

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

  Future<void> _autoJoinSession({String? roomCode}) async {
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
      final session = await _sessionService.getOrCreateActiveSession(roomCode: roomCode);
      if (session == null) {
        if (mounted) {
          if (roomCode != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ルームコードが無効か、参加時間が過ぎています')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('セッションを作成できませんでした')),
            );
          }
          setState(() => _isJoining = false);
        }
        return;
      }

      // ルームコードを保存
      setState(() {
        _currentRoomCode = session['roomCode'] as String?;
      });

      // セッションに参加
      await _sessionService.joinSession(
        session['sessionId'],
        authState.user!.userId,
        authState.user!.displayName,
      );

      _hasJoinedSession = true;

      if (mounted) {
        // ロビー画面に遷移（30秒待機）
        Navigator.pushNamed(
          context,
          '/lobby',
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

  Future<void> _joinByRoomCode() async {
    final code = _roomCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6桁のルームコードを入力してください')),
      );
      return;
    }

    _watchActiveSession(roomCode: code);
    await _autoJoinSession(roomCode: code);
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
              _buildNetworkInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkInfoCard() {
    if (_isWifiAvailable == true && _wifiName != null) {
      return Card(
        color: Colors.green[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.wifi, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WiFi: $_wifiName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      '同じWiFiの人と自動でマッチング',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WiFi情報を取得できません',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  Text(
                    'ルームコードを使って参加してください',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStatusCard() {
    // WiFi利用不可の場合：ルームコード入力画面
    if (_isWifiAvailable == false) {
      return _buildRoomCodeInputCard();
    }

    // WiFiチェック中
    if (_isWifiAvailable == null) {
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
                'ネットワークを確認中...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
              if (_currentRoomCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ルームコード',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                            ),
                            Text(
                              _currentRoomCode!,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'このコードを友達に共有して参加してもらえます',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
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

  Widget _buildRoomCodeInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.meeting_room,
              size: 64,
              color: Colors.blue[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'ルームコードで参加',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '友達からもらったルームコードを入力してください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _roomCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  letterSpacing: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinByRoomCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '参加する',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'または',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isJoining
                    ? null
                    : () async {
                        // 新しいルームを作成
                        setState(() => _isJoining = true);
                        final authState = ref.read(authProvider);
                        if (authState.user == null) {
                          setState(() => _isJoining = false);
                          return;
                        }

                        // 新しいルームを作成（コードは自動生成）
                        final session = await _sessionService.createNewRoom();
                        if (session != null) {
                          final roomCode = session['roomCode'] as String?;
                          setState(() {
                            _currentRoomCode = roomCode;
                          });
                          _watchActiveSession(roomCode: roomCode);

                          await _sessionService.joinSession(
                            session['sessionId'],
                            authState.user!.userId,
                            authState.user!.displayName,
                          );

                          _hasJoinedSession = true;

                          if (mounted) {
                            Navigator.pushNamed(
                              context,
                              '/lobby',
                              arguments: {
                                'sessionId': session['sessionId'],
                                'sharedSession': session,
                              },
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ルーム作成に失敗しました')),
                            );
                          }
                        }
                        setState(() => _isJoining = false);
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '新しいルームを作成',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
