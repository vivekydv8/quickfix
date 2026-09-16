import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix_provider/core/network/network_providers.dart';
import 'package:quickfix_provider/features/bookings/datasources/bookings_remote_data_source.dart';
import 'package:quickfix_provider/features/bookings/models/booking_model.dart';
import 'package:quickfix_provider/features/bookings/repositories/bookings_repository.dart';

class BookingsRepositoryImpl implements BookingsRepository {
  final BookingsRemoteDataSource _remoteDataSource;

  BookingsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<BookingModel>> fetchBookings(String shopId) async {
    final response = await _remoteDataSource.fetchBookings(shopId);
    if (response.data is List) {
      return (response.data as List)
          .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Invalid bookings response format');
  }

  @override
  Future<BookingModel?> fetchBookingDetails(String bookingId) async {
    final response = await _remoteDataSource.fetchBookingDetails(bookingId);
    if (response.data != null) {
      return BookingModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<BookingModel?> updateStatus({
    required String bookingId,
    required String status,
    required String providerName,
    String? shopId,
  }) async {
    final response = await _remoteDataSource.updateStatus(
      bookingId: bookingId,
      status: status,
      providerName: providerName,
      shopId: shopId,
    );

    if (response.data != null && response.data['success'] == true) {
      if (response.data['booking'] != null) {
        return BookingModel.fromJson(
          response.data['booking'] as Map<String, dynamic>,
        );
      }
    }
    return null;
  }

  @override
  Future<bool> uploadQuotation({
    required String bookingId,
    required double labourCharge,
    required double spareParts,
    required double additionalMaterials,
    required double visitingCharges,
    required double discount,
    required double gst,
  }) async {
    final response = await _remoteDataSource.uploadQuotation(
      bookingId,
      {
        'labourCharge': labourCharge,
        'spareParts': spareParts,
        'additionalMaterials': additionalMaterials,
        'visitingCharges': visitingCharges,
        'discount': discount,
        'gst': gst,
      },
    );
    if (response.data != null && response.data['success'] == true) {
      return true;
    }
    return false;
  }

  @override
  Future<bool> updateLiveLocation(double latitude, double longitude) async {
    final response = await _remoteDataSource.updateLiveLocation(latitude, longitude);
    return response.statusCode == 200 || response.statusCode == 201;
  }
}

final bookingsRemoteDataSourceProvider = Provider<BookingsRemoteDataSource>((ref) {
  return BookingsRemoteDataSourceImpl(ref.watch(dioClientProvider));
});

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepositoryImpl(ref.watch(bookingsRemoteDataSourceProvider));
});
