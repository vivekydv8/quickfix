import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/home/presentation/widgets/premium_category_icon.dart';

/// Interactive Urban Company / Blinkit style bottom sheet that showcases
/// all subcategories under a specific main category when clicked.
class CategorySubcategoriesSheet extends ConsumerWidget {
  final MainCategory category;

  const CategorySubcategoriesSheet({super.key, required this.category});

  static Future<void> show(BuildContext context, MainCategory category) {
    AppHaptics.mediumTap();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategorySubcategoriesSheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final subcategoriesAsync = ref.watch(subcategoriesFamily(category.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag Handle ──────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // ── Header Banner ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
              child: Row(
                children: [
                  PremiumCategoryIcon(
                    category: category,
                    size: 52,
                    iconSize: 26,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                category.displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.secondary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (category.badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: category.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: category.accentColor.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  category.badge!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: category.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // ── Subcategories List ────────────────────────────────────
            Flexible(
              child: subcategoriesAsync.when(
                data: (subcats) {
                  final list = subcats.isNotEmpty
                      ? subcats
                      : category.sampleSubcategories
                          .asMap()
                          .entries
                          .map((e) => Subcategory(
                                id: '${category.id}_${e.key + 1}',
                                categoryId: category.id,
                                name: e.value,
                                description: 'Expert service for ${e.value.toLowerCase()}',
                                displayOrder: e.key + 1,
                                isActive: true,
                              ))
                          .toList();

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sub = list[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            AppHaptics.mediumTap();
                            Navigator.of(context).pop();
                            context.push('/category/${category.id}?subcat=${Uri.encodeComponent(sub.name)}');
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF262635) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: category.accentColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      category.icon,
                                      color: category.accentColor,
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sub.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : AppColors.secondary,
                                        ),
                                      ),
                                      if (sub.description.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sub.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Explore services directly below',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom Action Button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: () {
                  AppHaptics.mediumTap();
                  Navigator.of(context).pop();
                  context.push('/category/${category.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleFramework(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All ${category.displayName} Services',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectangleFramework extends RoundedRectangleBorder {
  const RoundedRectangleFramework({super.borderRadius});
}
