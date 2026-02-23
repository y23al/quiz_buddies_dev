// 設定画面
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

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
                            // アバター with gold border
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.goldPrimary, width: 2.5),
                                color: AppColors.surfaceCard2,
                              ),
                              child: Center(
                                child: Text(
                                  user?.displayName.isNotEmpty == true
                                      ? user!.displayName.substring(0, 1)
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.goldPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
