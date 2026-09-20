import 'package:flutter/material.dart';
import 'package:quickfix/core/network/dio_client.dart';
import 'package:quickfix/core/network/api_endpoints.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/features/home/models/home_models.dart';
import 'package:quickfix/features/home/config/main_categories_config.dart';

class HomeRemoteDataSource {
  final DioClient _client;

  HomeRemoteDataSource(this._client);

  Future<List<ServiceCategory>> getCategories() async {
    try {
      final response = await _client.get(ApiEndpoints.categories);
      final data = response.data as List;
      await HiveService.saveDataCache('home_categories', data);
      return _parseCategoriesList(data);
    } catch (e) {
      final cached = HiveService.getDataCache('home_categories');
      if (cached != null && cached is List) {
        return _parseCategoriesList(cached);
      }
      rethrow;
    }
  }

  List<ServiceCategory> _parseCategoriesList(List data) {
    return data.map((json) {
      final id = json['id']?.toString() ?? '';
      return ServiceCategory(
        id: id,
        name: json['name']?.toString() ?? '',
        icon: _parseIcon(id),
        backgroundColor: _parseColor(id, isBg: true),
        iconColor: _parseColor(id, isBg: false),
        iconUrl: json['iconUrl']?.toString() ?? json['imageUrl']?.toString(),
      );
    }).toList();
  }

