import 'package:quickfix/features/home/models/home_models.dart';

abstract class HomeRepository {
  Future<List<ServiceCategory>> getCategories();
  Future<List<Shop>> getNearbyShops({String? filter, double? lat, double? lng});
  Future<List<Professional>> getTopProfessionals({double? lat, double? lng});

  Future<List<Review>> getCustomerReviews();
  Future<List<Shop>> searchShops({
    required String query,
    double? lat,
    double? lng,
  });
  Future<List<PromoBanner>> getBanners();
  Future<List<Promotion>> getPromotions();
  Future<List<SpecialCard>> getSpecialCards();
  Future<List<CmsSection>> getHomepageLayout();
  Future<List<CustomSection>> getCustomSections();
  Future<Map<String, dynamic>> getAppSettings();
  Future<List<Subcategory>> getSubcategories(String categoryId);
  Future<List<Subcategory>> getAllSubcategories();
  Future<List<CatalogService>> getCatalogServices({String? categoryId, String? subcategoryId});
  Future<List<CatalogService>> searchCatalogServices(String query);
}

