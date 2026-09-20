import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix/core/network/network_providers.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/core/storage/secure_token_manager.dart';
import 'package:quickfix/features/auth/datasources/auth_remote_data_source.dart';
import 'package:quickfix/features/auth/repositories/auth_repository.dart';
import 'package:quickfix/features/auth/repositories/auth_repository_impl.dart';
import 'package:quickfix/core/network/error_handler.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Represents the state of the user's authentication workflow.
class AuthState {
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Controller responsible for managing user login, registration, wallets, profile pictures, and logout actions.
/// 
/// Interacts with [AuthRepository] to execute operations and syncs state reactively.
/// Performs background synchronization of FCM push tokens.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository)
    : super(AuthState(isAuthenticated: false, isLoading: true)) {
    checkSession();
  }

  /// **Caching & Authentication**: Checks for existing sessions on app initialization.
  /// 
  /// Read cached token and user profile from Hive. If a token is found, the user is instantly authenticated
  /// to prevent splash delays. It then silently refreshes the profile and coordinates updates of FCM tokens.
  /// **Offline Fallback**: If network fails, the user remains authenticated with local cached configurations
  /// instead of logging out, allowing full offline read access.
  Future<void> checkSession() async {
    final token = HiveService.getAuthToken();
    if (token == null) {
      state = AuthState(isAuthenticated: false, isLoading: false);
      return;
    }

    final cached = HiveService.getCachedProfile();
    if (cached != null) {
      state = AuthState(isAuthenticated: true, user: cached, isLoading: false);
      _refreshProfileSilently();
      syncFcmTokenSilently();
    } else {
      try {
        state = AuthState(isAuthenticated: false, isLoading: true);
        final profile = await _repository.fetchUserProfile().timeout(
          const Duration(milliseconds: 2500),
        );
        await HiveService.saveCachedProfile(profile);
        state = AuthState(
          isAuthenticated: true,
          user: profile,
          isLoading: false,
        );
        syncFcmTokenSilently();
      } catch (e, s) {
        final resolved = ErrorHandler.handle(e, s);
        if (HiveService.getAuthToken() == null) {
          state = AuthState(isAuthenticated: false, isLoading: false);
        } else {
          // Offline mode: minimal fallback with NO hardcoded fake data
          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            error: resolved.message,
            user: {
              'phone': 'Unknown',
              'name': '',
              'email': '',
              'membership': 'basic',
              'walletBalance': 0.0,
              'savedAddresses': <dynamic>[],
              'avatarUrl': '',
              'isPhoneVerified': true,
              'accountStatus': 'active',
              'referralCode': '',
              'referralCount': 0,
              'referralRewardsEarned': 0,
            },
          );
        }
      }
    }
  }

  Future<void> syncFcmTokenSilently() async {
    try {
      final fcmToken = await NotificationService.getToken().timeout(
        const Duration(seconds: 2),
      );
      if (fcmToken != null) {
        final cached = HiveService.getCachedProfile();
        if (cached == null || cached['fcmToken'] != fcmToken) {
          await _repository.updateUserProfile({'fcmToken': fcmToken}).timeout(
            const Duration(seconds: 2),
          );
          if (cached != null) {
            final updatedProfile = Map<String, dynamic>.from(cached);
            updatedProfile['fcmToken'] = fcmToken;
            await HiveService.saveCachedProfile(updatedProfile);
            state = state.copyWith(user: updatedProfile);
          }
        }
        await NotificationService.subscribeToTopic('customers');
      }
    } catch (_) {}
  }

  Future<void> _refreshProfileSilently() async {
    try {
      final profile = await _repository.fetchUserProfile().timeout(
        const Duration(seconds: 3),
      );
      await HiveService.saveCachedProfile(profile);
      state = AuthState(isAuthenticated: true, user: profile, isLoading: false);
    } catch (e, s) {
      ErrorHandler.handle(e, s);
      if (HiveService.getAuthToken() == null) {
        state = AuthState(isAuthenticated: false, isLoading: false);
      }
      // Silently keep cached state on network error
    }
  }

  /// **Authentication & Firebase**: Logs user in using SMS verification code.
  /// 
  /// Validates phone number/code with the remote server. After login, it updates the profile cache,
  /// triggers push notification permissions dialogs, retrieves the new FCM token, and syncs it to the backend.
  Future<void> _clearPreviousUserNotificationHistory() async {
    try {
      final box = Hive.box('local_notifications');
      await box.clear();
      await HiveService.clearDataCache('user_notifications');
      await HiveService.clearDataCache('profile_offers');
    } catch (_) {}
  }

  Future<void> login(String phone, String code, {String? firebaseToken}) async {
    state = AuthState(isAuthenticated: false, isLoading: true);
    try {
      await _clearPreviousUserNotificationHistory();
      await _repository.verifyCode(phone, code, firebaseToken: firebaseToken);
      final profile = await _repository.fetchUserProfile();
      await HiveService.saveCachedProfile(profile);
      state = AuthState(isAuthenticated: true, user: profile, isLoading: false);

      // Trigger FCM registration and topic subscription on login
      await NotificationService.onUserLoggedIn();
    } catch (e, s) {
      final resolved = ErrorHandler.handle(e, s);
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: resolved.message,
      );
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updateData) async {
    state = state.copyWith(isLoading: true);
    try {
      final updatedProfile = await _repository.updateUserProfile(updateData);
      await HiveService.saveCachedProfile(updatedProfile);
      state = AuthState(
        isAuthenticated: true,
        user: updatedProfile,
        isLoading: false,
      );
    } catch (e, s) {
      final resolved = ErrorHandler.handle(e, s);
      state = state.copyWith(isLoading: false, error: resolved.message);
      rethrow;
    }
  }

  Future<String> uploadAvatar(String base64Image, String mimeType) async {
    state = state.copyWith(isLoading: true);
    try {
      final avatarUrl = await _repository.uploadAvatar(base64Image, mimeType);
      if (state.user != null) {
        final updatedUser = Map<String, dynamic>.from(state.user!);
        updatedUser['avatarUrl'] = avatarUrl;
        await HiveService.saveCachedProfile(updatedUser);
        state = AuthState(
          isAuthenticated: true,
          user: updatedUser,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return avatarUrl;
    } catch (e, s) {
      final resolved = ErrorHandler.handle(e, s);
      state = state.copyWith(isLoading: false, error: resolved.message);
      rethrow;
    }
  }

  /// **Business Purpose & Caching**: Credits money to the user's platform wallet balance.
  /// 
  /// Communicates with Razorpay SDK or payment APIs to credit funds, updates local state
  /// mapping with the new balance and transactions list, and updates Hive cache.
  Future<void> addMoney(double amount) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _repository.addMoneyToWallet(amount);
      if (state.user != null) {
        final updatedUser = Map<String, dynamic>.from(state.user!);
        updatedUser['walletBalance'] = res['walletBalance'];
        updatedUser['walletTransactions'] = res['walletTransactions'];
        await HiveService.saveCachedProfile(updatedUser);
        state = AuthState(
          isAuthenticated: true,
          user: updatedUser,
          isLoading: false,
        );
      }
    } catch (e, s) {
      final resolved = ErrorHandler.handle(e, s);
      state = state.copyWith(isLoading: false, error: resolved.message);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteAccount();
      await SecureTokenManager.clearToken(
        clearCallback: HiveService.clearAuthToken,
      );
      await HiveService.clearCachedProfile();
      state = AuthState(isAuthenticated: false, isLoading: false);
    } catch (e, s) {
      final resolved = ErrorHandler.handle(e, s);
      state = state.copyWith(isLoading: false, error: resolved.message);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = AuthState(isAuthenticated: false, isLoading: true);
    try {
      await NotificationService.unsubscribeFromTopic('customers');
      await _repository.updateUserProfile({'fcmToken': ''});
    } catch (_) {}
    await SecureTokenManager.clearToken(
      clearCallback: HiveService.clearAuthToken,
    );
    await HiveService.clearCachedProfile();
    try {
      final box = Hive.box('local_notifications');
      await box.clear();
    } catch (_) {}
    await HiveService.clearDataCache('user_notifications');
    await NotificationService.cancelAllNotifications();
    state = AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final client = ref.watch(dioClientProvider);
  return AuthRemoteDataSource(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remote);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final notifier = AuthNotifier(repo);
  
  ref.read(dioClientProvider).onUnauthorized.listen((_) {
    notifier.logout();
  });
  
  return notifier;
});

// Profile Future Provider (reactive fallback wrapper for screen compatibility)
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.user != null) {
    return auth.user!;
  }
  final repository = ref.watch(authRepositoryProvider);
  return repository.fetchUserProfile();
});
