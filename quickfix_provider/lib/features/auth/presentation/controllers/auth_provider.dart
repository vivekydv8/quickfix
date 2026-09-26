import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix_provider/core/network/network_providers.dart';
import 'package:quickfix_provider/core/storage/hive_service.dart';
import 'package:quickfix_provider/features/auth/models/shop_model.dart';
import 'package:quickfix_provider/core/services/notification_service.dart';
import 'package:quickfix_provider/core/logging/app_logger.dart';
import 'package:quickfix_provider/features/auth/repositories/auth_repository_impl.dart';
import 'package:quickfix_provider/core/network/error_handler.dart';

/// Represents the state of the partner's authentication workflow.
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final ShopModel? shop;
  final bool isAuthenticated;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.shop,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    ShopModel? shop,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      shop: shop ?? this.shop,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Controller responsible for managing provider login, password resets, shop details,
/// and uploading banners/portfolios.
/// 
/// Interacts with [AuthRepository] to perform credential validation, profile caching, etc.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState()) {
    checkSession();
    _ref.read(dioClientProvider).onUnauthorized.listen((_) {
      logout();
    });
  }

  void checkSession() {
    final token = HiveService.getAuthToken();
    final cachedProfile = HiveService.getShopProfile();
    if (token != null && cachedProfile != null) {
      state = AuthState(
        isAuthenticated: true,
        shop: ShopModel.fromJson(cachedProfile),
      );
    }
  }

  Future<bool> login(String shopId, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);
      final shop = await repository.login(shopId, password);

      if (shop != null) {
        state = AuthState(isAuthenticated: true, shop: shop);

        // Request permissions and sync FCM token with backend
        NotificationService.onProviderLoggedIn();

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Login failed. Please check credentials.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);
      final success = await repository.changePassword(oldPassword, newPassword);

      if (success) {
        // Password changed, update local shop cache to set isFirstLogin = false
        if (state.shop != null) {
          final updatedShopJson = state.shop!.toJson();
          updatedShopJson['isFirstLogin'] = false;
          final updatedShop = ShopModel.fromJson(updatedShopJson);
          await HiveService.saveShopProfile(updatedShop.toJson());
          state = state.copyWith(isLoading: false, shop: updatedShop);
        } else {
          state = state.copyWith(isLoading: false);
        }
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update password.',
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

  Future<bool> updateShopDetails({
    Map<String, dynamic>? workingHours,
    List<String>? holidays,
    double? serviceRadius,
    double? visitingCharges,
    bool? emergencyAvailable,
    String? gst,
    String? pan,
    String? bankAccountNumber,
    String? ifscCode,
    String? upiId,
    bool? isFirstLogin,
    double? walletBalance,
    List<dynamic>? walletTransactions,
    String? ownerPhone,
    String? ownerEmail,
    String? estimatedServiceTime,
    String? priceRange,
    List<String>? categories,
    List<String>? subcategories,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);

      final dataToSend = <String, dynamic>{};
      if (workingHours != null) dataToSend['workingHours'] = workingHours;
      if (holidays != null) dataToSend['holidays'] = holidays;
      if (serviceRadius != null) dataToSend['serviceRadius'] = serviceRadius;
      if (visitingCharges != null) dataToSend['visitingCharges'] = visitingCharges;
      if (emergencyAvailable != null) dataToSend['emergencyAvailable'] = emergencyAvailable;
      if (gst != null) dataToSend['gst'] = gst;
      if (pan != null) dataToSend['pan'] = pan;
      if (bankAccountNumber != null) dataToSend['bankAccountNumber'] = bankAccountNumber;
      if (ifscCode != null) dataToSend['ifscCode'] = ifscCode;
      if (upiId != null) dataToSend['upiId'] = upiId;
      if (isFirstLogin != null) dataToSend['isFirstLogin'] = isFirstLogin;
      if (walletBalance != null) dataToSend['walletBalance'] = walletBalance;
      if (walletTransactions != null) dataToSend['walletTransactions'] = walletTransactions;
      if (ownerPhone != null) dataToSend['ownerPhone'] = ownerPhone;
      if (ownerEmail != null) dataToSend['ownerEmail'] = ownerEmail;
      if (estimatedServiceTime != null) dataToSend['estimatedServiceTime'] = estimatedServiceTime;
      if (priceRange != null) dataToSend['priceRange'] = priceRange;
      if (categories != null) dataToSend['categories'] = categories;
      if (subcategories != null) dataToSend['subcategories'] = subcategories;

      final shop = await repository.updateShopDetails(dataToSend);

      if (shop != null) {
        state = state.copyWith(isLoading: false, shop: shop);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update shop details.',
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

  Future<void> refreshProfile() async {
    if (state.shop == null) return;
    try {
      final repository = _ref.read(authRepositoryProvider);
      final shop = await repository.getProfile();
      if (shop != null) {
        state = state.copyWith(shop: shop);
      }
    } catch (e) {
      AppLogger.warning('Refresh profile error', tag: 'Auth', error: e);
    }
  }

  Future<bool> uploadShopBanner(String base64Image, String mimeType) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);
      final newImagePath = await repository.uploadShopBanner(base64Image, mimeType);

      if (newImagePath != null && newImagePath.isNotEmpty) {
        if (state.shop != null) {
          final updatedShopJson = state.shop!.toJson();
          updatedShopJson['imagePath'] = newImagePath;
          final updatedShop = ShopModel.fromJson(updatedShopJson);
          await HiveService.saveShopProfile(updatedShop.toJson());
          state = state.copyWith(isLoading: false, shop: updatedShop);
          return true;
        }
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to upload shop banner.',
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

  Future<bool> uploadPortfolioImage(String base64Image, String mimeType) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);
      final newImages = await repository.uploadPortfolioImage(base64Image, mimeType);

      if (newImages != null) {
        if (state.shop != null) {
          final updatedShopJson = state.shop!.toJson();
          updatedShopJson['portfolioImages'] = newImages;
          final updatedShop = ShopModel.fromJson(updatedShopJson);
          await HiveService.saveShopProfile(updatedShop.toJson());
          state = state.copyWith(isLoading: false, shop: updatedShop);
          return true;
        }
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to upload portfolio image.',
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

  Future<bool> deletePortfolioImage(String imageUrl) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(authRepositoryProvider);
      final newImages = await repository.deletePortfolioImage(imageUrl);

      if (newImages != null) {
        if (state.shop != null) {
          final updatedShopJson = state.shop!.toJson();
          updatedShopJson['portfolioImages'] = newImages;
          final updatedShop = ShopModel.fromJson(updatedShopJson);
          await HiveService.saveShopProfile(updatedShop.toJson());
          state = state.copyWith(isLoading: false, shop: updatedShop);
          return true;
        }
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete portfolio image.',
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

  Future<void> logout() async {
    await HiveService.clearSession();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