  Future<List<Shop>> getNearbyShops({
    String? filter,
    double? lat,
    double? lng,
  }) async {
    final Map<String, dynamic> query = {};
    if (filter != null && filter != 'All') {
      query['filter'] = filter;
    }
    if (lat != null && lng != null) {
      query['lat'] = lat;
      query['lng'] = lng;
    }

    final cacheKey = 'nearby_shops_${filter ?? 'All'}';

    try {
      final response = await _client.get(
        ApiEndpoints.shops,
        queryParameters: query,
      );
      final data = response.data as List;
      await HiveService.saveDataCache(cacheKey, data);
      await HiveService.saveDataCache('nearby_shops_default', data);
      return data.map((json) => Shop.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache(cacheKey) ?? HiveService.getDataCache('nearby_shops_default');
      if (cached != null && cached is List) {
        return cached.map((json) => Shop.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<Shop>> searchShops({
    required String query,
    double? lat,
    double? lng,
    String? category,
    String? subcategory,
  }) async {
    final Map<String, dynamic> queryParams = {'q': query};
    if (lat != null && lng != null) {
      queryParams['lat'] = lat;
      queryParams['lng'] = lng;
    }
    if (category != null && category.trim().isNotEmpty) {
      queryParams['category'] = category.trim();
    }
    if (subcategory != null && subcategory.trim().isNotEmpty) {
      queryParams['subcategory'] = subcategory.trim();
    }

    final cacheKey = 'search_shops_${query}_${category ?? ''}_${subcategory ?? ''}';

    try {
      final response = await _client.get(
        '/shops/search',
        queryParameters: queryParams,
      );
      final raw = response.data;
      final List data = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : []);
      await HiveService.saveDataCache(cacheKey, data);
      return data.map((json) => Shop.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache(cacheKey) ?? HiveService.getDataCache('search_shops_$query');
      if (cached != null && cached is List) {
        return cached.map((json) => Shop.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<PromoBanner>> getBanners() async {
    try {
      final response = await _client.get(ApiEndpoints.banners);
      final data = response.data as List;
      await HiveService.saveDataCache('home_banners', data);
      return data.map((json) => PromoBanner.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('home_banners');
      if (cached != null && cached is List) {
        return cached.map((json) => PromoBanner.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<Professional>> getTopProfessionals({
    double? lat,
    double? lng,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (lat != null && lat != 0.0) queryParams['lat'] = lat;
    if (lng != null && lng != 0.0) queryParams['lng'] = lng;

    try {
      final response = await _client.get(
        ApiEndpoints.professionals,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response.data as List;
      await HiveService.saveDataCache('top_professionals', data);
      return data.map((json) => Professional.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('top_professionals');
      if (cached != null && cached is List) {
        return cached.map((json) => Professional.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<Review>> getCustomerReviews() async {
    try {
      final response = await _client.get(ApiEndpoints.reviews);
      final data = response.data as List;
      await HiveService.saveDataCache('customer_reviews', data);
      return data.map((json) => Review.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('customer_reviews');
      if (cached != null && cached is List) {
        return cached.map((json) => Review.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<Promotion>> getPromotions() async {
    try {
      final response = await _client.get(ApiEndpoints.promotions);
      final data = response.data as List;
      await HiveService.saveDataCache('home_promotions', data);
      return data.map((json) => Promotion.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('home_promotions');
      if (cached != null && cached is List) {
        return cached.map((json) => Promotion.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<SpecialCard>> getSpecialCards() async {
    try {
      final response = await _client.get(ApiEndpoints.specialCards);
      final data = response.data as List;
      await HiveService.saveDataCache('special_cards', data);
      return data.map((json) => SpecialCard.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('special_cards');
      if (cached != null && cached is List) {
        return cached.map((json) => SpecialCard.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<CmsSection>> getHomepageLayout() async {
    try {
      final response = await _client.get(ApiEndpoints.homepageLayout);
      final data = response.data as List;
      await HiveService.saveDataCache('homepage_layout', data);
      return data.map((json) => CmsSection.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('homepage_layout');
      if (cached != null && cached is List) {
        return cached.map((json) => CmsSection.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<CustomSection>> getCustomSections() async {
    try {
      final response = await _client.get(ApiEndpoints.customSections);
      final data = response.data as List;
      await HiveService.saveDataCache('custom_sections', data);
      return data.map((json) => CustomSection.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('custom_sections');
      if (cached != null && cached is List) {
        return cached.map((json) => CustomSection.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final response = await _client.get(ApiEndpoints.settings);
      final data = response.data as Map<String, dynamic>;
      await HiveService.saveDataCache('app_settings_data', data);
      return data;
    } catch (e) {
      final cached = HiveService.getDataCache('app_settings_data');
      if (cached != null && cached is Map) {
        return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    final cacheKey = 'subcategories_$categoryId';
    try {
      final response = await _client.get(ApiEndpoints.categorySubcategories(categoryId));
      final data = response.data as List;
      if (data.isNotEmpty) {
        await HiveService.saveDataCache(cacheKey, data);
        return data.map((json) => Subcategory.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    final cached = HiveService.getDataCache(cacheKey);
    if (cached != null && cached is List && cached.isNotEmpty) {
      return cached.map((json) => Subcategory.fromJson(json as Map<String, dynamic>)).toList();
    }

    final cat = getMainCategoryById(categoryId);
    return cat.sampleSubcategories
        .asMap()
        .entries
        .map((e) => Subcategory(
              id: '${cat.id}_${e.key + 1}',
              categoryId: cat.id,
              name: e.value,
              description: 'Expert verified services for ${e.value.toLowerCase()}',
              displayOrder: e.key + 1,
              isActive: true,
            ))
        .toList();
  }

  Future<List<Subcategory>> getAllSubcategories() async {
    const cacheKey = 'all_subcategories';
    try {
      final response = await _client.get(ApiEndpoints.subcategories);
      final data = response.data as List;
      if (data.isNotEmpty) {
        await HiveService.saveDataCache(cacheKey, data);
        return data.map((json) => Subcategory.fromJson(json as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    final cached = HiveService.getDataCache(cacheKey);
    if (cached != null && cached is List && cached.isNotEmpty) {
      return cached.map((json) => Subcategory.fromJson(json as Map<String, dynamic>)).toList();
    }

    final List<Subcategory> allDefaults = [];
    for (final cat in kMainCategories) {
      for (int i = 0; i < cat.sampleSubcategories.length; i++) {
        allDefaults.add(Subcategory(
          id: '${cat.id}_${i + 1}',
          categoryId: cat.id,
          name: cat.sampleSubcategories[i],
          description: 'Expert verified services for ${cat.sampleSubcategories[i].toLowerCase()}',
          displayOrder: i + 1,
          isActive: true,
        ));
      }
    }
    return allDefaults;
  }

  Future<List<CatalogService>> getCatalogServices({String? categoryId, String? subcategoryId}) async {
    String endpoint;
    String cacheKey;
    if (subcategoryId != null && subcategoryId.isNotEmpty) {
      endpoint = ApiEndpoints.subcategoryCatalogServices(subcategoryId);
      cacheKey = 'catalog_services_subcat_$subcategoryId';
    } else if (categoryId != null && categoryId.isNotEmpty) {
      endpoint = ApiEndpoints.categoryCatalogServices(categoryId);
      cacheKey = 'catalog_services_cat_$categoryId';
    } else {
      endpoint = ApiEndpoints.catalogServices;
      cacheKey = 'catalog_services_all';
    }

    try {
      final response = await _client.get(endpoint);
      final data = response.data as List;
      await HiveService.saveDataCache(cacheKey, data);
      return data.map((json) => CatalogService.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache(cacheKey);
      if (cached != null && cached is List) {
        return cached.map((json) => CatalogService.fromJson(json as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<CatalogService>> searchCatalogServices(String query) async {
    try {
      final response = await _client.get(
        ApiEndpoints.searchCatalogServices,
        queryParameters: {'q': query},
      );
      final data = response.data as List;
      return data.map((json) => CatalogService.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }


  // Helper icons and color utilities
  IconData _parseIcon(String id) {
    switch (id) {
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'plumbing':
        return Icons.plumbing_outlined;
      case 'electrician':
        return Icons.bolt_outlined;
      case 'appliances':
        return Icons.local_laundry_service_outlined;
      case 'carpentry':
        return Icons.carpenter_outlined;
      default:
        return Icons.grid_view_outlined;
    }
  }

  Color _parseColor(String id, {required bool isBg}) {
    // Dynamic color matching
    if (isBg) {
      switch (id) {
        case 'cleaning':
          return const Color(0xFFEEF2FF);
        case 'plumbing':
          return const Color(0xFFECFDF5);
        case 'electrician':
          return const Color(0xFFFFFBEB);
        case 'appliances':
          return const Color(0xFFF5F3FF);
        case 'carpentry':
          return const Color(0xFFFFF7ED);
        default:
          return const Color(0xFFF1F5F9);
      }
    } else {
      switch (id) {
        case 'cleaning':
          return const Color(0xFF4F46E5);
        case 'plumbing':
          return const Color(0xFF059669);
        case 'electrician':
          return const Color(0xFFD97706);
        case 'appliances':
          return const Color(0xFF7C3AED);
        case 'carpentry':
          return const Color(0xFFEA580C);
        default:
          return const Color(0xFF475569);
      }
    }
  }
}
