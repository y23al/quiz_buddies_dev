// フレンド一覧画面（申請管理 + フレンドチャットへの導線）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/friend_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../widgets/user_avatar_widget.dart';

class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  final FriendService _friendService = FriendService();
  final int _navIndex = 1; // チャットタブ

  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _friends = [];
  StreamSubscription? _requestsSub;
  StreamSubscription? _friendsSub;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    _friendsSub?.cancel();
    super.dispose();
  }

  void _startListening() {
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) return;

    _requestsSub = _friendService.watchIncomingRequests(userId).listen((data) {
      if (mounted) setState(() => _incomingRequests = data);
    });

    _friendsSub = _friendService.watchFriends(userId).listen((data) {
      if (mounted) setState(() => _friends = data);
    });
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      case 2:
        Navigator.pushNamed(context, '/ranking');
      case 3:
        Navigator.pushNamed(context, '/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _incomingRequests.isEmpty && _friends.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.screen),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_incomingRequests.isNotEmpty) ...[
                              _buildSectionTitle('フレンド申請'),
                              const SizedBox(height: 8),
                              ..._incomingRequests
                                  .map(_buildRequestCard),
                              const SizedBox(height: 20),
                            ],
                            if (_friends.isNotEmpty) ...[
                              _buildSectionTitle('フレンド'),
                              const SizedBox(height: 8),
                              ..._friends.map(_buildFriendCard),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
              PremiumBottomNav(
                currentIndex: _navIndex,
                onTap: _onNavTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lineGold, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'フレンド',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 申請バッジ
          if (_incomingRequests.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldPrimary,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                '${_incomingRequests.length}件',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnCard,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.section.copyWith(color: AppColors.goldPrimary),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: AppColors.textPrimary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'まだフレンドがいません',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'クイズに参加してフレンド申請を送ろう！',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final name = request['fromDisplayName'] as String? ?? '???';
    final requestId = request['requestId'] as String;
    final avatarUrl = request['fromAvatarUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        type: PremiumCardType.dark,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // アバター
            UserAvatarWidget(
              avatarUrl: avatarUrl,
              displayName: name,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.section.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'フレンド申請が届いています',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            // 承認ボタン
            GestureDetector(
              onTap: () async {
                await _friendService.acceptRequest(requestId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name とフレンドになりました！'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: kGoldGradient,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: const Text(
                  '承認',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnCard,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 拒否ボタン
            GestureDetector(
              onTap: () async {
                await _friendService.rejectRequest(requestId);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.textMuted, width: 1),
                ),
                child: Text(
                  '拒否',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final name = friend['displayName'] as String? ?? '???';
    final friendUserId = friend['userId'] as String;
    final avatarUrl = friend['avatarUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumCard(
        type: PremiumCardType.dark,
        padding: const EdgeInsets.all(14),
        onTap: () {
          Navigator.pushNamed(context, '/friend-chat', arguments: {
            'friendUserId': friendUserId,
            'friendDisplayName': name,
          });
        },
        child: Row(
          children: [
            // アバター
            UserAvatarWidget(
              avatarUrl: avatarUrl,
              displayName: name,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.section.copyWith(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.goldPrimary,
              size: 22,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.goldPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
