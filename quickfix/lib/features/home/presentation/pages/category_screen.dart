import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/theme/app_text_styles.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/core/widgets/shimmer_loading.dart';
import 'package:quickfix/core/widgets/notify_me_dialog.dart';
import 'package:quickfix/core/widgets/error_widgets.dart';
import 'package:quickfix/core/network/connectivity_provider.dart';
import 'package:quickfix/core/network/error_handler.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/booking/presentation/controllers/cart_provider.dart';
import 'package:quickfix/features/home/presentation/widgets/premium_category_icon.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String? initialSubcategoryId;
  const CategoryScreen({
    super.key,
    required this.categoryId,
    this.initialSubcategoryId,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  List<Shop>? _shops;
  bool _isLoading = true;
  String _errorMessage = '';
  String? _selectedSubcategoryId; // null means "All"
  String? _selectedSubcategoryName;

  @override
  void initState() {
    super.initState();
    _selectedSubcategoryId = widget.initialSubcategoryId;
    _resolveInitialSubcategoryName();
    _loadCachedShops();
    _fetchCategoryShops();
  }

  void _resolveInitialSubcategoryName() {
    if (_selectedSubcategoryId == null) return;
    final mainCat = getMainCategoryById(widget.categoryId);
    for (final sample in mainCat.sampleSubcategories) {
      if (sample.toLowerCase() == _selectedSubcategoryId!.toLowerCase() ||
          _selectedSubcategoryId!.toLowerCase().contains(sample.toLowerCase())) {
        _selectedSubcategoryName = sample;
        return;
      }
    }
    _selectedSubcategoryName = _selectedSubcategoryId;
  }

  void _loadCachedShops() {
    try {
      final cacheKey = 'search_shops_${widget.categoryId}_${_selectedSubcategoryName ?? ''}';
      final cached = HiveService.getDataCache(cacheKey) ??
          HiveService.getDataCache('search_shops_${widget.categoryId}');
      if (cached != null && cached is List) {
        final parsed = cached
            .map((e) => Shop.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (parsed.isNotEmpty) {
          setState(() {
            _shops = parsed;
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCategoryShops() async {
    if (_shops == null || _shops!.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final activeLocation = ref.read(currentAddressProvider);
      final repo = ref.read(homeRepositoryProvider);

      final shops = await repo.searchShops(
        query: _selectedSubcategoryName ?? widget.categoryId,
        lat: activeLocation.latitude,
        lng: activeLocation.longitude,
        category: widget.categoryId,
        subcategory: _selectedSubcategoryName,
      );

      if (mounted) {
        setState(() {
          _shops = shops;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_shops == null || _shops!.isEmpty) {
            _errorMessage = ErrorHandler.handle(e).message;
          }
        });
      }
    }
  }

  String _getCategoryTitle() {
    final mainCat = getMainCategoryById(widget.categoryId);
    return mainCat.displayName;
  }

  void _showNotifyMeDialog(
    BuildContext context,
    bool isDark,
    UserLocation currentLoc,
  ) {
    final title = _selectedSubcategoryName != null
        ? '$_selectedSubcategoryName (${_getCategoryTitle()})'
        : _getCategoryTitle();

    showDialog(
      context: context,
      builder: (ctx) => NotifyMeDialog(
        isDark: isDark,
        currentLoc: currentLoc,
        categoryTitle: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final mainCat = getMainCategoryById(widget.categoryId);
    final cart = ref.watch(cartProvider);
    final currentLoc = ref.watch(currentAddressProvider);

    // Auto-retry on internet reconnection if previously failed
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true &&
          previous?.value == false &&
          _errorMessage.isNotEmpty) {
        _fetchCategoryShops();
      }
    });

    // Watch subcategories for this category
    final subcategoriesAsync = ref.watch(subcategoriesFamily(widget.categoryId));

    final totalCartCount = cart.values.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalCartPrice = cart.values.fold<double>(0.0, (sum, item) => sum + (item.price * item.quantity));

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.secondary),
          onPressed: () {
            AppHaptics.lightTap();
            context.pop();
          },
        ),
        title: Text(
          mainCat.displayName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.secondary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : AppColors.secondary),
            onPressed: () {
              AppHaptics.mediumTap();
              ref.invalidate(subcategoriesFamily(widget.categoryId));
              _fetchCategoryShops();
            },
          ),
        ],
      ),
      bottomNavigationBar: totalCartCount > 0
          ? _buildBottomCartBar(context, isDark, totalCartCount, totalCartPrice)
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(subcategoriesFamily(widget.categoryId));
          await _fetchCategoryShops();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── 1. Hero Visual Identity Banner ──────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeroBanner(context, isDark, mainCat),
            ),

            // ── 2. Subcategories Horizontal Selector ─────────────────────────
            SliverToBoxAdapter(
              child: subcategoriesAsync.when(
                data: (subcategories) {
                  final list = subcategories.isNotEmpty
                      ? subcategories
                      : mainCat.sampleSubcategories
                          .asMap()
                          .entries
                          .map((e) => Subcategory(
                                id: '${mainCat.id}_${e.key + 1}',
                                categoryId: mainCat.id,
                                name: e.value,
                                description: 'Expert service for ${e.value.toLowerCase()}',
                                displayOrder: e.key + 1,
                                isActive: true,
                              ))
                          .toList();
                  return _buildSubcategorySelector(isDark, mainCat, list);
                },
                loading: () => _buildSubcategoriesLoadingShimmer(),
                error: (_, __) {
                  final fallbackList = mainCat.sampleSubcategories
                      .asMap()
                      .entries
                      .map((e) => Subcategory(
                            id: '${mainCat.id}_${e.key + 1}',
                            categoryId: mainCat.id,
                            name: e.value,
                            description: 'Expert service for ${e.value.toLowerCase()}',
                            displayOrder: e.key + 1,
                            isActive: true,
                          ))
                      .toList();
                  return _buildSubcategorySelector(isDark, mainCat, fallbackList);
                },
              ),
            ),

            // ── 3. Main Body: Nearby Shops List / Coming Soon Screen ────────
            if (_isLoading)
              _buildShopsLoadingShimmer()
            else if (_errorMessage.isNotEmpty && (_shops == null || _shops!.isEmpty))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: CommonErrorWidget(
                    message: _errorMessage,
                    onRetry: _fetchCategoryShops,
                  ),
                ),
              )
            else if (_shops == null || _shops!.isEmpty)
              SliverToBoxAdapter(
                child: _buildComingSoonScreen(context, isDark, currentLoc, mainCat),
              )
            else ...[
              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              '${_shops!.length} Verified Nearby',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (currentLoc.address.isNotEmpty)
                        Flexible(
                          child: Text(
                            currentLoc.address.split(',').first,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Shops List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final shop = _shops![index];
                      return _buildShopCard(context, isDark, shop, mainCat);
                    },
                    childCount: _shops!.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  // ── Hero Visual Banner ───────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context, bool isDark, MainCategory mainCat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: mainCat.accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          PremiumCategoryIcon(
            category: mainCat,
            size: 54,
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
                        mainCat.displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.secondary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (mainCat.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: mainCat.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: mainCat.accentColor.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          mainCat.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: mainCat.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  mainCat.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'QuickFix Verified Technicians',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Subcategories Horizontal Selector ────────────────────────────────────
  Widget _buildSubcategorySelector(bool isDark, MainCategory mainCat, List<Subcategory> subcategories) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: subcategories.length + 1, // +1 for "All"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll
              ? _selectedSubcategoryId == null
              : (_selectedSubcategoryId == subcategories[index - 1].id ||
                 _selectedSubcategoryName == subcategories[index - 1].name);

          final title = isAll ? 'All' : subcategories[index - 1].name;

          return GestureDetector(
            onTap: () {
              AppHaptics.selectionClick();
              setState(() {
                if (isAll) {
                  _selectedSubcategoryId = null;
                  _selectedSubcategoryName = null;
                } else {
                  final sub = subcategories[index - 1];
                  _selectedSubcategoryId = sub.id;
                  _selectedSubcategoryName = sub.name;
                }
              });
              _fetchCategoryShops();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: mainCat.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: mainCat.accentColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
              ),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubcategoriesLoadingShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, __) => const ShimmerLoading(width: 90, height: 38, borderRadius: 20),
      ),
    );
  }

  // ── Shop Card Widget ─────────────────────────────────────────────────────
  Widget _buildShopCard(BuildContext context, bool isDark, Shop shop, MainCategory mainCat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          AppHaptics.mediumTap();
          context.push('/shop/${shop.id}', extra: shop);
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Cover Image Header
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    shop.imagePath,
                    height: 148,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    errorBuilder: (_, __, ___) => Container(
                      height: 148,
                      color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                      child: Center(
                        child: Icon(
                          mainCat.icon,
                          size: 44,
                          color: mainCat.accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),

                // Rating Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 13),
                        const SizedBox(width: 3),
                        Text(
                          shop.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (shop.reviewsCount > 0) ...[
                          const SizedBox(width: 2),
                          Text(
                            ' (${shop.reviewsCount})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Distance Badge
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          '${shop.distanceKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Shop Details Body
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Verified
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.secondary,
                          ),
                        ),
                      ),
                      const Icon(Icons.verified, size: 16, color: AppColors.primary),
                    ],
                  ),

                  if (shop.ownerName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'By ${shop.ownerName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Timing & Visiting Charges Pills
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          shop.visitingCharges > 0
                              ? 'Visiting: ₹${shop.visitingCharges.toInt()}'
                              : 'Free Visit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚡ ${shop.estimatedServiceTime ?? '${shop.deliveryTimeMins} mins'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Category & Services Chips
                  if (shop.services.isNotEmpty || shop.categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...shop.categories.take(2).map(
                              (c) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: mainCat.accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: mainCat.accentColor,
                                  ),
                                ),
                              ),
                            ),
                        ...shop.services.take(2).map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A2A38) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  s.title,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Bottom Action CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'View Services & Packages',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopsLoadingShimmer() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: ShimmerLoading(width: double.infinity, height: 230, borderRadius: 20),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  // ── Authentic Coming Soon Screen ─────────────────────────────────────────
  Widget _buildComingSoonScreen(
    BuildContext context,
    bool isDark,
    UserLocation currentLoc,
    MainCategory mainCat,
  ) {
    final title = _selectedSubcategoryName != null
        ? _selectedSubcategoryName!
        : _getCategoryTitle();

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2E3A) : const Color(0xFFFFF1F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.construction_rounded,
                color: AppColors.primary,
                size: 52,
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: 24),

            Text(
              '🚧 We\'re Coming Soon!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.secondary,
              ),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 10),

            Text(
              'Sorry, QuickFix currently doesn\'t provide $title in your area.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(isDark).copyWith(
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 250.ms),

            const SizedBox(height: 6),

            Text(
              'We are expanding rapidly and onboarding verified service partners in your sector. Be the first to know when we launch here!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(isDark).copyWith(height: 1.4),
            ).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showNotifyMeDialog(context, isDark, currentLoc),
                icon: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Notify Me When Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 450.ms),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AppHaptics.lightTap();
                      context.push('/location-selector');
                    },
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                    label: const Text('Change Address'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppColors.secondary,
                      side: BorderSide(
                        color: isDark ? Colors.white38 : AppColors.borderLight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AppHaptics.mediumTap();
                      _fetchCategoryShops();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 550.ms),
          ],
        ),
      ),
    );
  }

  // ── Bottom Cart Bar ──────────────────────────────────────────────────────
  Widget _buildBottomCartBar(
    BuildContext context,
    bool isDark,
    int count,
    double price,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'ITEM' : 'ITEMS'} ADDED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.secondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                AppHaptics.mediumTap();
                context.push('/checkout');
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text(
                'View Cart & Book',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
