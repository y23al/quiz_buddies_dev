// ディープリンクからのルーム参加リダイレクト画面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../main.dart' show pendingRoomCode;

class JoinRedirectScreen extends ConsumerStatefulWidget {
  const JoinRedirectScreen({super.key});

  @override
  ConsumerState<JoinRedirectScreen> createState() => _JoinRedirectScreenState();
}

class _JoinRedirectScreenState extends ConsumerState<JoinRedirectScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  bool _navigated = false;

  Future<void> _attemptJoin() async {
    if (_navigated) return;
    _navigated = true;

    final code = pendingRoomCode;
    if (code == null || code.isEmpty) {
      pendingRoomCode = null;
      _goHome();
      return;
    }

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.user == null) {
      // 未認証 → 認証画面へ（pendingRoomCode は保持したまま）
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    // 認証済み → ルームに参加
    try {
      final session = await _sessionService.joinByRoomCode(code);
      if (session != null && mounted) {
        await _sessionService.joinSession(
          session['sessionId'],
          authState.user!.userId,
          authState.user!.displayName,
        );
        // 参加成功後にコードを消費
        pendingRoomCode = null;
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/lobby', arguments: {
            'sessionId': session['sessionId'],
            'roomCode': code,
            'grade': session['grade'] ?? 0,
            'term': session['term'] ?? 0,
            'subjectId': session['subjectId'] ?? '',
            'subjectName': session['subjectName'] ?? '',
            'isHost': false,
          });
        }
      } else {
        pendingRoomCode = null;
        _showErrorAndGoHome();
      }
    } catch (_) {
      pendingRoomCode = null;
      _showErrorAndGoHome();
    }
  }

  void _showErrorAndGoHome() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('招待リンクが無効か、募集が締め切られています'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    // Auth状態を監視 — isLoading が false に確定してから _attemptJoin を実行
    final authState = ref.watch(authProvider);
    if (!_navigated && !authState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_navigated) _attemptJoin();
      });
    }

    return Scaffold(
      body: StarryBackground(
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.goldPrimary),
              SizedBox(height: 16),
              Text(
                'ルームに参加中...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}