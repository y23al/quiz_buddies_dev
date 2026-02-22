// 認証プロバイダー
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// 認証状態
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final bool isEmailVerificationPending;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.isEmailVerificationPending = false,
  });

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool? isEmailVerificationPending,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      isEmailVerificationPending:
          isEmailVerificationPending ?? this.isEmailVerificationPending,
    );
  }
}

// 認証状態管理
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authService.getCurrentAuthUser();
      if (user != null) {
        state = AuthState(user: user, isAuthenticated: true, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // メール新規登録
  Future<void> signUpWithEmail(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user =
          await _authService.signUpWithEmail(email, password, displayName);
      state = AuthState(
        user: user,
        isLoading: false,
        isAuthenticated: false,
        isEmailVerificationPending: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e));
      rethrow;
    }
  }

  // メールログイン
  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.signInWithEmail(email, password);
      state = AuthState(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e));
      rethrow;
    }
  }

  // 認証メール再送
  Future<void> resendVerificationEmail() async {
    await _authService.resendVerificationEmail();
  }

  // メール認証状態確認
  Future<bool> checkEmailVerified() async {
    final verified = await _authService.checkEmailVerified();
    if (verified) {
      final user = _authService.currentUser;
      state = AuthState(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        isEmailVerificationPending: false,
      );
    }
    return verified;
  }

  // ゲストログイン
  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.signInAnonymously();
      state = AuthState(
        user: user,
        isLoading: false,
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void updateDisplayName(String name) {
    if (state.user != null) {
      final updated = state.user!.copyWith(displayName: name);
      state = state.copyWith(user: updated);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = AuthState(isLoading: false, isAuthenticated: false);
  }

  // Firebaseエラーコードを日本語に変換
  String _mapFirebaseError(Object e) {
    if (e is EmailNotVerifiedException) return e.message;
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'このメールアドレスは既に使用されています';
    }
    if (msg.contains('invalid-email')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (msg.contains('weak-password')) {
      return 'パスワードが短すぎます（6文字以上）';
    }
    if (msg.contains('user-not-found') || msg.contains('invalid-credential')) {
      return 'メールアドレスまたはパスワードが正しくありません';
    }
    if (msg.contains('wrong-password')) {
      return 'パスワードが正しくありません';
    }
    if (msg.contains('too-many-requests')) {
      return 'しばらくしてからもう一度お試しください';
    }
    return 'エラーが発生しました';
  }
}

// プロバイダー
final authServiceProvider = Provider((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
