// 認証サービス（Firebase Auth + ゲストモード）
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/nickname_generator.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  AppUser? _guestUser;

  AppUser? get currentUser {
    // Firebaseユーザーがいればそちらを優先
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser != null) return _mapFirebaseUser(fbUser);
    return _guestUser;
  }

  // Firebase User → AppUser変換
  AppUser _mapFirebaseUser(User user) {
    return AppUser(
      userId: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'ユーザー',
      email: user.email,
      emailVerified: user.emailVerified,
      isGuest: false,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  // メール/パスワードで新規登録
  Future<AppUser> signUpWithEmail(String email, String password, String displayName) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    await credential.user!.sendEmailVerification();
    await credential.user!.reload();
    return _mapFirebaseUser(_firebaseAuth.currentUser!);
  }

  // メール/パスワードでログイン
  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    if (!user.emailVerified) {
      throw EmailNotVerifiedException('メールアドレスが未認証です。メールを確認してください。');
    }
    return _mapFirebaseUser(user);
  }

  // 認証メール再送
  Future<void> resendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // メール認証状態を確認（リフレッシュ）
  Future<bool> checkEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser!.emailVerified;
  }

  // ゲストログイン
  Future<AppUser> signInAnonymously() async {
    _guestUser = AppUser(
      userId: const Uuid().v4(),
      displayName: generateNickname(),
      createdAt: DateTime.now(),
      isGuest: true,
    );
    return _guestUser!;
  }

  // ログアウト
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _guestUser = null;
  }

  // アプリ起動時の自動ログイン確認
  Future<AppUser?> getCurrentAuthUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && user.emailVerified) {
      return _mapFirebaseUser(user);
    }
    return null;
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // ユーザーデータ取得
  Future<AppUser?> getUserData(String userId) async {
    return currentUser;
  }

  // ユーザーをブロック
  Future<void> blockUser(String userId, String blockedUserId) async {
    if (_guestUser != null) {
      final newBlockedList = [..._guestUser!.blockedUserIds, blockedUserId];
      _guestUser = _guestUser!.copyWith(blockedUserIds: newBlockedList);
    }
  }
}

// メール未認証例外
class EmailNotVerifiedException implements Exception {
  final String message;
  EmailNotVerifiedException(this.message);
  @override
  String toString() => message;
}
