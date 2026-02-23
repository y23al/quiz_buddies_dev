// 認証画面（ログイン/新規登録/メール認証/ゲスト）— Premium Design
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/premium_components.dart';
import '../../main.dart' show pendingRoomCode;

enum AuthMode { login, signUp, verifyEmail }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated && authState.user != null) {
        Navigator.pushReplacementNamed(
          context, pendingRoomCode != null ? '/join' : '/home',
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startVerificationPolling() {
    _verificationTimer?.cancel();
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      final verified =
          await ref.read(authProvider.notifier).checkEmailVerified();
      if (verified && mounted) {
        _verificationTimer?.cancel();
        Navigator.pushReplacementNamed(
          context, pendingRoomCode != null ? '/join' : '/home',
        );
      }
    });
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
            _displayNameController.text.trim(),
          );
      if (mounted) {
        setState(() => _mode = AuthMode.verifyEmail);
        _startVerificationPolling();
      }
    } catch (_) {}
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        Navigator.pushReplacementNamed(
          context, pendingRoomCode != null ? '/join' : '/home',
        );
      }
    } catch (e) {
      if (e.toString().contains('未認証') && mounted) {
        setState(() => _mode = AuthMode.verifyEmail);
        _startVerificationPolling();
      }
    }
  }

  Future<void> _handleGuest() async {
    try {
      await ref.read(authProvider.notifier).signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context, pendingRoomCode != null ? '/join' : '/home',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ログインに失敗しました: $e')),
        );
      }
    }
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.goldPrimary),
      filled: true,
      fillColor: AppColors.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.lineGold, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.lineGold, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide:
            const BorderSide(color: AppColors.goldPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // ロゴ
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A3A6A), Color(0xFF0E2045)],
                            ),
                            border: Border.all(
                                color: AppColors.goldPrimary, width: 2),
                          ),
                          child: const Center(
                            child: Text('Q',
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.goldPrimary)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'QuizBuddies',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'みんなで学ぶ、教え合う',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 32),

                        if (_mode == AuthMode.verifyEmail)
                          _buildVerificationCard(authState)
                        else
                          _buildAuthForm(authState),

                        const SizedBox(height: 20),

                        if (_mode != AuthMode.verifyEmail) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed:
                                  authState.isLoading ? null : _handleGuest,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: AppColors.goldPrimary
                                        .withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.chip),
                                ),
                              ),
                              child: const Text(
                                'ゲストとして始める',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.goldPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          '利用を開始することで、利用規約に同意したものとみなされます',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.35)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm(AuthState authState) {
    final isLogin = _mode == AuthMode.login;

    return PremiumCard(
      type: PremiumCardType.light,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isLogin ? 'ログイン' : '新規登録',
              style: AppTextStyles.titleOnCard.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (authState.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  authState.error!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 14),
                ),
              ),

            if (!isLogin) ...[
              TextFormField(
                controller: _displayNameController,
                style: const TextStyle(color: AppColors.textOnCard),
                decoration: _inputDeco('表示名', Icons.person),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '表示名を入力してください';
                  if (v.trim().length > 20) return '20文字以内で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textOnCard),
              decoration: _inputDeco('メールアドレス', Icons.email),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'メールアドレスを入力してください';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'メールアドレスの形式が正しくありません';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppColors.textOnCard),
              decoration: _inputDeco('パスワード', Icons.lock).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.goldDeep,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'パスワードを入力してください';
                if (v.length < 6) return '6文字以上で入力してください';
                return null;
              },
            ),
            const SizedBox(height: 24),

            PremiumButton(
              label: isLogin ? 'ログイン' : '新規登録',
              onPressed: authState.isLoading
                  ? null
                  : (isLogin ? _handleSignIn : _handleSignUp),
            ),
            const SizedBox(height: 14),

            TextButton(
              onPressed: () {
                setState(() {
                  _mode = isLogin ? AuthMode.signUp : AuthMode.login;
                });
              },
              child: Text(
                isLogin ? 'アカウントをお持ちでない方はこちら' : '既にアカウントをお持ちの方はこちら',
                style: const TextStyle(color: AppColors.goldPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(AuthState authState) {
    return PremiumCard(
      type: PremiumCardType.light,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read,
              size: 64, color: AppColors.goldPrimary),
          const SizedBox(height: 16),
          Text('メール認証が必要です',
              style: AppTextStyles.titleOnCard.copyWith(fontSize: 22)),
          const SizedBox(height: 12),
          Text(
            '${_emailController.text.trim()} に\n認証メールを送信しました',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text('メールを確認して認証リンクをクリックしてください',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.goldPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.goldDeep, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'メールが届かない場合、迷惑メールフォルダもご確認ください。\n送信元: noreply@quiz-buddies-3a96c.firebaseapp.com',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.goldPrimary),
          ),
          const SizedBox(height: 4),
          Text('認証を自動で確認中...',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref
                      .read(authProvider.notifier)
                      .resendVerificationEmail();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('認証メールを再送しました')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('再送に失敗しました: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('認証メールを再送する'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.goldPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _verificationTimer?.cancel();
              setState(() => _mode = AuthMode.login);
            },
            child: const Text('ログイン画面に戻る',
                style: TextStyle(color: AppColors.goldDeep)),
          ),
        ],
      ),
    );
  }
}
