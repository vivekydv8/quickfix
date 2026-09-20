import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/widgets/main_scaffold.dart';
import 'package:quickfix/features/auth/presentation/pages/splash_screen.dart';
import 'package:quickfix/features/auth/presentation/pages/onboarding_screen.dart';
import 'package:quickfix/features/auth/presentation/pages/login_screen.dart';
import 'package:quickfix/features/auth/presentation/pages/location_permission_screen.dart';
import 'package:quickfix/features/home/presentation/pages/home_screen.dart';
import 'package:quickfix/features/home/presentation/pages/search_screen.dart';
import 'package:quickfix/features/home/presentation/pages/shops_list_screen.dart';
import 'package:quickfix/features/home/presentation/pages/category_screen.dart';
import 'package:quickfix/features/home/presentation/pages/all_services_screen.dart';
import 'package:quickfix/features/booking/presentation/pages/service_details_screen.dart';
import 'package:quickfix/features/booking/presentation/pages/booking_checkout_screen.dart';
import 'package:quickfix/features/booking/presentation/pages/booking_confirmation_screen.dart';
import 'package:quickfix/features/booking/presentation/pages/quick_booking_screen.dart';
import 'package:quickfix/features/tracking/presentation/pages/live_tracking_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/profile_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/settings_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/refer_earn_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/addresses_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/order_history_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/privacy_policy_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/terms_conditions_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/support_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/wishlist_screen.dart';
import 'package:quickfix/features/profile/presentation/pages/offers_screen.dart';
import 'package:quickfix/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:quickfix/features/home/presentation/pages/location_selector_screen.dart';

import 'package:quickfix/features/home/presentation/pages/shop_details_screen.dart';
import 'package:quickfix/features/home/models/home_models.dart';

import 'package:quickfix/core/logging/navigation_observer.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  observers: [AppNavigationObserver()],
  routes: [
    // Onboarding & Authentication Flow
    GoRoute(
      path: '/',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/location',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LocationPermissionScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/location-selector',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LocationSelectorScreen(),
    ),

    // Shell Route for bottom navigation screens
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrderHistoryScreen(),
        ),
        GoRoute(
          path: '/wishlist',
          builder: (context, state) => const WishlistScreen(),
        ),
        GoRoute(
          path: '/offers',
          builder: (context, state) => const OffersScreen(),
        ),
      ],
    ),

    // Full screen routes (outside ShellRoute)
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final startVoice = state.uri.queryParameters['voice'] == 'true' ||
            (state.extra as Map<String, dynamic>?)?['startVoice'] == true;
        return SearchScreen(startVoice: startVoice);
      },
    ),
    GoRoute(
      path: '/shops',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ShopsListScreen(),
    ),
    GoRoute(
      path: '/category/all',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AllServicesScreen(),
    ),
    GoRoute(
      path: '/category/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final subcat = state.uri.queryParameters['subcat'];
        return CategoryScreen(categoryId: id, initialSubcategoryId: subcat);
      },
    ),
    GoRoute(
      path: '/shop/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final initialShop = state.extra as Shop?;
        return ShopDetailsScreen(shopId: id, initialShop: initialShop);
      },
    ),
    GoRoute(
      path: '/service/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ServiceDetailsScreen(serviceId: id);
      },
    ),
    GoRoute(
      path: '/booking-quick',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const QuickBookingScreen(),
    ),
    GoRoute(
      path: '/checkout',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BookingCheckoutScreen(),
    ),
    GoRoute(
      path: '/confirmation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extraData = state.extra as Map<String, dynamic>?;
        return BookingConfirmationScreen(extraData: extraData);
      },
    ),
    GoRoute(
      path: '/tracking/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return LiveTrackingScreen(bookingId: id);
      },
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TermsConditionsScreen(),
    ),
    GoRoute(
      path: '/support',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SupportScreen(),
    ),
    GoRoute(
      path: '/profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/refer-earn',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReferEarnScreen(),
    ),
    GoRoute(
      path: '/addresses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddressesScreen(),
    ),
  ],
);
