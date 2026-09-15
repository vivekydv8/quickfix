class ApiEndpoints {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'https://quickfix-production-4c09.up.railway.app/api';

  // Provider Auth
  static const String login = '/provider/login';
  static const String changePassword = '/provider/change-password';
  static const String updateFcmToken = '/provider/update-fcm';

  // Dashboard
  static String dashboard(String shopId) => '/provider/dashboard/$shopId';
  static const String toggleOnline = '/provider/toggle-online';

  // Bookings
  static const String bookings = '/bookings';
  static const String updateBookingStatus = '/bookings/update-status';
  static String bookingDetails(String bookingId) =>
      '/bookings/details/$bookingId';

  // Shop & Services
  static const String updateHours = '/provider/update-hours';
  static const String updateServices = '/provider/update-services';
  static const String updateLocation = '/provider/update-location';
  static const String uploadServiceImage = '/provider/upload-service-image';

  // Earnings
  static String earnings(String shopId) => '/provider/earnings/$shopId';

  // Payment System
  static String paymentDashboard(String shopId) =>
      '/payments/dashboard/provider/$shopId';
  static String providerSettlements(String shopId) =>
      '/payments/settlements/shop/$shopId';
  static String providerLedger(String shopId) =>
      '/payments/ledger/shop/$shopId';
  static const String requestSettlement = '/payments/settlements/request';
  static String cashConfirm(String bookingId) =>
      '/payments/cash-confirm/$bookingId';
  static String bookingLedger(String bookingId) =>
      '/payments/ledger/$bookingId';

  // Reviews
  static const String replyReview = '/provider/reply-review';
  static String shopReviews(String shopId) => '/reviews/shop/$shopId';
}
