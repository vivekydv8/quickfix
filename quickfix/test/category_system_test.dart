import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';
import 'package:quickfix/features/home/models/home_models.dart';

void main() {
  group('Main Categories Architecture Tests', () {
    test('kMainCategories contains exactly 11 distinct categories', () {
      expect(kMainCategories.length, 11);

      final ids = kMainCategories.map((c) => c.id).toSet();
      expect(ids.length, 11, reason: 'All category IDs must be unique');

      const expectedIds = [
        'electrician',
        'plumbing',
        'carpenter',
        'ac_repair',
        'refrigerator_repair',
        'washing_machine_repair',
        'ro_water_purifier',
        'mobile_repair',
        'laptop_repair',
        'tv_repair',
        'other_services',
      ];

      for (final id in expectedIds) {
        expect(ids.contains(id), isTrue, reason: 'Missing category ID: $id');
      }
    });

    test('getMainCategoryById retrieves correct category', () {
      final electrician = getMainCategoryById('electrician');
      expect(electrician.displayName, 'Electrician');
      expect(electrician.badge, isNotEmpty);

      final fallback = getMainCategoryById('non_existent_category');
      expect(fallback.id, 'non_existent_category');
      expect(fallback.displayName, 'NON EXISTENT CATEGORY');
    });

    test('All main categories have valid metadata and badge info', () {
      for (final cat in kMainCategories) {
        expect(cat.id, isNotEmpty);
        expect(cat.displayName, isNotEmpty);
        expect(cat.subtitle, isNotEmpty);
        expect(cat.icon, isNotNull);
      }
    });
  });

  group('Subcategory Model Tests', () {
    test('Subcategory fromJson and toJson serialization', () {
      final json = {
        'id': 'sub_switchboard_01',
        'name': 'Switchboard & Sockets',
        'imageUrl': 'https://example.com/switchboard.png',
        'categoryId': 'electrician',
        'description': 'Repair, replacement and installation of switches and sockets',
        'displayOrder': 1,
        'isActive': true,
      };

      final subcategory = Subcategory.fromJson(json);
      expect(subcategory.id, 'sub_switchboard_01');
      expect(subcategory.name, 'Switchboard & Sockets');
      expect(subcategory.categoryId, 'electrician');
      expect(subcategory.displayOrder, 1);
      expect(subcategory.isActive, isTrue);

      final serialized = subcategory.toJson();
      expect(serialized['name'], 'Switchboard & Sockets');
      expect(serialized['categoryId'], 'electrician');
    });
  });

  group('CatalogService Model Tests', () {
    test('CatalogService parses Fixed pricing correctly', () {
      final json = {
        'id': 'srv_switch_01',
        'title': 'Switch & Socket Installation',
        'description': 'Fitting and wiring of modular switches and sockets',
        'categoryId': 'electrician',
        'subcategoryId': 'sub_switchboard_01',
        'price': 99.0,
        'pricingType': 'fixed',
        'visitingCharges': 49.0,
        'isFreeInspection': false,
        'bulletPoints': ['Wiring inspection', 'Socket fitting', 'Safety check'],
        'durationText': '30 mins',
        'rating': 4.8,
        'reviewsCount': 124,
        'isActive': true,
      };

      final service = CatalogService.fromJson(json);
      expect(service.id, 'srv_switch_01');
      expect(service.pricingType, 'fixed');
      expect(service.formattedPrice, '₹99');
      expect(service.bulletPoints.length, 3);
      expect(service.durationText, '30 mins');
    });

    test('CatalogService parses Starting At pricing correctly', () {
      final json = {
        'id': 'srv_fan_01',
        'title': 'Ceiling Fan Repair',
        'description': 'Bearing noise, speed issue or capacitor replacement',
        'categoryId': 'electrician',
        'subcategoryId': 'sub_fans_01',
        'price': 149.0,
        'pricingType': 'starting',
        'minPrice': 149.0,
        'maxPrice': 399.0,
        'visitingCharges': 49.0,
        'bulletPoints': ['Capacitor check', 'Winding check'],
      };

      final service = CatalogService.fromJson(json);
      expect(service.pricingType, 'starting');
      expect(service.formattedPrice, 'Starts at ₹149');
    });

    test('CatalogService parses Inspection / Quotation pricing correctly', () {
      final json = {
        'id': 'srv_wiring_01',
        'title': 'Complete House Wiring Inspection',
        'description': 'Full premises short circuit and load inspection',
        'categoryId': 'electrician',
        'subcategoryId': 'sub_wiring_01',
        'price': 199.0,
        'pricingType': 'inspection',
        'visitingCharges': 199.0,
        'isFreeInspection': false,
      };

      final service = CatalogService.fromJson(json);
      expect(service.pricingType, 'inspection');
      expect(service.formattedPrice, '₹199 Visiting Fee');
    });

    test('CatalogService converts seamlessly to ShopService for Cart compatibility', () {
      const catalogService = CatalogService(
        id: 'srv_pipe_01',
        title: 'Tap Leakage Repair',
        description: 'Fix dripping or damaged water taps and washers',
        categoryId: 'plumbing',
        subcategoryId: 'sub_plumbing_taps',
        price: 129.0,
        pricingType: 'fixed',
        visitingCharges: 49.0,
        isFreeInspection: false,
        durationText: '25 mins',
        rating: 4.9,
        reviewsCount: 88,
        bulletPoints: ['Washer replacement', 'Threading check'],
        isActive: true,
      );

      final shopService = catalogService.toShopService();
      expect(shopService.id, 'srv_pipe_01');
      expect(shopService.title, 'Tap Leakage Repair');
      expect(shopService.price, 129.0);
      expect(shopService.bulletPoints, contains('Washer replacement'));
      expect(shopService.durationText, '25 mins');
      expect(shopService.visitingCharges, 49.0);
    });
  });
}
