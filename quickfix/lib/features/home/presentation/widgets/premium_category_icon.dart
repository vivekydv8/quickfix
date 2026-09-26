import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';

/// Ultra-premium category icon widget inspired by top on-demand apps (Urban Company, Blinkit).
/// Features dual-layer depth: soft-tinted ambient halo + inner vibrant gradient squircle with specular glass sheen.
class PremiumCategoryIcon extends StatelessWidget {
  final MainCategory category;
  final double size;
  final double iconSize;
  final bool showBadge;
  final bool isDark;

  const PremiumCategoryIcon({
    super.key,
    required this.category,
    this.size = 58.0,
    this.iconSize = 28.0,
    this.showBadge = true,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.76;
    final borderRadius = BorderRadius.circular(size * 0.30);
    final innerBorderRadius = BorderRadius.circular(innerSize * 0.32);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Layer 1: Outer Tinted Soft Squircle Halo
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: isDark
                ? category.accentColor.withValues(alpha: 0.14)
                : category.backgroundColor,
            border: Border.all(
              color: category.accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: category.glowColor.withValues(alpha: isDark ? 0.25 : 0.15),
                blurRadius: size * 0.24,
                spreadRadius: 0.5,
                offset: Offset(0, size * 0.08),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          child: Center(
            // Layer 2: Inner Vibrant 3D Gradient Squircle
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                borderRadius: innerBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: category.gradientColors,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: category.glowColor.withValues(alpha: 0.35),
                    blurRadius: innerSize * 0.28,
                    offset: Offset(0, innerSize * 0.12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Top specular sheen reflection
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: innerSize * 0.46,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(innerSize * 0.30),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.32),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Crisp high-contrast Icon
                  Center(
                    child: Icon(
                      category.icon,
                      size: iconSize * 0.88,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 3,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Layer 3: Floating Micro-badge
        if (showBadge && category.badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: category.accentColor.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Text(
                category.badge!,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: category.accentColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
