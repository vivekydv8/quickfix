import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/core/widgets/shimmer_loading.dart';
import 'package:quickfix/core/widgets/notify_me_dialog.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/booking/presentation/controllers/cart_provider.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const CategoryScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String? _selectedSubcategoryId; // null means "All"
  List<Shop>? _shops;
  bool _showShopsSection = false;

  @override
  void initState() {
    super.initState();
    _fetchCategoryShops();
  }

  Future<void> _fetchCategoryShops() async {
    try {
      final activeLocation = ref.read(currentAddressProvider);
      final repo = ref.read(homeRepositoryProvider);
      final shops = await repo.searchShops(
        query: widget.categoryId,
        lat: activeLocation.latitude,
        lng: activeLocation.longitude,
      );
      if (mounted) {
        setState(() {
          _shops = shops;
        });
      }
    } catch (_) {}
  }


  void _showNotifyMeDialog(BuildContext context, bool isDark, UserLocation currentLoc, String title) {
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

    // Watch subcategories for this category
    final subcategoriesAsync = ref.watch(subcategoriesFamily(widget.categoryId));

    // Watch catalog services for this category or selected subcategory
    final servicesAsync = _selectedSubcategoryId == null
        ? ref.watch(categoryServicesFamily(widget.categoryId))
        : ref.watch(subcategoryServicesFamily(_selectedSubcategoryId!));

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
              ref.invalidate(categoryServicesFamily(widget.categoryId));
              if (_selectedSubcategoryId != null) {
                ref.invalidate(subcategoryServicesFamily(_selectedSubcategoryId!));
              }
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
          ref.invalidate(categoryServicesFamily(widget.categoryId));
          if (_selectedSubcategoryId != null) {
            ref.invalidate(subcategoryServicesFamily(_selectedSubcategoryId!));
          }
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
                  if (subcategories.isEmpty) return const SizedBox.shrink();
                  return _buildSubcategorySelector(isDark, mainCat, subcategories);
                },
                loading: () => _buildSubcategoriesLoadingShimmer(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── 3. Services List Header ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedSubcategoryId == null ? 'Available Services' : 'Services',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.secondary,
                      ),
                    ),
                    if (_shops != null && _shops!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          AppHaptics.lightTap();
                          setState(() => _showShopsSection = !_showShopsSection);
                        },
                        child: Text(
                          _showShopsSection ? 'Hide Local Shops' : 'View Local Shops (${_shops!.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── 4. Catalog Services List ────────────────────────────────────
            servicesAsync.when(
              data: (services) {
                if (services.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyState(context, isDark, mainCat),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final service = services[index];
                        final cartItem = cart[service.id];
                        return _buildServiceCard(context, isDark, mainCat, service, cartItem);
                      },
                      childCount: services.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerLoading(width: double.infinity, height: 140, borderRadius: 16),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text('Unable to load services right now.'),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(categoryServicesFamily(widget.categoryId));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 5. Optional Local Shops Section ─────────────────────────────
            if (_showShopsSection && _shops != null && _shops!.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Verified Local Centers & Workshops',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.secondary,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final shop = _shops![index];
                      return _buildShopCard(context, isDark, shop);
                    },
                    childCount: _shops!.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Hero Visual Banner ───────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context, bool isDark, MainCategory mainCat) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark
                      ? mainCat.accentColor.withValues(alpha: 0.20)
                      : mainCat.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: mainCat.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(mainCat.icon, color: mainCat.accentColor, size: 30),
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.secondary,
                            ),
                          ),
                        ),
                        if (mainCat.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: mainCat.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              mainCat.badge!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mainCat.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Trust Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrustPill('🛡️ 30-Day Warranty', isDark),
              _buildTrustPill('⚡ Verified Experts', isDark),
              _buildTrustPill('💰 Upfront Pricing', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPill(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262635) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  // ── Subcategories Horizontal Selector ────────────────────────────────────
  Widget _buildSubcategorySelector(
    bool isDark,
    MainCategory mainCat,
    List<Subcategory> subcategories,
  ) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: subcategories.length + 1, // +1 for "All"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAllChip = index == 0;
          final isSelected = isAllChip
              ? _selectedSubcategoryId == null
              : _selectedSubcategoryId == subcategories[index - 1].id;
          final title = isAllChip ? 'All' : subcategories[index - 1].name;

          return GestureDetector(
            onTap: () {
              AppHaptics.selectionClick();
              setState(() {
                _selectedSubcategoryId = isAllChip ? null : subcategories[index - 1].id;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.secondary),
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
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          ShimmerLoading(width: 60, height: 36, borderRadius: 18),
          SizedBox(width: 8),
          ShimmerLoading(width: 100, height: 36, borderRadius: 18),
          SizedBox(width: 8),
          ShimmerLoading(width: 110, height: 36, borderRadius: 18),
        ],
      ),
    );
  }


  // ── Catalog Service Card ────────────────────────────────────────────────
  Widget _buildServiceCard(
    BuildContext context,
    bool isDark,
    MainCategory mainCat,
    CatalogService service,
    CartItem? cartItem,
  ) {
    final hasDiscount = service.originalPrice > service.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title and Price Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Rating
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '${service.rating.toStringAsFixed(1)} (${service.reviewsCount})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Duration
                        Icon(Icons.schedule_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          service.durationText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Pricing Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    service.formattedPrice,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      '₹${service.originalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Row 2: Inclusions / Bullet Points
          if (service.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...service.bulletPoints.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bullet,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Row 3: Visiting charges disclosure & Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Visiting charges disclosure
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    service.isFreeInspection
                        ? 'Free inspection included'
                        : service.visitingCharges > 0
                            ? 'Visiting fee: ₹${service.visitingCharges.toStringAsFixed(0)} (adjusted in bill)'
                            : 'Standard doorstep service',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Add to Cart / Qty button
              cartItem == null
                  ? ElevatedButton(
                      onPressed: () {
                        AppHaptics.mediumTap();
                        ref.read(cartProvider.notifier).addItem(
                          service.id,
                          service.title,
                          service.price,
                          pricingType: service.pricingType,
                          isFreeInspection: service.isFreeInspection,
                          visitingCharges: service.visitingCharges,
                          minPrice: service.minPrice,
                          maxPrice: service.maxPrice,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add Service',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              AppHaptics.lightTap();
                              ref.read(cartProvider.notifier).removeItem(service.id);
                            },
                          ),
                          Text(
                            '${cartItem.quantity}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.secondary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () {
                              AppHaptics.lightTap();
                              ref.read(cartProvider.notifier).addItem(
                                service.id,
                                service.title,
                                service.price,
                                pricingType: service.pricingType,
                                isFreeInspection: service.isFreeInspection,
                                visitingCharges: service.visitingCharges,
                                minPrice: service.minPrice,
                                maxPrice: service.maxPrice,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shop Card (for local centers) ────────────────────────────────────────
  Widget _buildShopCard(BuildContext context, bool isDark, Shop shop) {
    return InkWell(
      onTap: () {
        AppHaptics.mediumTap();
        context.push('/shop/${shop.id}', extra: shop);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262635) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    shop.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        '${shop.rating} (${shop.reviewsCount}) • ${shop.distanceKm} km',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Floating Bottom Cart Bar ─────────────────────────────────────────────
  Widget _buildBottomCartBar(
    BuildContext context,
    bool isDark,
    int totalCount,
    double totalPrice,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCount ${totalCount == 1 ? "service" : "services"} added',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.secondary,
                  ),
                ),
              ],
            ),
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

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, bool isDark, MainCategory mainCat) {
    final currentLoc = ref.watch(currentAddressProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262635) : const Color(0xFFFFF1F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.construction_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon in Your Area!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We are rapidly expanding ${mainCat.displayName} services to Kalyanpur and Kanpur.\nGet notified as soon as technicians are available in your sector.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showNotifyMeDialog(context, isDark, currentLoc, mainCat.displayName),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Notify Me When Available'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

