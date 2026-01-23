// 認証サービス
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/nickname_generator.dart';

// デモモードフラグ
bool isDemoMode = true;

// デモユーザー
AppUser? _demoUser;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? get currentUser => _demoUser;

  // 匿名ログイン
  Future<AppUser> signInAnonymously() async {
    if (isDemoMode) {
      _demoUser = AppUser(
        userId: const Uuid().v4(),
        displayName: generateNickname(),
        createdAt: DateTime.now(),
        blockedUserIds: [],
      );
      return _demoUser!;
    }

    // TODO: Firebase Auth実装
    throw UnimplementedError('Firebase Auth not implemented');
  }

  // ログアウト
  Future<void> signOut() async {
    _demoUser = null;
  }

  // ユーザーデータ取得
  Future<AppUser?> getUserData(String userId) async {
    if (isDemoMode) {
      return _demoUser;
    }
    // TODO: Firestore実装
    return null;
  }

  // ユーザーをブロック
  Future<void> blockUser(String userId, String blockedUserId) async {
    if (isDemoMode && _demoUser != null) {
      final newBlockedList = [..._demoUser!.blockedUserIds, blockedUserId];
      _demoUser = AppUser(
        userId: _demoUser!.userId,
        displayName: _demoUser!.displayName,
        createdAt: _demoUser!.createdAt,
        blockedUserIds: newBlockedList,
      );
    }
  }
}
