class ApiEndpoints {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'https://quickfix-production-4c09.up.railway.app/api';

  // Authentication
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String profile = '/auth/profile';

  // Home & Hyperlocal services
  static const String categories = '/categories';
  static const String subcategories = '/subcategories';
  static String categorySubcategories(String categoryId) =>
      '/categories/$categoryId/subcategories';
  static const String catalogServices = '/services';
  static String categoryCatalogServices(String categoryId) =>
      '/categories/$categoryId/services';
  static String subcategoryCatalogServices(String subcategoryId) =>
      '/subcategories/$subcategoryId/services';
  static const String searchCatalogServices = '/services/search';
  static const String shops = '/shops';
  static const String professionals = '/professionals';
  static const String reviews = '/reviews';
  static const String banners = '/banners';
  static const String promotions = '/promotions';
  static const String specialCards = '/special-cards';
  static const String homepageLayout = '/homepage/layout';
  static const String customSections = '/custom-sections';
  static const String settings = '/settings';


  // Bookings
  static const String packages = '/packages';
  static const String slots = '/bookings/slots';
  static const String validateCoupon = '/coupons/validate';
  static const String createBooking = '/bookings/create';
  static const String bookingHistory = '/bookings/history';
  static const String trackBooking = '/bookings/track';

  // Wallet
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String addMoney = '/wallet/add-money';

  // Support & Helpdesk AI
  static const String supportTickets = '/support/tickets';
  static const String ticketMessages = '/support/messages';
  static const String helpdeskChat = '/helpdesk/chat';
  static const String helpdeskUserTickets = '/helpdesk/tickets/user';
  static const String helpdeskTicketDetail = '/helpdesk/tickets/detail';
  static const String helpdeskKb = '/helpdesk/kb';

  // Payment Receipts
  static String bookingLedger(String bookingId) =>
      '/payments/ledger/$bookingId';
}
