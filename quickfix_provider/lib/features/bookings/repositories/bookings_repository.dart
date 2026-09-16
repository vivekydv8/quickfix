import 'package:quickfix_provider/features/bookings/models/booking_model.dart';

abstract class BookingsRepository {
  Future<List<BookingModel>> fetchBookings(String shopId);
  Future<BookingModel?> fetchBookingDetails(String bookingId);
  Future<BookingModel?> updateStatus({
    required String bookingId,
    required String status,
    required String providerName,
    String? shopId,
  });
  Future<bool> uploadQuotation({
    required String bookingId,
    required double labourCharge,
    required double spareParts,
    required double additionalMaterials,
    required double visitingCharges,
    required double discount,
    required double gst,
  });
  Future<bool> updateLiveLocation(double latitude, double longitude);
}
