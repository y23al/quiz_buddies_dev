// 設定画面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/avatar_templates.dart';
import '../../providers/auth_provider.dart';
import '../../services/avatar_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../widgets/user_avatar_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  final AvatarService _avatarService = AvatarService();
  bool _isAvatarLoading = false;

  @override
  void initState() {
    super.initState();
    final name = ref.read(authProvider).user?.displayName ?? '';
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ref.read(authProvider.notifier).updateDisplayName(name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('表示名を更新しました'),
        backgroundColor: AppColors.goldDeep,
      ),
    );
  }

  Future<void> _showAvatarPicker() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final isGuest = user.isGuest;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ドラッグハンドル
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'アイコンを変更',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // 写真を選択ボタン（ゲストは不可）
              if (!isGuest)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _pickPhotoAvatar();
                    },
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text('写真を選択'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldPrimary,
                      side: const BorderSide(color: AppColors.goldPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                  ),
                ),
              if (!isGuest) const SizedBox(height: 16),

              // テンプレート一覧
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'テンプレート',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: kAvatarTemplates.length,
                  itemBuilder: (_, i) {
                    final t = kAvatarTemplates[i];
                    final isSelected = user.avatarUrl == 'template:${t.id}';
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectTemplate(t.id);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.backgroundColor,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.goldPrimary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? AppColors.goldPrimary
                                  : AppColors.textMuted,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // デフォルトに戻す
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
                child: const Text(
                  'デフォルトに戻す',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTemplate(String templateId) async {
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) return;
    setState(() => _isAvatarLoading = true);
    try {
      final avatarUrl = await _avatarService.saveTemplateAvatar(userId, templateId);
      ref.read(authProvider.notifier).updateAvatarUrl(avatarUrl);
    } catch (_) {}
    if (mounted) setState(() => _isAvatarLoading = false);
  }

  Future<void> _pickPhotoAvatar() async {
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) return;
    setState(() => _isAvatarLoading = true);
    try {
      final avatarUrl = await _avatarService.pickAndSavePhotoAvatar(userId);
      if (avatarUrl != null) {
        ref.read(authProvider.notifier).updateAvatarUrl(avatarUrl);
      }
    } catch (_) {}
    if (mounted) setState(() => _isAvatarLoading = false);
  }

  Future<void> _removeAvatar() async {
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) return;
    setState(() => _isAvatarLoading = true);
    try {
      await _avatarService.removeAvatar(userId);
      ref.read(authProvider.notifier).updateAvatarUrl(null);
    } catch (_) {}
    if (mounted) setState(() => _isAvatarLoading = false);
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.lineGold, width: 1),
        ),
        title: const Text('ログアウト', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'ログアウトしますか？データはリセットされます。',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
              Navigator.pushNamedAndRemoveUntil(
                this.context,
                '/auth',
                (route) => false,
              );
            },
            child: const Text('ログアウト', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Premium header
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.lineGold, width: 0.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24),
        ),
        const SizedBox(width: 12),
        const Text(
          '設定',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ]),
    );

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),

                    // プロフィールセクション
                    _SectionHeader(title: 'プロフィール'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: PremiumCard(
                        type: PremiumCardType.dark,
                        child: Column(
                          children: [
                            // アバター with 編集オーバーレイ
                            GestureDetector(
                              onTap: _showAvatarPicker,
                              child: Stack(
                                children: [
                                  _isAvatarLoading
                                      ? Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.surfaceCard2,
                                            border: Border.all(
                                              color: AppColors.goldPrimary,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.goldPrimary,
                                              ),
                                            ),
                                          ),
                                        )
                                      : UserAvatarWidget(
                                          avatarUrl: user?.avatarUrl,
                                          displayName: user?.displayName ?? '?',
                                          size: 80,
                                          borderColor: AppColors.goldPrimary,
                                          borderWidth: 2.5,
                                        ),
                                  // 編集アイコン
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.goldPrimary,
                                        border: Border.all(
                                          color: AppColors.bgBase,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: AppColors.textOnCard,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 表示名編集
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                              decoration: InputDecoration(
                                labelText: '表示名',
                                labelStyle: const TextStyle(color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.surfaceCard2,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  borderSide: const BorderSide(color: AppColors.lineGold),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  borderSide: BorderSide(color: AppColors.lineGold.withValues(alpha: 0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  borderSide: const BorderSide(color: AppColors.goldPrimary, width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.check, color: AppColors.goldPrimary),
                                  onPressed: _saveName,
                                ),
                              ),
                              onSubmitted: (_) => _saveName(),
                            ),
                            const SizedBox(height: 12),

                            // ユーザーID
                            Row(
                              children: [
                                const Text(
                                  'ユーザーID',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    user?.userId ?? '-',
                                    style: TextStyle(
                                      color: AppColors.textMuted.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // アプリ情報セクション
                    _SectionHeader(title: 'アプリ情報'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: PremiumCard(
                        type: PremiumCardType.dark,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline,
                              title: 'バージョン',
                              trailing: const Text(
                                '1.0.0',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                            Divider(height: 1, color: AppColors.lineGold.withValues(alpha: 0.3)),
                            _SettingsTile(
                              icon: Icons.quiz_outlined,
                              title: 'クイズ問題数',
                              trailing: const Text(
                                '48問',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                            Divider(height: 1, color: AppColors.lineGold.withValues(alpha: 0.3)),
                            _SettingsTile(
                              icon: Icons.timer_outlined,
                              title: 'クイズ制限時間',
                              trailing: const Text(
                                '30秒',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // アカウントセクション
                    _SectionHeader(title: 'アカウント'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: PremiumCard(
                        type: PremiumCardType.dark,
                        padding: EdgeInsets.zero,
                        child: _SettingsTile(
                          icon: Icons.logout,
                          title: 'ログアウト',
                          titleColor: AppColors.danger,
                          iconColor: AppColors.danger,
                          onTap: _confirmSignOut,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.goldPrimary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.goldPrimary),
      title: Text(
        title,
        style: TextStyle(color: titleColor ?? AppColors.textPrimary),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textMuted) : null),
      onTap: onTap,
    );
  }
}
