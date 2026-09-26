import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';

/// Clean, natural, professional category icon widget designed for a modern white theme.
/// Features a crisp porcelain card with delicate hairline border and a soft-tinted natural emblem.
class PremiumCategoryIcon extends StatelessWidget {
  final MainCategory category;
  final double size;
  final double iconSize;
  final bool showBadge;
  final bool isDark;

  const PremiumCategoryIcon({
    super.key,
    required this.category,
    this.size = 54.0,
    this.iconSize = 26.0,
    this.showBadge = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.28);
    final innerSize = size * 0.76;
    final innerRadius = BorderRadius.circular(innerSize * 0.28);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Outer Crisp Minimal White / Slate Surface Card
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: isDark ? const Color(0xFF1E2433) : Colors.white,
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.035),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            // Inner Soft-Tinted Natural Pod with Crisp Accent Icon
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                borderRadius: innerRadius,
                color: isDark
                    ? category.accentColor.withValues(alpha: 0.16)
                    : category.accentColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: isDark
                      ? category.accentColor.withValues(alpha: 0.24)
                      : category.accentColor.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Icon(
                  category.icon,
                  size: iconSize * 0.86,
                  color: isDark
                      ? category.accentColor.withValues(alpha: 0.95)
                      : category.accentColor,
                ),
              ),
            ),
          ),
        ),

        // Optional Minimal Micro-Badge
        if (showBadge && category.badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 0.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                category.badge!,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
