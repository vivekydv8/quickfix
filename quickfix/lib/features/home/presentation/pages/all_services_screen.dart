import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/theme/app_text_styles.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/home/presentation/widgets/category_subcategories_sheet.dart';
import 'package:quickfix/features/home/presentation/widgets/premium_category_icon.dart';

class AllServicesScreen extends ConsumerStatefulWidget {
  const AllServicesScreen({super.key});

  @override
  ConsumerState<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends ConsumerState<AllServicesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    final filteredCategories = kMainCategories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return cat.displayName.toLowerCase().contains(query) ||
          cat.subtitle.toLowerCase().contains(query) ||
          cat.id.toLowerCase().contains(query) ||
          cat.sampleSubcategories.any((sub) => sub.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : AppColors.secondary,
          ),
          onPressed: () {
            AppHaptics.lightTap();
            context.pop();
          },
        ),
        title: Text('All Service Categories', style: AppTextStyles.headingMedium(isDark)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${kMainCategories.length} Categories',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.secondary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search categories or services (e.g. AC, tap, lock)...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 22, color: AppColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // ── Categories List / Grid ───────────────────────────────────────
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No category matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try searching for plumber, electrician, or appliance repair',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cat = filteredCategories[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Opens the Urban Company / Blinkit style subcategories bottom sheet
                            CategorySubcategoriesSheet.show(context, cat);
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.035),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Premium Gradient Category Icon
                                    PremiumCategoryIcon(
                                      category: cat,
                                      size: 54,
                                      iconSize: 26,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 14),
                                    // Title & subtitle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  cat.displayName,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppColors.secondary,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                              if (cat.badge != null) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: cat.accentColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: cat.accentColor.withValues(alpha: 0.3),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    cat.badge!,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: cat.accentColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            cat.subtitle,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Open Subcategories Arrow Pill
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF262635)
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: isDark ? Colors.white : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),

                                // Subcategories Quick Preview Chips
                                if (cat.sampleSubcategories.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: cat.sampleSubcategories.map((subName) {
                                      return GestureDetector(
                                        onTap: () {
                                          AppHaptics.lightTap();
                                          CategorySubcategoriesSheet.show(context, cat);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E2433)
                                                : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF2D3748)
                                                  : const Color(0xFFE2E8F0),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            subName,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
