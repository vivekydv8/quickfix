import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quickfix_provider/features/auth/presentation/controllers/auth_provider.dart';
import 'package:quickfix_provider/features/dashboard/presentation/controllers/dashboard_provider.dart';
import 'package:quickfix_provider/features/bookings/models/booking_model.dart';
import 'package:quickfix_provider/core/logging/app_logger.dart';
import 'package:quickfix_provider/features/bookings/repositories/bookings_repository_impl.dart';
import 'package:quickfix_provider/core/network/error_handler.dart';

/// Represents the state of service bookings queue for the partner.
class BookingsState {
  final bool isLoading;
  final String? errorMessage;
  final List<BookingModel> bookings;
  final BookingModel? selectedBookingDetails;

  BookingsState({
    this.isLoading = false,
    this.errorMessage,
    this.bookings = const [],
    this.selectedBookingDetails,
  });

  BookingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<BookingModel>? bookings,
    BookingModel? selectedBookingDetails,
  }) {
    return BookingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      bookings: bookings ?? this.bookings,
      selectedBookingDetails:
          selectedBookingDetails ?? this.selectedBookingDetails,
    );
  }
}

/// Controller responsible for managing incoming jobs, status transitions,
/// submitting quotations, and starting live GPS tracking via Geolocator.
class BookingsNotifier extends StateNotifier<BookingsState> {
  final Ref _ref;
  Timer? _refreshTimer;
  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionSubscription;

  BookingsNotifier(this._ref) : super(BookingsState()) {
    fetchBookings();
    // Auto-refresh bookings every 30 seconds for live requests
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchBookings(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _trackingTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchBookings({bool silent = false}) async {
    final shop = _ref.read(authProvider).shop;
    if (shop == null) return;

    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    try {
      final repository = _ref.read(bookingsRepositoryProvider);
      final list = await repository.fetchBookings(shop.id);
      state = state.copyWith(isLoading: false, bookings: list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
    }
  }

  Future<void> fetchBookingDetails(String bookingId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(bookingsRepositoryProvider);
      final details = await repository.fetchBookingDetails(bookingId);
      if (details != null) {
        state = state.copyWith(
          isLoading: false,
          selectedBookingDetails: details,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load booking details',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorHandler.handle(e).message,
      );
    }
  }

  /// Updates a booking order status and syncs with the remote server.
  /// 
  /// Triggers related events depending on the transition:
  /// - Starts background location tracking when status is set to `navigating`.
  /// - Automatically cancels/stops background tracking when status transitions to `work_completed`, `payment_completed`, `cancelled`, or `closed`.
  /// Also refreshes dashboard and order queues.
  Future<bool> updateStatus(String bookingId, String status) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final shop = _ref.read(authProvider).shop;
      final repository = _ref.read(bookingsRepositoryProvider);
      final updatedBooking = await repository.updateStatus(
        bookingId: bookingId,
        status: status,
        providerName: shop?.ownerName ?? 'Partner Service Agent',
        shopId: shop?.id,
      );

      if (updatedBooking != null) {
        // Refresh stats and listing
        await fetchBookings(silent: true);
        await _ref.read(dashboardProvider.notifier).fetchStats();

        // Update currently viewed detail if it is the same one
        if (state.selectedBookingDetails?.id == bookingId) {
          state = state.copyWith(
            isLoading: false,
            selectedBookingDetails: updatedBooking,
          );
        } else {
          state = state.copyWith(isLoading: false);
        }

        // Manage background tracking depending on new status
        if (status == 'navigating') {
          _startLocationTracking(bookingId);
        } else if (status == 'work_completed' ||
            status == 'payment_completed' ||
            status == 'cancelled' ||
            status == 'closed') {
          _stopLocationTracking();
        }

        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update status',
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

  Future<bool> uploadQuotation({
    required String bookingId,
    required double labourCharge,
    required double spareParts,
    required double additionalMaterials,
    required double visitingCharges,
    required double discount,
    required double gst,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = _ref.read(bookingsRepositoryProvider);
      final success = await repository.uploadQuotation(
        bookingId: bookingId,
        labourCharge: labourCharge,
        spareParts: spareParts,
        additionalMaterials: additionalMaterials,
        visitingCharges: visitingCharges,
        discount: discount,
        gst: gst,
      );

      if (success) {
        // Refresh details
        await fetchBookingDetails(bookingId);
        await fetchBookings(silent: true);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to upload quotation',
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

  // Live Location Tracking during Navigation
  Future<void> _startLocationTracking(String bookingId) async {
    _stopLocationTracking(); // Clear any previous tracking

    try {
      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        AppLogger.warning(
          'Geolocator permission denied. Live location update skipped.',
          tag: 'Tracking',
        );
        return;
      }

      // Start coordinates polling
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // Update location every 10 meters
            ),
          ).listen((Position position) async {
            try {
              final repository = _ref.read(bookingsRepositoryProvider);
              await repository.updateLiveLocation(position.latitude, position.longitude);
              AppLogger.info(
                'Sent partner live coordinates: ${position.latitude}, ${position.longitude}',
                tag: 'Tracking',
              );
            } catch (e) {
              AppLogger.warning('Failed to sync live position', tag: 'Tracking', error: e);
            }
          });
    } catch (err) {
      AppLogger.error('Error starting background stream', tag: 'Tracking', error: err);
    }
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }
}

final bookingsProvider = StateNotifierProvider<BookingsNotifier, BookingsState>(
  (ref) {
    return BookingsNotifier(ref);
  },
);
