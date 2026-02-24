// 結果画面（正解数・ポイント・再試験判定・フレンド申請・全員完了でチャット遷移）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../services/friend_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final String? roomCode;
  final String subjectName;
  final int lectureNo;
  final int correctCount;
  final int totalQuestions;
  final int totalPoints;
  final List<Map<String, dynamic>> questions;
  final Map<int, String?> userAnswers;

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
    this.userAnswers = const {},
    bool isCorrect = false,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  final FriendService _friendService = FriendService();
  bool _showExitButton = false;
  bool _allCompleted = false;
  int _completedCount = 0;
  int _totalParticipants = 0;
  Timer? _exitTimer;
  StreamSubscription? _participantSubscription;

  // フレンド申請用
  List<Map<String, dynamic>> _otherParticipants = [];
  // userId → 'send' | 'sent' | 'friend' | 'received'
  final Map<String, String> _friendStates = {};

  // 正解率60%未満で再試験
  bool get _needsRetest =>
      widget.totalQuestions > 0 &&
      widget.correctCount / widget.totalQuestions < 0.6;

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
    final myUserId = ref.read(authProvider).user?.userId;

    _participantSubscription = _sessionService
        .watchParticipants(widget.sessionId)
        .listen((participants) {
      if (!mounted) return;

      final total = participants.length;
      final completed = participants
          .where((p) => p['quizCompleted'] == true)
          .length;

      // 他の参加者リスト更新（フレンド申請用）
      final others = participants
          .where((p) => p['odId'] != myUserId && p['odId'] != null)
          .toList();
      if (others.length != _otherParticipants.length) {
        _checkFriendStates(others, myUserId ?? '');
      }

      setState(() {
        _totalParticipants = total;
        _completedCount = completed;
        _otherParticipants = others;
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
              'userAnswers': widget.userAnswers,
              'subjectName': widget.subjectName,
              'lectureNo': widget.lectureNo,
            });
          }
        });
      }
    });
  }

  Future<void> _checkFriendStates(
      List<Map<String, dynamic>> others, String myUserId) async {
    for (final p in others) {
      final otherId = p['odId'] as String;
      if (_friendStates.containsKey(otherId)) continue;
      if (await _friendService.areFriends(myUserId, otherId)) {
        _friendStates[otherId] = 'friend';
      } else if (await _friendService.hasExistingRequest(myUserId, otherId)) {
        _friendStates[otherId] = 'sent';
      } else {
        _friendStates[otherId] = 'send';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendFriendRequest(String otherId, String otherName) async {
    final authState = ref.read(authProvider);
    if (authState.user == null || authState.user!.isGuest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ゲストユーザーはフレンド申請できません。ログインしてください。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      await _friendService.sendFriendRequest(
        fromUserId: authState.user!.userId,
        toUserId: otherId,
        fromDisplayName: authState.user!.displayName,
        toDisplayName: otherName,
        sessionId: widget.sessionId,
      );
      if (mounted) {
        setState(() => _friendStates[otherId] = 'sent');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$otherName にフレンド申請を送りました！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('フレンド申請に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Premium header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
                ),
                child: Row(
                  children: [
                    const Text(
                      '結果',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // スコア表示
                      PremiumCard(
                        type: PremiumCardType.light,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(
                              widget.subjectName,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textOnCard.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              '第${widget.lectureNo}回',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textOnCard.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${widget.correctCount} / ${widget.totalQuestions}',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: percentage >= 50
                                    ? AppColors.goldPrimary
                                    : AppColors.danger,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$percentage%正解',
                              style: TextStyle(
                                fontSize: 20,
                                color: AppColors.textOnCard.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Points badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.goldPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.goldPrimary),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: AppColors.goldPrimary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+${widget.totalPoints}pt',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.goldPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 再試験通知
                      if (_needsRetest)
                        PremiumCard(
                          type: PremiumCardType.dark,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: AppColors.danger),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '再試験対象です',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.danger,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '正解率60%未満のため、退出後に再試験があります',
                                      style: TextStyle(
                                        color: AppColors.danger.withValues(alpha: 0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 全員完了ステータス
                      PremiumCard(
                        type: PremiumCardType.dark,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            if (_allCompleted)
                              const Icon(Icons.check_circle, color: AppColors.goldPrimary)
                            else
                              const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.goldPrimary,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _allCompleted
                                  ? const Text(
                                      '全員回答完了！チャットに移動します...',
                                      style: TextStyle(
                                        color: AppColors.goldPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : Text(
                                      '回答完了: $_completedCount / $_totalParticipants人',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // フレンド申請セクション
                      if (_otherParticipants.isNotEmpty &&
                          !(ref.read(authProvider).user?.isGuest ?? true)) ...[
                        const SizedBox(height: 16),
                        _buildFriendRequestSection(),
                      ],

                      const SizedBox(height: 24),

                      // 復習ボタン（待ち時間中に復習可能）
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _goToReview,
                          icon: const Icon(Icons.school, color: AppColors.textOnCard),
                          label: const Text(
                            '待ち時間に復習する',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textOnCard,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldPrimary,
                            foregroundColor: AppColors.textOnCard,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                            ),
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
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      if (!_showExitButton)
                        const Text(
                          '退出ボタンは10秒後に表示されます',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
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

  Widget _buildFriendRequestSection() {
    return PremiumCard(
      type: PremiumCardType.dark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people, color: AppColors.goldPrimary, size: 22),
              SizedBox(width: 8),
              Text(
                'フレンド申請',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.goldPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._otherParticipants.map((p) {
            final otherId = p['odId'] as String;
            final name = p['displayName'] as String? ?? '???';
            final state = _friendStates[otherId] ?? 'send';
            final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.goldPrimary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnCard,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildFriendButton(state, otherId, name),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFriendButton(String state, String otherId, String name) {
    switch (state) {
      case 'friend':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.goldPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'フレンド',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.goldPrimary,
            ),
          ),
        );
      case 'sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '申請済み',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
        );
      default: // 'send'
        return ElevatedButton(
          onPressed: () => _sendFriendRequest(otherId, name),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldPrimary,
            foregroundColor: AppColors.textOnCard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'フレンド申請',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
    }
  }
}
