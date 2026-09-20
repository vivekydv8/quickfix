import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/theme/app_text_styles.dart';
import 'package:quickfix/core/theme/app_shadows.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/core/utils/cta_handler.dart';
import 'package:quickfix/core/widgets/shimmer_loading.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/notifications/presentation/controllers/notifications_provider.dart';
import 'package:quickfix/features/home/presentation/widgets/home_header.dart';
import 'package:quickfix/features/home/presentation/widgets/home_banner_carousel.dart';
import 'package:quickfix/features/home/presentation/widgets/home_categories_grid.dart';
import 'package:quickfix/features/home/presentation/widgets/home_promo_banner.dart';
import 'package:quickfix/features/home/presentation/widgets/home_nearby_shops.dart';
import 'package:quickfix/features/home/presentation/widgets/home_professionals_section.dart';
import 'package:quickfix/features/home/presentation/widgets/home_special_offers.dart';
import 'package:quickfix/features/home/presentation/widgets/home_trust_and_guides.dart';
import 'package:quickfix/features/home/presentation/widgets/home_customer_reviews.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _showPinnedHeader = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scrollListener);

    // Fetch location dynamically on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(currentAddressProvider.notifier)
          .fetchGPSLocation(requestPermission: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger background location update on app resume
      ref
          .read(currentAddressProvider.notifier)
          .fetchGPSLocation(requestPermission: false);
    }
  }

  void _scrollListener() {
    if (_scrollController.offset > 120) {
      if (!_showPinnedHeader) {
        setState(() {
          _showPinnedHeader = true;
        });
      }
    } else {
      if (_showPinnedHeader) {
        setState(() {
          _showPinnedHeader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final bannersAsync = ref.watch(bannersProvider);
    final layoutAsync = ref.watch(homepageLayoutProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.refresh(categoriesProvider.future),
                  ref.refresh(nearbyShopsProvider.future),
                  ref.refresh(topProfessionalsProvider.future),
                  ref.refresh(customerReviewsProvider.future),
                  ref.refresh(bannersProvider.future),
                  ref.refresh(promotionsProvider.future),
                  ref.refresh(specialCardsProvider.future),
                  ref.refresh(homepageLayoutProvider.future),
                  ref.refresh(notificationsProvider.future),
                ]);
              },
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header Block
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeHeaderRow(),
                          SizedBox(height: 12),
                          HomeAddressRow(),
                          SizedBox(height: 10),
                          HomeSearchBarRow(),
                          SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  ...layoutAsync.when(
                    data: (sections) => sections
                        .map((sec) => _buildDynamicSection(sec, isDark))
                        .toList(),
                    loading: () => [
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              ShimmerLoading(
                                width: double.infinity,
                                height: 168,
                                borderRadius: 18,
                              ),
                              SizedBox(height: 14),
                              ShimmerLoading(
                                width: double.infinity,
                                height: 120,
                                borderRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    error: (err, stack) => [
                      // Fallback static layout (equivalent to current layout)
                      SliverToBoxAdapter(
                        child: bannersAsync.when(
                          data: (banners) =>
                              HomeBannerCarousel(banners: banners),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, s) => const SizedBox.shrink(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: HomeCategoriesGrid()),
                      const SliverToBoxAdapter(child: HomeFestiveOfferBanner()),
                      const SliverToBoxAdapter(child: HomeNearbyShops()),
                      const SliverToBoxAdapter(child: HomeTrustBadges()),
                      const SliverToBoxAdapter(child: HomeOfferPromoSection()),
                      const SliverToBoxAdapter(child: HomeHowItWorksSection()),
                      const SliverToBoxAdapter(child: HomeSpecialForYou()),
                      const SliverToBoxAdapter(
                        child: HomeProfessionalsSection(),
                      ),
                      const SliverToBoxAdapter(child: HomeCustomerReviews()),
                      const SliverToBoxAdapter(child: HomeBrandLogos()),
                      const SliverToBoxAdapter(child: HomeNeedHelpCard()),
                    ],
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),

            // Animated Pinned Compact Header Row
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showPinnedHeader ? 0 : -80,
              left: 0,
              right: 0,
              child: const HomePinnedHeader(),
            ),
          ],
        ),
      ),
    );
  }

  // --- CMS DYNAMIC SECTIONS ROUTER ---

  Widget _buildDynamicSection(CmsSection sec, bool isDark) {
    switch (sec.type) {
      case 'banner_carousel':
        final bannersAsync = ref.watch(bannersProvider);
        return SliverToBoxAdapter(
          child: bannersAsync.when(
            data: (banners) =>
                RepaintBoundary(child: HomeBannerCarousel(banners: banners)),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, s) => const SizedBox.shrink(),
          ),
        );
      case 'grid_categories':
        return const SliverToBoxAdapter(child: HomeCategoriesGrid());
      case 'home_promotions':
        return const SliverToBoxAdapter(child: HomeFestiveOfferBanner());
      case 'nearby_shops':
        return const SliverToBoxAdapter(
          child: RepaintBoundary(child: HomeNearbyShops()),
        );
      case 'quickfix_plus':
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      case 'trust_badges':
        return const SliverToBoxAdapter(child: HomeTrustBadges());
      case 'referral_offers':
        return const SliverToBoxAdapter(child: HomeOfferPromoSection());
      case 'how_it_works':
        return const SliverToBoxAdapter(child: HomeHowItWorksSection());
      case 'special_for_you':
        return const SliverToBoxAdapter(child: HomeSpecialForYou());
      case 'top_experts':
        return const SliverToBoxAdapter(
          child: RepaintBoundary(child: HomeProfessionalsSection()),
        );
      case 'customer_reviews':
        return SliverToBoxAdapter(
          child: RepaintBoundary(
            child: HomeCustomerReviews(settings: sec.settings),
          ),
        );
      case 'brand_logos':
        return const SliverToBoxAdapter(child: HomeBrandLogos());
      case 'support_card':
        return const SliverToBoxAdapter(child: HomeNeedHelpCard());
      case 'custom_section':
        return SliverToBoxAdapter(
          child: RepaintBoundary(child: _buildCustomSection(sec, isDark)),
        );
      default:
        return SliverToBoxAdapter(child: _buildGenericCmsSection(sec, isDark));
    }
  }

  Widget _buildGenericCmsSection(CmsSection sec, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : AppShadows.card,
          border: isDark
              ? Border.all(color: AppColors.borderDark)
              : Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sec.title, style: AppTextStyles.headingMedium(isDark)),
            const SizedBox(height: 8),
            Text(
              sec.settings['description']?.toString() ??
                  'Dynamic content section.',
              style: AppTextStyles.bodySmall(isDark),
            ),
            if (sec.settings['buttonText'] != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  handleCtaAction(
                    context,
                    sec.settings['ctaAction']?.toString() ?? 'No Action',
                    sec.settings['ctaActionValue']?.toString() ?? '',
                  );
                },
                child: Text(sec.settings['buttonText'].toString()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSection(CmsSection sec, bool isDark) {
    final customSectionsAsync = ref.watch(customSectionsProvider);

    return customSectionsAsync.when(
      data: (customSections) {
        final data = customSections.where((cs) => cs.id == sec.id).firstOrNull;
        if (data == null) return const SizedBox.shrink();
        return _buildCustomSectionContent(data, isDark);
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildCustomSectionContent(CustomSection data, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Premium Showcase Banner ────────────────────────────────
        if (data.bannerImageUrl.isNotEmpty)
          GestureDetector(
            onTap: () {
              AppHaptics.mediumTap();
              handleCtaAction(
                context,
                data.bannerActionType,
                data.bannerActionValue,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      // Banner Image
                      AspectRatio(
                        aspectRatio: 1.95,
                        child: Image.network(
                          data.bannerImageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: isDark
                                ? AppColors.surfaceDark
                                : const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Multi-stop Vignette Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.18),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                              stops: const [0.0, 0.40, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Top Badge
                      if (data.bannerBadgeText.isNotEmpty)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  data.bannerBadgeText.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Banner Content Text & CTA
                      Positioned(
                        bottom: 14,
                        left: 16,
                        right: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (data.title.isNotEmpty)
                                    Text(
                                      data.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 6.0,
                                            color: Colors.black.withValues(alpha: 0.7),
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (data.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      data.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4.0,
                                            color: Colors.black.withValues(alpha: 0.7),
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (data.bannerButtonText.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      data.bannerButtonText,
                                      style: GoogleFonts.outfit(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── 2. Service Items Showcase ─────────────────────────────────
        if (data.serviceItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 14.0,
              bottom: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data.title.isNotEmpty)
                              Text(
                                data.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : AppColors.secondary,
                                ),
                              ),
                            if (data.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                data.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.seeAllActionType != 'No Action')
                  GestureDetector(
                    onTap: () {
                      AppHaptics.lightTap();
                      handleCtaAction(
                        context,
                        data.seeAllActionType,
                        data.seeAllActionValue,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'See all',
                            style: GoogleFonts.outfit(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 232,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: data.serviceItems.length,
              itemBuilder: (context, index) {
                final item = data.serviceItems[index];
                final priceText = item.startingPrice.isNotEmpty
                    ? (item.startingPrice.startsWith('₹')
                        ? item.startingPrice
                        : '₹${item.startingPrice}')
                    : '';

                return GestureDetector(
                  onTap: () {
                    AppHaptics.mediumTap();
                    handleCtaAction(context, item.actionType, item.actionValue);
                  },
                  child: Container(
                    width: 168,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Image Container with Rating Pill
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 108,
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  child: item.imageUrl.isNotEmpty
                                      ? Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: 380,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Center(
                                            child: Icon(
                                              Icons.home_repair_service_rounded,
                                              color: Colors.grey,
                                              size: 28,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.home_repair_service_rounded,
                                            color: Colors.grey,
                                            size: 28,
                                          ),
                                        ),
                                ),
                                // Rating Pill Floating on Top-Left
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 12,
                                          color: Color(0xFFFFB800),
                                        ),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          item.rating.toStringAsFixed(1),
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Service Title
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.secondary,
                            ),
                          ),

                          const Spacer(),

                          // Bottom Row: Price & Mini "+ ADD / BOOK" CTA Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (priceText.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Starts at',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      priceText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox.shrink(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '+ ADD',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
