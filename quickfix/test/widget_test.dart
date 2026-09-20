import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:quickfix/app.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';

class FakeLocationNotifier extends LocationNotifier {
  @override
  Future<void> fetchCurrentLocationAutomatically() async {
    // Prevent Geolocator and reverse-geocoding timers/requests during test execution
  }

  @override
  Future<bool> fetchGPSLocation({bool requestPermission = true}) async {
    return true;
  }
}

void main() {
  setUpAll(() async {
    // Initialize Hive in a temporary directory for the test suite
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);

    // Open the boxes that HiveService expects to be open
    await Hive.openBox('app_settings');
    await Hive.openBox('app_cache');
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAddressProvider.overrideWith((ref) => FakeLocationNotifier()),
          categoriesProvider.overrideWith((ref) => Future.value([])),
          bannersProvider.overrideWith((ref) => Future.value([])),
          homepageLayoutProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const QuickFixApp(),
      ),
    );

    // 1. Advance virtual clock to let the splash screen navigation timer (2.5s) fire
    await tester.pump(const Duration(seconds: 3));

    // 2. Let all post-navigation transition animations (like flutter_animate) settle
    await tester.pumpAndSettle();
  });
}
