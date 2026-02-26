// アバター管理サービス（RTDB保存/読込）
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  // テンプレートアバターを保存
  Future<String> saveTemplateAvatar(String userId, String templateId) async {
    final avatarUrl = 'template:$templateId';
    await _db.child('user_profiles/$userId/avatarUrl').set(avatarUrl);
    return avatarUrl;
  }

  // 写真を選択してbase64エンコード → RTDB保存
  Future<String?> pickAndSavePhotoAvatar(String userId) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 128,
      maxHeight: 128,
      imageQuality: 70,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final b64 = base64Encode(bytes);
    final avatarUrl = 'data:image/jpeg;base64,$b64';

    await _db.child('user_profiles/$userId/avatarUrl').set(avatarUrl);
    return avatarUrl;
  }

  // アバターURLを取得
  Future<String?> getAvatarUrl(String userId) async {
    final snapshot = await _db.child('user_profiles/$userId/avatarUrl').get();
    return snapshot.value as String?;
  }

  // アバターを削除（デフォルトに戻す）
  Future<void> removeAvatar(String userId) async {
    await _db.child('user_profiles/$userId/avatarUrl').remove();
  }
}
