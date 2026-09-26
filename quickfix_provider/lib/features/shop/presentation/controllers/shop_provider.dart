import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix_provider/features/auth/presentation/controllers/auth_provider.dart';
import 'package:quickfix_provider/features/shop/repositories/shop_repository_impl.dart';
import 'package:quickfix_provider/core/network/error_handler.dart';

/// Represents the state of shop parameters modification (such as adding custom services).
class ShopManagementState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  ShopManagementState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  ShopManagementState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ShopManagementState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// Controller responsible for configuring shop settings, toggling professional availability,
/// modifying price books, adding custom services, and uploading service imagery.
class ShopManagementNotifier extends StateNotifier<ShopManagementState> {
  final Ref _ref;

  ShopManagementNotifier(this._ref) : super(ShopManagementState());

  Future<bool> updateOperationalHours({
    required Map<String, dynamic> workingHours,
    required List<String> holidays,
    required double serviceRadius,
    required double visitingCharges,
    required bool emergencyAvailable,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final success = await _ref
          .read(authProvider.notifier)
          .updateShopDetails(
            workingHours: workingHours,
            holidays: holidays,
            serviceRadius: serviceRadius,
            visitingCharges: visitingCharges,
            emergencyAvailable: emergencyAvailable,
          );

      if (success) {
        state = ShopManagementState(isSuccess: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update shop parameters.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<bool> updateCategoriesAndSubcategories({
    required List<String> categories,
    required List<String> subcategories,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final success = await _ref
          .read(authProvider.notifier)
          .updateShopDetails(
            categories: categories,
            subcategories: subcategories,
          );

      if (success) {
        state = ShopManagementState(isSuccess: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update categories & subcategories.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<bool> toggleService(String serviceId, bool isEnabled) async {
    return updateServiceDetails(serviceId, {'isEnabled': isEnabled});
  }

  Future<bool> updateServicePrice(String serviceId, double newPrice) async {
    return updateServiceDetails(serviceId, {'price': newPrice});
  }

  Future<bool> updateServiceDetails(
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    final shop = _ref.read(authProvider).shop;
    if (shop == null) return false;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repository = _ref.read(shopRepositoryProvider);
      final servicesList = List<Map<String, dynamic>>.from(
        shop.toJson()['services'] as List? ?? [],
      );

      final updatedList = servicesList.map((s) {
        if (s['id'] == serviceId) {
          s.addAll(data);
        }
        return s;
      }).toList();

      final success = await repository.updateServices({'services': updatedList});

      if (success) {
        await _ref.read(authProvider.notifier).refreshProfile();
        state = ShopManagementState(isSuccess: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update service details.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<bool> addCustomService({
    required String title,
    required double price,
    required String durationText,
    required List<String> bulletPoints,
    String pricingType = 'fixed',
    double minPrice = 0,
    double maxPrice = 0,
    double visitingCharges = 0,
    bool isFreeInspection = false,
    double gst = 0,
    double extraCharges = 0,
    String extraChargesLabel = '',
    String? imageUrl,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repository = _ref.read(shopRepositoryProvider);
      final success = await repository.updateServices({
        'customService': {
          'title': title,
          'price': price,
          'durationText': durationText,
          'bulletPoints': bulletPoints,
          'pricingType': pricingType,
          'minPrice': minPrice,
          'maxPrice': maxPrice,
          'visitingCharges': visitingCharges,
          'isFreeInspection': isFreeInspection,
          'gst': gst,
          'extraCharges': extraCharges,
          'extraChargesLabel': extraChargesLabel,
          if (imageUrl != null) 'imageUrl': imageUrl,
        },
      });

      if (success) {
        await _ref.read(authProvider.notifier).refreshProfile();
        state = ShopManagementState(isSuccess: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add custom service.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<bool> deleteService(String serviceId) async {
    final shop = _ref.read(authProvider).shop;
    if (shop == null) return false;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );
    try {
      final repository = _ref.read(shopRepositoryProvider);
      final servicesList = List<Map<String, dynamic>>.from(
        shop.toJson()['services'] as List? ?? [],
      );

      final updatedList = servicesList
          .where((s) => s['id'] != serviceId)
          .toList();

      final success = await repository.updateServices({'services': updatedList});

      if (success) {
        await _ref.read(authProvider.notifier).refreshProfile();
        state = ShopManagementState(isSuccess: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete service.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<String?> uploadServiceImage(
    String base64Image,
    String mimeType,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(shopRepositoryProvider);
      final imageUrl = await repository.uploadServiceImage(base64Image, mimeType);

      if (imageUrl != null) {
        state = ShopManagementState(isSuccess: true);
        return imageUrl;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to upload service image.',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return null;
    }
  }
}

final shopManagementProvider =
    StateNotifierProvider<ShopManagementNotifier, ShopManagementState>((ref) {
      return ShopManagementNotifier(ref);
    });
