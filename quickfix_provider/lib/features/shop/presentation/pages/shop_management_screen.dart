import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quickfix_provider/core/theme/app_colors.dart';
import 'package:quickfix_provider/features/auth/models/shop_model.dart';
import 'package:quickfix_provider/features/auth/presentation/controllers/auth_provider.dart';
import 'package:quickfix_provider/features/shop/presentation/controllers/shop_provider.dart';
import 'package:quickfix_provider/core/network/connectivity_provider.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/operational_settings_tab.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/catalog_tab.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/gallery_tab.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/add_service_dialog.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/edit_service_dialog.dart';
import 'package:quickfix_provider/features/shop/presentation/widgets/manage_categories_dialog.dart';

class ShopManagementScreen extends ConsumerStatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  ConsumerState<ShopManagementScreen> createState() =>
      _ShopManagementScreenState();
}

class _ShopManagementScreenState extends ConsumerState<ShopManagementScreen> {
  // Operations state
  late double _serviceRadius;
  late double _visitingCharges;
  late bool _emergencyAvailable;
  late List<String> _holidays;
  late Map<String, dynamic> _workingHours;

  // Shop card display fields
  String _estimatedServiceTime = '20 mins';
  String _priceRange = '₹₹';
  bool _bannerUploading = false;
  bool _portfolioUploading = false;

  bool _initialized = false;

  void _initFields() {
    if (_initialized) return;
    final shop = ref.read(authProvider).shop;
    if (shop != null) {
      _serviceRadius = shop.serviceRadius;
      _visitingCharges = shop.visitingCharges;
      _emergencyAvailable = shop.emergencyAvailable;
      _holidays = List<String>.from(shop.holidays);
      _workingHours = Map<String, dynamic>.from(shop.workingHours);
      _estimatedServiceTime = shop.estimatedServiceTime;
      _priceRange = shop.priceRange;
      _initialized = true;
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = picked.mimeType ?? 'image/jpeg';

    setState(() => _bannerUploading = true);
    final success = await ref
        .read(authProvider.notifier)
        .uploadShopBanner(base64Image, mimeType);
    setState(() => _bannerUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Shop banner updated!' : 'Failed to upload banner.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _pickAndUploadPortfolio() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = picked.mimeType ?? 'image/jpeg';

    setState(() => _portfolioUploading = true);
    final success = await ref
        .read(authProvider.notifier)
        .uploadPortfolioImage(base64Image, mimeType);
    setState(() => _portfolioUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Gallery image added!' : 'Failed to upload image.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deletePortfolioImage(String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
          'Are you sure you want to delete this image from your gallery?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _portfolioUploading = true);
    final success = await ref
        .read(authProvider.notifier)
        .deletePortfolioImage(imageUrl);
    setState(() => _portfolioUploading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Image deleted from gallery!' : 'Failed to delete image.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _saveShopCardFields() async {
    final success = await ref
        .read(authProvider.notifier)
        .updateShopDetails(
          estimatedServiceTime: _estimatedServiceTime,
          priceRange: _priceRange,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop card details updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _saveOperationalHours() async {
    final success = await ref
        .read(shopManagementProvider.notifier)
        .updateOperationalHours(
          workingHours: _workingHours,
          holidays: _holidays,
          serviceRadius: _serviceRadius,
          visitingCharges: _visitingCharges,
          emergencyAvailable: _emergencyAvailable,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operational parameters updated!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _addHolidayDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Holiday Date'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 15 Aug 2026',
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _holidays.add(controller.text.trim());
                });
                Navigator.pop(context);
                _saveOperationalHours();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddServiceDialog(),
    );
  }

  void _showManageCategoriesDialog(ShopModel shop) {
    showDialog(
      context: context,
      builder: (context) => ManageCategoriesDialog(shop: shop),
    );
  }

  void _showEditServiceDetailsDialog(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (context) => EditServiceDialog(service: service),
    );
  }

  Future<void> _deleteServiceConfirm(Map<String, dynamic> service) async {
    final title = service['title']?.toString() ?? '';
    final serviceId = service['id']?.toString() ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await ref.read(shopManagementProvider.notifier).deleteService(serviceId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service deleted.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-retry on internet reconnection if previously failed
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true && previous?.value == false) {
        ref.read(authProvider.notifier).refreshProfile();
      }
    });

    if (authState.shop == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: const Center(child: Text('Please log in first')),
      );
    }

    _initFields();

    final shop = authState.shop!;
    // Parse services
    final services = shop.toJson()['services'] as List? ?? [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Shop Management'),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white54,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Settings'),
              Tab(text: 'Catalog'),
              Tab(text: 'Gallery'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OperationalSettingsTab(
              shop: shop,
              isDark: isDark,
              estimatedServiceTime: _estimatedServiceTime,
              priceRange: _priceRange,
              serviceRadius: _serviceRadius,
              visitingCharges: _visitingCharges,
              emergencyAvailable: _emergencyAvailable,
              holidays: _holidays,
              workingHours: _workingHours,
              bannerUploading: _bannerUploading,
              onPickAndUploadBanner: _pickAndUploadBanner,
              onSaveShopCardFields: _saveShopCardFields,
              onAddHolidayDialog: _addHolidayDialog,
              onEstimatedServiceTimeChanged: (val) => setState(() => _estimatedServiceTime = val),
              onPriceRangeChanged: (val) => setState(() => _priceRange = val),
              onServiceRadiusChanged: (val) {
                setState(() {
                  _serviceRadius = val;
                });
              },
              onVisitingChargesChanged: (val) {
                setState(() {
                  _visitingCharges = val;
                });
                _saveOperationalHours();
              },
              onEmergencyAvailableChanged: (val) {
                setState(() {
                  _emergencyAvailable = val;
                });
                _saveOperationalHours();
              },
              onToggleWorkingDay: (day, val) {
                setState(() {
                  _workingHours[day]['isClosed'] = !val;
                });
                _saveOperationalHours();
              },
              onRemoveHoliday: (date) {
                setState(() {
                  _holidays.remove(date);
                });
                _saveOperationalHours();
              },
              onManageCategories: () => _showManageCategoriesDialog(shop),
            ),
            CatalogTab(
              services: services,
              isDark: isDark,
              onAddService: _showAddServiceDialog,
              onEditService: _showEditServiceDetailsDialog,
              onToggleService: (serviceId, val) {
                ref.read(shopManagementProvider.notifier).toggleService(serviceId, val);
              },
              onDeleteService: _deleteServiceConfirm,
            ),
            GalleryTab(
              portfolioImages: List<String>.from(shop.portfolioImages),
              portfolioUploading: _portfolioUploading,
              onPickAndUploadPortfolio: _pickAndUploadPortfolio,
              onDeletePortfolioImage: _deletePortfolioImage,
            ),
          ],
        ),
      ),
    );
  }
}
