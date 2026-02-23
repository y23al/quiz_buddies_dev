// QuizBuddies Design Tokens — Premium Navy × Gold × Ivory
import 'package:flutter/material.dart';

// ──────────────────────────────────────────
// Colors
// ──────────────────────────────────────────
class AppColors {
  AppColors._();

  // Background
  static const bgBase = Color(0xFF0B1020);
  static const bgGradientTop = Color(0xFF111B33);
  static const bgGradientBottom = Color(0xFF070B14);

  // Surface
  static const surfaceCard = Color(0xFFF3EADF); // アイボリー
  static const surfaceCard2 = Color(0x14FFFFFF); // 半透明ホワイト 8%

  // Text
  static const textPrimary = Color(0xFFF8F1E6); // 明るいアイボリー
  static const textOnCard = Color(0xFF1A1A1A); // カード上の濃色
  static const textMuted = Color(0x80F8F1E6); // 50% opacity

  // Gold
  static const goldPrimary = Color(0xFFD6B56D);
  static const goldDeep = Color(0xFFB48A3C);
  static const lineGold = Color(0xBFD6B56D); // 75% opacity

  // Accent
  static const accentBlue = Color(0xFF2F6BFF);
  static const danger = Color(0xFFD04B4B);

  // Bottom Nav
  static const navBg = Color(0xFF080E1E);
}

// Background gradient
const kBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.bgGradientTop, AppColors.bgBase, AppColors.bgGradientBottom],
);

// Gold button gradient
const kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE0C47A), AppColors.goldPrimary, AppColors.goldDeep],
);

// ──────────────────────────────────────────
// Radius
// ──────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const double card = 20;
  static const double button = 16;
  static const double chip = 999;
}

// ──────────────────────────────────────────
// Shadows
// ──────────────────────────────────────────
class AppShadows {
  AppShadows._();
  static const card = [
    BoxShadow(color: Color(0x59000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const button = [
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

// ──────────────────────────────────────────
// Spacing
// ──────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double screen = 16;
  static const double card = 16;
  static const double gap = 12;
  static const double gapLg = 16;
}

// ──────────────────────────────────────────
// Text Styles
// ──────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const title = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const section = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static const caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted,
  );

  // Card上のテキスト
  static const titleOnCard = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textOnCard,
  );
  static const bodyOnCard = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textOnCard,
  );

  // Gold text
  static const goldTitle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.goldPrimary,
  );
  static const goldButton = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textOnCard,
    letterSpacing: 1,
  );
}

// ──────────────────────────────────────────
// Border
// ──────────────────────────────────────────
const kGoldBorder = BorderSide(color: AppColors.lineGold, width: 1.5);
