// ホーム画面（Premium: Navy × Gold × Ivory）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../widgets/user_avatar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CsvImportService _csvService = CsvImportService();
  final FirebaseSessionService _sessionService = FirebaseSessionService();
  final TextEditingController _inviteCodeController = TextEditingController();
  UserProfile? _profile;
  final int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _csvService.importFromAsset('assets/karute_data.csv').ignore();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = ref.read(authProvider);
    if (authState.user != null) {
      final profile =
          await _sessionService.getUserProfile(authState.user!.userId);
      if (mounted) setState(() => _profile = profile);
    }
  }

  Future<void> _joinByInviteCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('6桁の招待番号を入力してください'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final session = await _sessionService.joinByRoomCode(code);
    if (session != null && mounted) {
      final authState = ref.read(authProvider);
      await _sessionService.joinSession(
        session['sessionId'],
        authState.user!.userId,
        authState.user!.displayName,
      );
      if (mounted) {
        Navigator.pushNamed(context, '/lobby', arguments: {
          'sessionId': session['sessionId'],
          'roomCode': code,
          'grade': session['grade'] ?? 0,
          'term': session['term'] ?? 0,
          'subjectId': session['subjectId'] ?? '',
          'subjectName': session['subjectName'] ?? '',
          'isHost': false,
        });
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('招待番号が無効か、募集が締め切られています'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    switch (index) {
      case 0:
        break; // 既にホーム
      case 1:
        Navigator.pushNamed(context, '/friends');
      case 2:
        Navigator.pushNamed(context, '/ranking');
      case 3:
        Navigator.pushNamed(context, '/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── App Header ──
              _buildHeader(),
              // ── Body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    8,
                    AppSpacing.screen,
                    AppSpacing.screen,
                  ),
                  child: Column(
                    children: [
                      _buildUserCard(authState),
                      const SizedBox(height: AppSpacing.gapLg),
                      _buildCreateRoomCard(),
                      const SizedBox(height: AppSpacing.gapLg),
                      _buildJoinRoomCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // ── Bottom Nav ──
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

  // ────────────────────────────────────────
  // Header
  // ────────────────────────────────────────
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
          // ロゴアイコン
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'QuizBuddies',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────
  // User Card（アイボリー）
  // ────────────────────────────────────────
  Widget _buildUserCard(AuthState authState) {
    final name = authState.user?.displayName ?? 'ゲスト';

    return PremiumCard(
      type: PremiumCardType.light,
      onTap: () => Navigator.pushNamed(context, '/settings'),
      child: Row(
        children: [
          // ゴールド縁のアバター
          UserAvatarWidget(
            avatarUrl: authState.user?.avatarUrl,
            displayName: name,
            size: 56,
            borderColor: AppColors.goldPrimary,
            borderWidth: 3,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleOnCard,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RankChip.tier(_profile?.tier ?? 'Bronze'),
                    const SizedBox(width: 8),
                    RankChip.points(_profile?.totalPoints ?? 0),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.goldDeep,
            size: 28,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────
  // メインCTA — ルームを作成
  // ────────────────────────────────────────
  Widget _buildCreateRoomCard() {
    return PremiumCard(
      type: PremiumCardType.dark,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/select-grade'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const GoldIconCircle(icon: Icons.add_rounded, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ルームを作成',
                        style: AppTextStyles.section.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '学年・学期・科目を選んでクイズを始めよう',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.goldPrimary,
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumButton(
            label: 'ルーム作成',
            onPressed: () => Navigator.pushNamed(context, '/select-grade'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────
  // 参加セクション — ルームに参加
  // ────────────────────────────────────────
  Widget _buildJoinRoomCard() {
    return PremiumCard(
      type: PremiumCardType.dark,
      child: Column(
        children: [
          Row(
            children: [
              const GoldIconCircle(
                  icon: Icons.people_alt_rounded, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ルームに参加',
                      style: AppTextStyles.section.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '招待番号を入力して参加しよう',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumTextField(
            controller: _inviteCodeController,
            hintText: '000000',
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 14),
          PremiumButton(
            label: '参加する',
            onPressed: _joinByInviteCode,
          ),
        ],
      ),
    );
  }
}
