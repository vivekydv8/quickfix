import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/repositories/home_repository.dart';
import 'package:quickfix/features/home/repositories/home_repository_impl.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:dio/dio.dart';

import 'package:quickfix/core/network/network_providers.dart';
import 'package:quickfix/features/home/datasources/home_remote_data_source.dart';

// Remote Data Source Provider
final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  final client = ref.watch(dioClientProvider);
  return HomeRemoteDataSource(client);
});

// Repository Provider
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final remote = ref.watch(homeRemoteDataSourceProvider);
  return HomeRepositoryImpl(remote);
});

// Categories Provider
final categoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final list = await repository.getCategories();
  final normalized = list
      .where(
        (category) =>
            category.id.trim().isNotEmpty && category.name.trim().isNotEmpty,
      )
      .toList();

  return normalized;
});

// Selected Nearby Shop Filter Tag Provider
final selectedNearbyFilterProvider = StateProvider<String>((ref) => 'All');

// Nearby Shops Provider (reactive to filters & location)
final nearbyShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final activeFilter = ref.watch(selectedNearbyFilterProvider);
  final location = ref.watch(currentAddressProvider);

  return repository.getNearbyShops(
    filter: activeFilter,
    lat: location.latitude,
    lng: location.longitude,
  );
});

// Top Rated Professionals Provider (location range filtered)
final topProfessionalsProvider = FutureProvider<List<Professional>>((
  ref,
) async {
  final repository = ref.watch(homeRepositoryProvider);
  final location = ref.watch(currentAddressProvider);
  return repository.getTopProfessionals(
    lat: location.latitude,
    lng: location.longitude,
  );
});


// Promo Banners Provider
final bannersProvider = FutureProvider<List<PromoBanner>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getBanners();
});

// Promotions Provider
final promotionsProvider = FutureProvider<List<Promotion>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getPromotions();
});

// Special Cards Provider
final specialCardsProvider = FutureProvider<List<SpecialCard>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getSpecialCards();
});

// Homepage Layout Provider
final homepageLayoutProvider = FutureProvider<List<CmsSection>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getHomepageLayout();
});

// Custom Homepage Sections Provider
final customSectionsProvider = FutureProvider<List<CustomSection>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getCustomSections();
});

// App Settings Provider (Support number, tax rate, etc.)
final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getAppSettings();
});

// Cart Shop ID Tracker Provider
final cartShopIdProvider = StateProvider<String?>((ref) {
  try {
    final cached = HiveService.getDataCache('cart_shop_id');
    if (cached != null && cached is String && cached.isNotEmpty) {
      return cached;
    }
  } catch (_) {}
  return null;
});

// Customer Reviews Provider
final customerReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getCustomerReviews();
});

// Active Navigation Bar Index
final currentNavIndexProvider = StateProvider<int>((ref) => 0);

// Location Provider
/// Controller responsible for managing and geolocating the user's current physical address.
/// 
/// **Business Purpose**: Provides location-based filters for nearby shops, calculating delivery/travel ranges.
/// **Data Flow**: Read from Hive Cache -> Fetch coordinates from GPS -> Call OSM API for address string -> Notify UI -> Cache back to Hive.
class LocationNotifier extends StateNotifier<UserLocation> {
  LocationNotifier() : super(_getInitialLocation()) {
    fetchCurrentLocationAutomatically();
  }

