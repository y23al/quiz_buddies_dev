// ユーザーアバター共通ウィジェット
// avatarUrl: "template:xxx" → 絵文字表示, "data:image/..." → 写真表示, null → 頭文字表示
import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants/avatar_templates.dart';
import '../theme/design_tokens.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatarWidget({
    super.key,
    this.avatarUrl,
    required this.displayName,
    this.size = 44,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppColors.goldPrimary;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (avatarUrl!.startsWith('template:')) {
        return _buildTemplateAvatar(border);
      }
      if (avatarUrl!.startsWith('data:image')) {
        return _buildPhotoAvatar(border);
      }
    }

    return _buildInitialAvatar(border);
  }

  // 頭文字表示（デフォルト）
  Widget _buildInitialAvatar(Color border) {
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceCard2,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // テンプレート（絵文字+背景色）
  Widget _buildTemplateAvatar(Color border) {
    final templateId = avatarUrl!.replaceFirst('template:', '');
    final template = kAvatarTemplates.cast<AvatarTemplate?>().firstWhere(
          (t) => t!.id == templateId,
          orElse: () => null,
        );
    if (template == null) return _buildInitialAvatar(border);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: template.backgroundColor,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Center(
        child: Text(
          template.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  // 写真（base64デコード）
  Widget _buildPhotoAvatar(Color border) {
    try {
      final base64Data = avatarUrl!.split(',').last;
      final bytes = base64Decode(base64Data);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: borderWidth),
          image: DecorationImage(
            image: MemoryImage(bytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return _buildInitialAvatar(border);
    }
  }
}
