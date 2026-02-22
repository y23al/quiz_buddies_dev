// ランキング画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  List<UserProfile> _profiles = [];
  bool _isLoading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _sessionService.watchAllUserProfiles().listen((profiles) {
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.userId;
    final myIndex = _profiles.indexWhere((p) => p.userId == currentUserId);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        title: const Text('ランキング', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : Column(
              children: [
                // 自分のランクカード
                if (myIndex >= 0)
                  _buildMyRankCard(_profiles[myIndex], myIndex + 1),

                // リーダーボード
                Expanded(
                  child: _profiles.isEmpty
                      ? const Center(child: Text('ランキングデータがありません'))
                      : ListView.builder(
                          itemCount: _profiles.length,
                          itemBuilder: (context, index) {
                            final profile = _profiles[index];
                            final isMe = profile.userId == currentUserId;
                            return _buildRankTile(profile, index + 1, isMe);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMyRankCard(UserProfile profile, int position) {
    final tierColor = Color(profile.tierColorValue);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '#$position',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTierBadge(profile.tier, tierColor),
                          const SizedBox(width: 8),
                          Text(
                            '${profile.totalPoints}pt',
                            style: TextStyle(
                              color: tierColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (profile.pointsToNextTier > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: profile.tierProgress,
                  backgroundColor: Colors.grey[200],
                  color: tierColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '次のティアまであと${profile.pointsToNextTier}pt',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRankTile(UserProfile profile, int position, bool isMe) {
    final tierColor = Color(profile.tierColorValue);

    return Container(
      color: isMe ? tierColor.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: SizedBox(
          width: 40,
          child: Center(
            child: position <= 3
                ? Icon(
                    Icons.emoji_events,
                    color: position == 1
                        ? const Color(0xFFFFD700)
                        : position == 2
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFCD7F32),
                    size: 28,
                  )
                : Text(
                    '#$position',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        title: Text(
          profile.displayName,
          style: TextStyle(
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          children: [
            _buildTierBadge(profile.tier, tierColor),
            const SizedBox(width: 8),
            Text('正解率 ${(profile.correctRate * 100).toStringAsFixed(0)}%'),
          ],
        ),
        trailing: Text(
          '${profile.totalPoints}pt',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tierColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tier, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        tier,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
