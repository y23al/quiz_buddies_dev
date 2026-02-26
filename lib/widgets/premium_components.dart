// QuizBuddies — 再利用可能なPremiumコンポーネント群
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

// ══════════════════════════════════════════
// StarryBackground — 星空テクスチャ背景
// ══════════════════════════════════════════
class StarryBackground extends StatelessWidget {
  final Widget child;
  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: kBgGradient),
      child: CustomPaint(
        painter: _StarPainter(),
        child: child,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  // 固定シードで再現性のある星配置
  static final _rng = Random(42);
  static final List<_Star> _stars = List.generate(80, (_) {
    return _Star(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      radius: _rng.nextDouble() * 1.2 + 0.3,
      opacity: _rng.nextDouble() * 0.4 + 0.1,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: s.opacity);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Star {
  final double x, y, radius, opacity;
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
}

// ══════════════════════════════════════════
// PremiumButton — ゴールドグラデーションボタン
// ══════════════════════════════════════════
class PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double height;

  const PremiumButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.height = 52,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: kGoldGradient,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: AppShadows.button,
            border: Border.all(
              color: AppColors.goldPrimary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(widget.label, style: AppTextStyles.goldButton),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// PremiumCard — ネイビー透過版 (type: dark) / アイボリー版 (type: light)
// ══════════════════════════════════════════
enum PremiumCardType { dark, light }

class PremiumCard extends StatelessWidget {
  final PremiumCardType type;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const PremiumCard({
    super.key,
    this.type = PremiumCardType.dark,
    required this.child,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = type == PremiumCardType.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: isLight ? AppColors.surfaceCard : AppColors.surfaceCard2,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.lineGold, width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }
}

// ══════════════════════════════════════════
// RankChip — ランク/ポイント表示用チップ
// ══════════════════════════════════════════
class RankChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const RankChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// ティア名から自動色付け
  factory RankChip.tier(String tier) {
    Color bg;
    Color text;
    Color border;
    switch (tier.toLowerCase()) {
      case 'platinum':
        bg = const Color(0xFFE0F7FA);
        text = const Color(0xFF00838F);
        border = const Color(0xFF4DD0E1);
      case 'gold':
        bg = const Color(0xFFFFF8E1);
        text = const Color(0xFFB48A3C);
        border = const Color(0xFFD6B56D);
      case 'silver':
        bg = const Color(0xFFF5F5F5);
        text = const Color(0xFF616161);
        border = const Color(0xFFBDBDBD);
      default: // bronze
        bg = const Color(0xFFEFEBE9);
        text = const Color(0xFF795548);
        border = const Color(0xFFA1887F);
    }
    return RankChip(
      label: tier,
      backgroundColor: bg,
      textColor: text,
      borderColor: border,
    );
  }

  /// ポイント表示用
  factory RankChip.points(int points) {
    return RankChip(
      label: '${points}pt',
      backgroundColor: const Color(0xFFE3F2FD),
      textColor: const Color(0xFF1565C0),
      borderColor: const Color(0xFF90CAF9),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceCard2,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: borderColor ?? AppColors.lineGold,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// PremiumTextField — アイボリー面/ゴールド枠
// ══════════════════════════════════════════
class PremiumTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;
  final double? letterSpacing;

  const PremiumTextField({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLength,
    this.textAlign = TextAlign.center,
    this.style,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textAlign: textAlign,
      style: style ??
          TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnCard,
            letterSpacing: letterSpacing ?? 8,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey[400],
          letterSpacing: letterSpacing ?? 8,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        counterText: '',
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: kGoldBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(
            color: AppColors.lineGold.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: const BorderSide(color: AppColors.goldPrimary, width: 2),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// GoldIconCircle — ゴールド縁の丸アイコン
// ══════════════════════════════════════════
class GoldIconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? iconColor;
  final Color? bgColor;

  const GoldIconCircle({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor ?? AppColors.surfaceCard2,
        border: Border.all(color: AppColors.goldPrimary, width: 2),
      ),
      child: Icon(
        icon,
        color: iconColor ?? AppColors.goldPrimary,
        size: size * 0.5,
      ),
    );
  }
}

// ══════════════════════════════════════════
// PremiumBottomNav — ネイビー+ゴールドのナビ
// ══════════════════════════════════════════
class PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_rounded, 'ホーム'),
    _NavItem(Icons.people_rounded, 'フレンド'),
    _NavItem(Icons.emoji_events_rounded, 'ランク'),
    _NavItem(Icons.person_rounded, 'プロフィール'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          top: BorderSide(color: AppColors.lineGold, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final color = selected
                  ? AppColors.goldPrimary
                  : AppColors.textPrimary.withValues(alpha: 0.45);
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_items[i].icon, color: color, size: 26),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
