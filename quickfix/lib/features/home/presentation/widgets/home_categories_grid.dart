import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/core/widgets/section_header.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';

class HomeCategoriesGrid extends ConsumerStatefulWidget {
  const HomeCategoriesGrid({super.key});

  @override
  ConsumerState<HomeCategoriesGrid> createState() => _HomeCategoriesGridState();
}

class _HomeCategoriesGridState extends ConsumerState<HomeCategoriesGrid> {
  int? _tappedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    // Display first 7 main categories + 1 "See All" tile
    final topCategories = kMainCategories.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'All Services',
          isDark: isDark,
          onSeeAll: () {
            AppHaptics.lightTap();
            context.push('/category/all');
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: 8,
            itemBuilder: (context, index) {
              final isSeeAllTile = index == 7;
              final MainCategory? cat = isSeeAllTile ? null : topCategories[index];
              final isActive = _tappedIndex == index;

              return GestureDetector(
                onTap: () {
                  AppHaptics.mediumTap();
                  setState(() => _tappedIndex = index);
                  Future.delayed(const Duration(milliseconds: 260), () {
                    if (mounted) setState(() => _tappedIndex = null);
                  });

                  if (isSeeAllTile) {
                    context.push('/category/all');
                  } else if (cat != null) {
                    context.push('/category/${cat.id}');
                  }
                },
                child: AnimatedScale(
                  scale: isActive ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Icon Box with optional Badge ───────────────
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 62,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSeeAllTile
                                  ? (isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9))
                                  : (isDark
                                      ? cat!.accentColor.withValues(alpha: 0.15)
                                      : cat!.backgroundColor),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSeeAllTile
                                    ? (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1))
                                    : (isDark
                                        ? AppColors.borderDark
                                        : cat!.accentColor.withValues(alpha: 0.20)),
                                width: 1,
                              ),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: (isSeeAllTile ? Colors.black : cat!.accentColor)
                                        .withValues(alpha: 0.07),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: isSeeAllTile
                                  ? Icon(
                                      Icons.apps_rounded,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      size: 28,
                                    )
                                  : Icon(
                                      cat!.icon,
                                      color: cat.accentColor,
                                      size: 30,
                                    ),
                            ),
                          ),
                          // Badge (e.g. Popular, Warranty)
                          if (!isSeeAllTile && cat?.badge != null)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: cat!.accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cat.accentColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  cat.badge!,
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // ── Title Label ───────────────────────────────
                      Text(
                        isSeeAllTile ? 'See All (11)' : cat!.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          letterSpacing: -0.1,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

