import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/repositories/home_repository.dart';
import 'package:quickfix/features/home/datasources/home_remote_data_source.dart';

/// Implementation of [HomeRepository] managing location-based shop queries, categories, search, and promotions.
/// 
/// Interacts with [HomeRemoteDataSource] to query the remote REST server,
/// returning structured models like [ServiceCategory], [Shop], and [PromoBanner].
class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<ServiceCategory>> getCategories() async {
    return await _remoteDataSource.getCategories();
  }

  @override
  Future<List<Shop>> getNearbyShops({
    String? filter,
    double? lat,
    double? lng,
  }) async {
    return await _remoteDataSource.getNearbyShops(
      filter: filter,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<List<Professional>> getTopProfessionals({
    double? lat,
    double? lng,
  }) async {
    return await _remoteDataSource.getTopProfessionals(lat: lat, lng: lng);
  }


  @override
  Future<List<Review>> getCustomerReviews() async {
    return await _remoteDataSource.getCustomerReviews();
  }

  @override
  Future<List<Shop>> searchShops({
    required String query,
    double? lat,
    double? lng,
    String? category,
    String? subcategory,
  }) async {
    return await _remoteDataSource.searchShops(
      query: query,
      lat: lat,
      lng: lng,
      category: category,
      subcategory: subcategory,
    );
  }

  @override
  Future<List<PromoBanner>> getBanners() async {
    return await _remoteDataSource.getBanners();
  }

  @override
  Future<List<Promotion>> getPromotions() async {
    return await _remoteDataSource.getPromotions();
  }

  @override
  Future<List<SpecialCard>> getSpecialCards() async {
    return await _remoteDataSource.getSpecialCards();
  }

  @override
  Future<List<CmsSection>> getHomepageLayout() async {
    return await _remoteDataSource.getHomepageLayout();
  }

  @override
  Future<List<CustomSection>> getCustomSections() async {
    return await _remoteDataSource.getCustomSections();
  }

  @override
  Future<Map<String, dynamic>> getAppSettings() async {
    return await _remoteDataSource.getAppSettings();
  }

  @override
  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    return await _remoteDataSource.getSubcategories(categoryId);
  }

  @override
  Future<List<Subcategory>> getAllSubcategories() async {
    return await _remoteDataSource.getAllSubcategories();
  }

  @override
  Future<List<CatalogService>> getCatalogServices({String? categoryId, String? subcategoryId}) async {
    return await _remoteDataSource.getCatalogServices(
      categoryId: categoryId,
      subcategoryId: subcategoryId,
    );
  }

  @override
  Future<List<CatalogService>> searchCatalogServices(String query) async {
    return await _remoteDataSource.searchCatalogServices(query);
  }
}

