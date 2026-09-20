import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';

/// Ultra-premium category icon widget inspired by top on-demand apps (Urban Company, Blinkit).
/// Features multi-stop vibrant gradients, ambient diffuse glow, inner gloss highlight, and micro-badges.
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Outer Glowing Pod Container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: category.gradientColors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.32),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: category.glowColor.withValues(alpha: isDark ? 0.40 : 0.30),
                blurRadius: size * 0.28,
                spreadRadius: 1,
                offset: Offset(0, size * 0.10),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Top-left subtle glass/gloss sheen
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size * 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(size * 0.30),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Centered High-Contrast Icon
              Center(
                child: Icon(
                  category.icon,
                  size: iconSize,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Optional Micro-badge
        if (showBadge && category.badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Text(
                category.badge!,
                style: GoogleFonts.inter(
                  fontSize: 8,
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
