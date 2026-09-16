import 'package:dio/dio.dart';
import 'package:quickfix_provider/core/network/api_endpoints.dart';
import 'package:quickfix_provider/core/network/dio_client.dart';

abstract class BookingsRemoteDataSource {
  Future<Response> fetchBookings(String shopId);
  Future<Response> fetchBookingDetails(String bookingId);
  Future<Response> updateStatus({
    required String bookingId,
    required String status,
    required String providerName,
    String? shopId,
  });
  Future<Response> uploadQuotation(String bookingId, Map<String, dynamic> quotationData);
  Future<Response> updateLiveLocation(double latitude, double longitude);
}

class BookingsRemoteDataSourceImpl implements BookingsRemoteDataSource {
  final DioClient _dioClient;

  BookingsRemoteDataSourceImpl(this._dioClient);

  @override
  Future<Response> fetchBookings(String shopId) {
    return _dioClient.get(
      ApiEndpoints.bookings,
      queryParameters: {'shopId': shopId},
    );
  }

  @override
  Future<Response> fetchBookingDetails(String bookingId) {
    return _dioClient.get(ApiEndpoints.bookingDetails(bookingId));
  }

  @override
  Future<Response> updateStatus({
    required String bookingId,
    required String status,
    required String providerName,
    String? shopId,
  }) {
    return _dioClient.post(
      ApiEndpoints.updateBookingStatus,
      data: {
        'id': bookingId,
        'status': status,
        'providerName': providerName,
        if (shopId != null) 'shopId': shopId,
      },
    );
  }

  @override
  Future<Response> uploadQuotation(String bookingId, Map<String, dynamic> quotationData) {
    return _dioClient.post(
      '/bookings/$bookingId/quotation',
      data: quotationData,
    );
  }

  @override
  Future<Response> updateLiveLocation(double latitude, double longitude) {
    return _dioClient.post(
      ApiEndpoints.updateLocation,
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }
}
