import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/home/presentation/widgets/shop_details_header.dart';
import 'package:quickfix/features/home/presentation/widgets/shop_category_filter_bar.dart';
import 'package:quickfix/features/home/presentation/widgets/shop_service_item.dart';
import 'package:quickfix/features/booking/presentation/controllers/cart_provider.dart';
import 'package:quickfix/core/widgets/error_widgets.dart';
import 'package:quickfix/core/network/connectivity_provider.dart';
import 'package:quickfix/core/network/error_handler.dart';
import 'package:quickfix/core/storage/hive_service.dart';

class ShopDetailsScreen extends ConsumerStatefulWidget {
  final String shopId;
  final Shop? initialShop;

  const ShopDetailsScreen({super.key, required this.shopId, this.initialShop});

  @override
  ConsumerState<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends ConsumerState<ShopDetailsScreen> {
  Shop? _shop;
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialShop != null) {
      _shop = widget.initialShop;
    } else {
      _fetchShopDetails();
    }
  }

  Future<void> _fetchShopDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final activeLocation = ref.read(currentAddressProvider);
      final repo = ref.read(homeRepositoryProvider);
      final shops = await repo.getNearbyShops(
        lat: activeLocation.latitude,
        lng: activeLocation.longitude,
      );

      final found = shops.firstWhere(
        (s) => s.id == widget.shopId,
        orElse: () => throw Exception('Shop details not found.'),
      );

      if (mounted) {
        setState(() {
          _shop = found;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.handle(e).message;
        });
      }
    }
  }

  void _handleAddToCart(ShopService service) {
    AppHaptics.heavyTap();
    final activeShopId = ref.read(cartShopIdProvider);

    if (activeShopId != null && activeShopId != _shop!.id) {
      // Prompt user to clear cart from different shop
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Replace Cart Items?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Your cart contains services from another shop. Do you want to clear your cart and add services from ${_shop!.name} instead?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondaryLight),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clearCart();
                ref.read(cartShopIdProvider.notifier).state = _shop!.id;
                HiveService.saveDataCache('cart_shop_id', _shop!.id);
                ref
                    .read(cartProvider.notifier)
                    .addItem(
                      service.id,
                      service.title,
                      service.price,
                      pricingType: service.pricingType,
                      isFreeInspection: service.isFreeInspection,
                      visitingCharges: service.visitingCharges,
                      minPrice: service.minPrice,
                      maxPrice: service.maxPrice,
                    );
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Replace Items',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      ref.read(cartShopIdProvider.notifier).state = _shop!.id;
      HiveService.saveDataCache('cart_shop_id', _shop!.id);
      ref
          .read(cartProvider.notifier)
          .addItem(
            service.id,
            service.title,
            service.price,
            pricingType: service.pricingType,
            isFreeInspection: service.isFreeInspection,
            visitingCharges: service.visitingCharges,
            minPrice: service.minPrice,
            maxPrice: service.maxPrice,
          );
    }
  }

  void _handleRemoveFromCart(ShopService service) {
    AppHaptics.lightTap();
    ref.read(cartProvider.notifier).removeItem(service.id);

    // If cart becomes empty, reset shop id tracker
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ref.read(cartShopIdProvider.notifier).state = null;
      HiveService.saveDataCache('cart_shop_id', null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final cart = ref.watch(cartProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalAmount = ref.watch(cartTotalAmountProvider);

    // Auto-retry on internet reconnection if previously failed
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true &&
          previous?.value == false &&
          (_errorMessage.isNotEmpty || _shop == null)) {
        _fetchShopDetails();
      }
    });

    Widget buildBody() {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (_errorMessage.isNotEmpty || _shop == null) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height:
                MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top -
                50,
            alignment: Alignment.center,
            child: CommonErrorWidget(
              message: _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Shop details could not be found.',
              onRetry: _fetchShopDetails,
            ),
          ),
        );
      }

      final shop = _shop!;
      final allAvailableServices = shop.services
          .where((s) => s.isEnabled != false && s.isAvailable != false)
          .toList();

      // Extract categories from shop's customCategories or auto-detect from services
      final List<String> categories = ['All'];
      if (shop.customCategories.isNotEmpty) {
        for (final cat in shop.customCategories) {
          if (cat.trim().isNotEmpty && !categories.contains(cat.trim())) {
            categories.add(cat.trim());
          }
        }
      } else {
        for (final s in allAvailableServices) {
          if (s.pricingType.isNotEmpty) {
            final label = s.pricingType == 'fixed'
                ? 'Fixed Price'
                : s.pricingType == 'starting'
                    ? 'Popular'
                    : s.pricingType == 'inspection'
                        ? 'Inspection'
                        : 'Special Offers';
            if (!categories.contains(label)) {
              categories.add(label);
            }
          }
        }
      }

      // Filter services by selected category
      final displayedServices = _selectedCategory == 'All'
          ? allAvailableServices
          : allAvailableServices.where((s) {
              final catLower = _selectedCategory.toLowerCase();
              final titleLower = s.title.toLowerCase();
              if (catLower == 'fixed price') return s.pricingType == 'fixed';
              if (catLower == 'popular') return s.pricingType == 'starting';
              if (catLower == 'inspection') return s.pricingType == 'inspection';
              return titleLower.contains(catLower) ||
                  s.pricingType.toLowerCase().contains(catLower);
            }).toList();

      final imageToUse = shop.imagePath.isNotEmpty
          ? shop.imagePath
          : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=500';

      return Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Cover Image Header with Back Button
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: isDark
                    ? AppColors.backgroundDark
                    : Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.black54
                        : Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Colors.white : AppColors.secondary,
                        size: 20,
                      ),
                      onPressed: () {
                        AppHaptics.lightTap();
                        context.pop();
                      },
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Image.network(imageToUse, fit: BoxFit.cover),
                ),
              ),

              // Shop Details Header Card
              SliverToBoxAdapter(
                child: ShopDetailsHeader(
                  shop: shop,
                  isDark: isDark,
                ),
              ),

              // Category Filter Bar (Urban Company Style)
              if (categories.length > 1)
                SliverToBoxAdapter(
                  child: ShopCategoryFilterBar(
                    categories: categories,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: (cat) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    isDark: isDark,
                  ),
                ),

              // Available Services Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 8.0,
                    bottom: 6.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Services (${displayedServices.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                      ),
                      if (shop.visitingCharges > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Visiting ₹${shop.visitingCharges.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Shop Services dynamic listings
              displayedServices.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                          child: Text(
                            'No services found in this category.',
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final service = displayedServices[index];
                        final quantity = cart[service.id]?.quantity ?? 0;
                        final isInCart = quantity > 0;

                        return ShopServiceItem(
                          service: service,
                          quantity: quantity,
                          isInCart: isInCart,
                          isDark: isDark,
                          onAddToCart: () => _handleAddToCart(service),
                          onRemoveFromCart: () => _handleRemoveFromCart(service),
                        );
                      }, childCount: displayedServices.length),
                    ),

              // Urban Company Trust Footer Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QuickFix Service Guarantee',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Trained experts • Verified pricing • 30-day post-service warranty',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Urban Company Style Floating Cart summary bar
          if (totalItems > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () {
                  AppHaptics.heavyTap();
                  context.push('/checkout');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${totalAmount.toInt()}',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '$totalItems Item(s) Selected',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'View Cart',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(
                    begin: 1.0,
                    end: 0.0,
                    duration: 250.ms,
                    curve: Curves.easeOutQuad,
                  ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: (_isLoading || _errorMessage.isNotEmpty || _shop == null)
          ? AppBar(title: const Text('Shop Details'))
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchShopDetails,
        child: buildBody(),
      ),
    );
  }


}