  /// **Caching**: Retrieves initial location on startup.
  /// 
  /// Checks active selected location first, then saved address from [HiveService],
  /// falling back to a placeholder state while GPS updates in background.
  static UserLocation _getInitialLocation() {
    final cached = HiveService.getActiveLocation();
    if (cached != null) {
      return UserLocation.fromJson(cached);
    }
    final address = HiveService.getSavedAddress();
    if (address.isNotEmpty) {
      return UserLocation(address: address, latitude: 0.0, longitude: 0.0);
    }
    return const UserLocation(
      address: 'Detecting Location...',
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  /// **Complex Calculations & Logic**: Updates local coordinate state if it is a major movement.
  /// 
  /// Uses [Geolocator.distanceBetween] to calculate distance offset between the new coordinates
  /// and the old state. If the movement is less than 100 meters, the update is ignored.
  /// This optimizes performance and avoids repetitive reverse-geocoding API queries.
  void updateLocation(String address, double lat, double lng) {
    if (state.address == address &&
        state.latitude != 0.0 &&
        state.longitude != 0.0 &&
        lat != 0.0 &&
        lng != 0.0) {
      final double distance = Geolocator.distanceBetween(
        state.latitude,
        state.longitude,
        lat,
        lng,
      );
      if (distance < 100.0) {
        return; // Ignore small coordinate drift to avoid redundant API queries
      }
    }
    state = UserLocation(address: address, latitude: lat, longitude: lng);
    HiveService.saveAddress(address, lat: lat, lng: lng);
  }

  void updateAddress(String newAddress) {
    updateLocation(newAddress, state.latitude, state.longitude);
  }

  /// **API Usage**: Calls OpenStreetMap Nominatim reverse-geocoding API.
  /// 
  /// Queries OSM with coordinates to resolve a formatted address string.
  /// Standard user-agent header is set to prevent rate limiting.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          headers: {'User-Agent': 'QuickFixApp/1.0'},
        ),
      );
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': 1,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['display_name'] as String?;
      }
    } catch (e) {
      // Ignore reverse geocoding failures and fall back to coordinates.
    }
    return null;
  }

  Future<void> updateAddressFromCoordinates(double lat, double lng) async {
    final realAddress = await _reverseGeocode(lat, lng);
    if (realAddress != null && realAddress.trim().isNotEmpty) {
      updateLocation(realAddress, lat, lng);
    } else {
      updateLocation(
        "Latitude: ${lat.toStringAsFixed(4)}, Longitude: ${lng.toStringAsFixed(4)}",
        lat,
        lng,
      );
    }
  }

  /// **Important Logic**: Automatically fetches the user location silently on boot.
  /// 
  /// Inspects system-level location service status and permissions.
  /// Attempts to use [Geolocator.getLastKnownPosition] immediately for instant UI updates,
  /// then requests a fresh lock with fallback levels (Medium -> Low accuracy) and timeouts
  /// to prevent the application from hanging.
  Future<void> fetchCurrentLocationAutomatically() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        // Try last known location first for instant update
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          await updateAddressFromCoordinates(
            lastKnown.latitude,
            lastKnown.longitude,
          );
        }

        // Fetch current position with fallback to balanced/low accuracy to avoid hanging
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (_) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 4),
            );
          } catch (_) {
            if (lastKnown == null) {
              position = await Geolocator.getLastKnownPosition();
            }
          }
        }

        if (position != null) {
          await updateAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  /// **Important Logic**: Requests GPS location explicitly from user prompts.
  /// 
  /// Prompts for permissions if denied, returns early if denied forever, and executes
  /// the same multi-tiered fallback geolocating workflow.
  Future<bool> fetchGPSLocation({bool requestPermission = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      // Try last known location first for speed
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        updateAddressFromCoordinates(lastKnown.latitude, lastKnown.longitude);
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (_) {
          position = lastKnown ?? await Geolocator.getLastKnownPosition();
        }
      }

      if (position != null) {
        await updateAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        return true;
      }

      return lastKnown != null;
    } catch (e) {
      return false;
    }
  }
}

/// **Business Purpose**: Splits and formats long location addresses into a concise representation.
/// 
/// Truncates details like country, state, postal codes to return only local street/area indicators
/// that fit comfortably inside mobile app bar headers.
String getShortAddress(String address) {
  if (address.isEmpty) return 'Select Location';
  if (address.startsWith('Latitude:')) {
    return 'Current Location';
  }
  final parts = address.split(',');
  if (parts.isEmpty) return address;

  final first = parts[0].trim();
  if (first.length <= 4 ||
      RegExp(r'^\d+$').hasMatch(first) ||
      first.toLowerCase().startsWith('flat') ||
      first.toLowerCase().startsWith('shop') ||
      first.toLowerCase().startsWith('house') ||
      first.toLowerCase().startsWith('plot') ||
      first.toLowerCase().startsWith('block') ||
      first.toLowerCase().startsWith('no.')) {
    if (parts.length > 1) {
      final second = parts[1].trim();
      return '$first, $second';
    }
  }
  return first;
}

final currentAddressProvider =
    StateNotifierProvider<LocationNotifier, UserLocation>((ref) {
      return LocationNotifier();
    });

// Theme Mode Provider (Light/Dark)
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(HiveService.isDarkMode());

  void toggleTheme() {
    state = !state;
    HiveService.setDarkMode(state);
  }
}

final isDarkModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((
  ref,
) {
  return ThemeModeNotifier();
});

class WishlistNotifier extends StateNotifier<List<String>> {
  WishlistNotifier() : super(HiveService.getFavouriteProviderIds());

  void toggleFavourite(String id) {
    HiveService.toggleFavouriteProvider(id);
    state = HiveService.getFavouriteProviderIds();
  }

  bool isFavourite(String id) {
    return state.contains(id);
  }
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<String>>((
  ref,
) {
  return WishlistNotifier();
});


