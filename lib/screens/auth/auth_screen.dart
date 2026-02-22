// 認証画面（ログイン/新規登録/メール認証/ゲスト）
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

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
        Navigator.pushReplacementNamed(context, '/home');
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
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final verified =
          await ref.read(authProvider.notifier).checkEmailVerified();
      if (verified && mounted) {
        _verificationTimer?.cancel();
        Navigator.pushReplacementNamed(context, '/home');
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
    } catch (_) {
      // エラーはauthStateに反映済み
    }
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // メール未認証の場合は認証画面に切り替え
      if (e.toString().contains('未認証')) {
        if (mounted) {
          setState(() => _mode = AuthMode.verifyEmail);
          _startVerificationPolling();
        }
      }
    }
  }

  Future<void> _handleGuest() async {
    try {
      await ref.read(authProvider.notifier).signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ログインに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // ヘッダー
                      const Text(
                        'Quiz Buddies',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'みんなで学ぶ、教え合う',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 32),

                      // メインコンテンツ
                      if (_mode == AuthMode.verifyEmail)
                        _buildVerificationCard(authState)
                      else
                        _buildAuthForm(authState),

                      const SizedBox(height: 24),

                      // ゲストボタン
                      if (_mode != AuthMode.verifyEmail)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: authState.isLoading ? null : _handleGuest,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              'ゲストとして始める',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),
                      const Text(
                        '利用を開始することで、利用規約に同意したものとみなされます',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
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
    );
  }

  Widget _buildAuthForm(AuthState authState) {
    final isLogin = _mode == AuthMode.login;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isLogin ? 'ログイン' : '新規登録',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // エラー表示
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    authState.error!,
                    style: TextStyle(color: Colors.red[700], fontSize: 14),
                  ),
                ),

              // 表示名（新規登録のみ）
              if (!isLogin) ...[
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: '表示名',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '表示名を入力してください';
                    if (v.trim().length > 20) return '20文字以内で入力してください';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // メール
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'メールアドレス',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'メールアドレスの形式が正しくありません';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // パスワード
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'パスワードを入力してください';
                  if (v.length < 6) return '6文字以上で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // アクションボタン
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading
                      ? null
                      : (isLogin ? _handleSignIn : _handleSignUp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isLogin ? 'ログイン' : '新規登録',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // モード切替
              TextButton(
                onPressed: () {
                  setState(() {
                    _mode =
                        isLogin ? AuthMode.signUp : AuthMode.login;
                  });
                },
                child: Text(
                  isLogin
                      ? 'アカウントをお持ちでない方はこちら'
                      : '既にアカウントをお持ちの方はこちら',
                  style: const TextStyle(color: Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(AuthState authState) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read, size: 64, color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            const Text(
              'メール認証が必要です',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${_emailController.text.trim()} に\n認証メールを送信しました',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'メールを確認して認証リンクをクリックしてください',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            // 迷惑メール注意
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'メールが届かない場合、迷惑メールフォルダもご確認ください。\n送信元: noreply@quiz-buddies-3a96c.firebaseapp.com',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 4),
            Text(
              '認証を自動で確認中...',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(authProvider.notifier).resendVerificationEmail();
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
                  foregroundColor: const Color(0xFF4CAF50),
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
              child: const Text('ログイン画面に戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
