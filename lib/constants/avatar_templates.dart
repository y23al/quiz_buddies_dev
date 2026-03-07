import 'package:flutter/material.dart';

class AvatarTemplate {
  final String id;
  final String emoji;
  final String label;
  final Color backgroundColor;

  const AvatarTemplate({
    required this.id,
    required this.emoji,
    required this.label,
    required this.backgroundColor,
  });
}

const kAvatarTemplates = [
  AvatarTemplate(id: 'cat', emoji: '🐱', label: 'ねこ', backgroundColor: Color(0xFFFFE0B2)),
  AvatarTemplate(id: 'dog', emoji: '🐶', label: 'いぬ', backgroundColor: Color(0xFFD7CCC8)),
  AvatarTemplate(id: 'rabbit', emoji: '🐰', label: 'うさぎ', backgroundColor: Color(0xFFF8BBD0)),
  AvatarTemplate(id: 'bear', emoji: '🐻', label: 'くま', backgroundColor: Color(0xFFBCAAA4)),
  AvatarTemplate(id: 'fox', emoji: '🦊', label: 'きつね', backgroundColor: Color(0xFFFFCC80)),
  AvatarTemplate(id: 'penguin', emoji: '🐧', label: 'ペンギン', backgroundColor: Color(0xFFB3E5FC)),
  AvatarTemplate(id: 'owl', emoji: '🦉', label: 'ふくろう', backgroundColor: Color(0xFFD1C4E9)),
  AvatarTemplate(id: 'panda', emoji: '🐼', label: 'パンダ', backgroundColor: Color(0xFFE0E0E0)),
  AvatarTemplate(id: 'star', emoji: '⭐', label: 'スター', backgroundColor: Color(0xFFFFF9C4)),
  AvatarTemplate(id: 'fire', emoji: '🔥', label: 'ファイア', backgroundColor: Color(0xFFFFCDD2)),
  AvatarTemplate(id: 'bolt', emoji: '⚡', label: 'ボルト', backgroundColor: Color(0xFFFFF176)),
  AvatarTemplate(id: 'rocket', emoji: '🚀', label: 'ロケット', backgroundColor: Color(0xFFB2DFDB)),
  AvatarTemplate(id: 'crown', emoji: '👑', label: 'クラウン', backgroundColor: Color(0xFFFFE082)),
  AvatarTemplate(id: 'gem', emoji: '💎', label: 'ダイヤ', backgroundColor: Color(0xFFB2EBF2)),
  AvatarTemplate(id: 'music', emoji: '🎵', label: 'ミュージック', backgroundColor: Color(0xFFCE93D8)),
  AvatarTemplate(id: 'book', emoji: '📚', label: 'ブック', backgroundColor: Color(0xFFA5D6A7)),
];
