import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String? iconUrl;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.iconUrl,
  });
}

class ShopService {
  final String id;
  final String title;
  final double price;
  final double originalPrice;
  final double rating;
  final int reviewsCount;
  final String durationText;
  final List<String> bulletPoints;
  final String imageUrl;
  final String pricingType;
  final double minPrice;
  final double maxPrice;
  final double visitingCharges;
  final bool isFreeInspection;
  final double gst;
  final double extraCharges;
  final String extraChargesLabel;
  final bool isEnabled;
  final bool isAvailable;

  const ShopService({
    required this.id,
    required this.title,
    required this.price,
    required this.originalPrice,
    required this.rating,
    required this.reviewsCount,
    required this.durationText,
    required this.bulletPoints,
    required this.imageUrl,
    this.pricingType = 'fixed',
    this.minPrice = 0,
    this.maxPrice = 0,
    this.visitingCharges = 0,
    this.isFreeInspection = false,
    this.gst = 0,
    this.extraCharges = 0,
    this.extraChargesLabel = '',
    this.isEnabled = true,
    this.isAvailable = true,
  });

  factory ShopService.fromJson(Map<String, dynamic> json) {
    return ShopService(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      originalPrice:
          double.tryParse(json['originalPrice']?.toString() ?? '0.0') ?? 0.0,
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
      reviewsCount: int.tryParse(json['reviewsCount']?.toString() ?? '0') ?? 0,
      durationText: json['durationText']?.toString() ?? '1 hr',
      bulletPoints:
          (json['bulletPoints'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      imageUrl: json['imageUrl']?.toString() ?? '',
      pricingType: json['pricingType']?.toString() ?? 'fixed',
      minPrice: double.tryParse(json['minPrice']?.toString() ?? '0.0') ?? 0.0,
      maxPrice: double.tryParse(json['maxPrice']?.toString() ?? '0.0') ?? 0.0,
      visitingCharges:
          double.tryParse(json['visitingCharges']?.toString() ?? '0.0') ?? 0.0,
      isFreeInspection: json['isFreeInspection'] == true,
      gst: double.tryParse(json['gst']?.toString() ?? '0.0') ?? 0.0,
      extraCharges:
          double.tryParse(json['extraCharges']?.toString() ?? '0.0') ?? 0.0,
      extraChargesLabel: json['extraChargesLabel']?.toString() ?? '',
      isEnabled: json['isEnabled'] != false,
      isAvailable: json['isAvailable'] != false,
    );
  }
}

class Shop {
  final String id;
  final String name;
  final List<String> categories;
  final double rating;
  final int reviewsCount;
  final double distanceKm;
  final int deliveryTimeMins;
  final String? estimatedServiceTime;
  final String priceRange;
  final String imagePath;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final double visitingCharges;
  final String timings;
  final bool isOpen;
  final List<String> portfolioImages;
  final List<ShopService> services;
  final List<String> technicians;
  final String offerBannerText;
  final String offerBannerCode;
  final String offerBannerSubtext;
  final List<String> customCategories;

  const Shop({
    required this.id,
    required this.name,
    required this.categories,
    required this.rating,
    required this.reviewsCount,
    required this.distanceKm,
    required this.deliveryTimeMins,
    this.estimatedServiceTime,
    required this.priceRange,
    required this.imagePath,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.visitingCharges,
    required this.timings,
    required this.isOpen,
    required this.portfolioImages,
    required this.services,
    required this.technicians,
    this.offerBannerText = 'Flat ₹100 OFF on First Booking',
    this.offerBannerCode = 'QUICK100',
    this.offerBannerSubtext = 'Use code QUICK100 at checkout • Free inspection included',
    this.customCategories = const [],
  });

  String get estimatedTimeDisplay =>
      (estimatedServiceTime != null && estimatedServiceTime!.isNotEmpty)
      ? estimatedServiceTime!
      : '$deliveryTimeMins mins';

  int get estimatedTimeMinutes {
    if (estimatedServiceTime == null || estimatedServiceTime!.isEmpty) {
      return deliveryTimeMins;
    }
    final text = estimatedServiceTime!.toLowerCase();
    if (text.contains('hour')) {
      final hourNum = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return hourNum * 60;
    }
    final minsNum = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    return minsNum ?? deliveryTimeMins;
  }

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      categories:
          (json['categories'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      rating: double.tryParse(json['rating']?.toString() ?? '4.0') ?? 4.0,
      reviewsCount: int.tryParse(json['reviewsCount']?.toString() ?? '0') ?? 0,
      distanceKm:
          double.tryParse(json['distanceKm']?.toString() ?? '1.0') ?? 1.0,
      deliveryTimeMins:
          int.tryParse(json['deliveryTimeMins']?.toString() ?? '15') ?? 15,
      estimatedServiceTime: json['estimatedServiceTime']?.toString(),
      priceRange: json['priceRange']?.toString() ?? '₹',
      imagePath: json['imagePath']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      visitingCharges:
          double.tryParse(json['visitingCharges']?.toString() ?? '150.0') ??
          150.0,
      timings: json['timings']?.toString() ?? '09:00 AM - 09:00 PM',
      isOpen: json['isOpen'] == null ? true : (json['isOpen'] as bool),
      portfolioImages:
          (json['portfolioImages'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      services:
          (json['services'] as List?)
              ?.map((e) => ShopService.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      technicians:
          (json['technicians'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      offerBannerText: json['offerBannerText']?.toString() ??
          'Flat ₹100 OFF on First Booking',
      offerBannerCode: json['offerBannerCode']?.toString() ?? 'QUICK100',
      offerBannerSubtext: json['offerBannerSubtext']?.toString() ??
          'Use code QUICK100 at checkout • Free inspection included',
      customCategories: (json['customCategories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class Professional {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviewsCount;
  final String avatarUrl;
  final String shopId;
  final String experience;
  final int completedJobs;
  final String location;
  final bool verifiedBadge;
  final bool availability;
  final String featuredStatus;
  final int priority;

  const Professional({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviewsCount,
    required this.avatarUrl,
    required this.shopId,
    required this.experience,
    required this.completedJobs,
    required this.location,
    required this.verifiedBadge,
    required this.availability,
    required this.featuredStatus,
    required this.priority,
  });

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      specialty: json['specialty']?.toString() ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
      reviewsCount: int.tryParse(json['reviewsCount']?.toString() ?? '0') ?? 0,
      avatarUrl:
          json['imageUrl']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      shopId: json['shopId']?.toString() ?? '',
      experience: json['experience']?.toString() ?? '',
      completedJobs:
          int.tryParse(json['completedJobs']?.toString() ?? '0') ?? 0,
      location: json['location']?.toString() ?? '',
      verifiedBadge: json['verifiedBadge'] == true,
      availability: json['availability'] != false,
      featuredStatus: json['featuredStatus']?.toString() ?? 'Featured',
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
    );
  }
}

class Review {
  final String id;
  final String userName;
  final String userAvatar;
  final double rating;
  final String comment;
  final String serviceName;
  final String locationName;
  final String providerName;
  final String date;
  final bool verifiedBadge;
  final int priority;
  final String status;
  final bool isActive;
  final bool isFeatured;

  const Review({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    required this.serviceName,
    required this.locationName,
    required this.providerName,
    required this.date,
    required this.verifiedBadge,
    required this.priority,
    required this.status,
    required this.isActive,
    required this.isFeatured,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userAvatar: json['userAvatar']?.toString() ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
      comment: json['comment']?.toString() ?? '',
      serviceName: json['serviceName']?.toString() ?? '',
      locationName: json['locationName']?.toString() ?? '',
      providerName: json['providerName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      verifiedBadge: json['verifiedBadge'] != false,
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'approved',
      isActive: json['isActive'] != false,
      isFeatured: json['isFeatured'] == true,
    );
  }
}

class UserLocation {
  final String address;
  final double latitude;
  final double longitude;

  const UserLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    address: json['address'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 26.4912,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 80.3156,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserLocation &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => address.hashCode ^ latitude.hashCode ^ longitude.hashCode;
}

class PromoBanner {
  final String id;
  final String title;
  final String code;
  final String percent;
  final String imageUrl;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.code,
    required this.percent,
    required this.imageUrl,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      percent: json['percent']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class Promotion {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String offerPercentage;
  final String couponCode;
  final String ctaButtonText;
  final String ctaButtonAction;
  final String ctaButtonActionValue;
  final String bannerImage;
  final String backgroundColor;
  final String textColor;
  final String buttonColor;
  final String buttonTextColor;
  final int priority;
  final String startDate;
  final String endDate;
  final bool isActive;

  const Promotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.offerPercentage,
    required this.couponCode,
    required this.ctaButtonText,
    required this.ctaButtonAction,
    required this.ctaButtonActionValue,
    required this.bannerImage,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.priority,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      offerPercentage: json['offerPercentage']?.toString() ?? '',
      couponCode: json['couponCode']?.toString() ?? '',
      ctaButtonText: json['ctaButtonText']?.toString() ?? 'Grab Now',
      ctaButtonAction: json['ctaButtonAction']?.toString() ?? 'No Action',
      ctaButtonActionValue: json['ctaButtonActionValue']?.toString() ?? '',
      bannerImage: json['bannerImage']?.toString() ?? '',
      backgroundColor: json['backgroundColor']?.toString() ?? '#FFF1F0',
      textColor: json['textColor']?.toString() ?? '#000000',
      buttonColor: json['buttonColor']?.toString() ?? '#FF4D4F',
      buttonTextColor: json['buttonTextColor']?.toString() ?? '#FFFFFF',
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}

class SpecialCard {
  final String id;
  final String icon;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String description;
  final String backgroundColor;
  final String buttonText;
  final String ctaAction;
  final String ctaActionValue;
  final int priority;
  final bool isActive;
  final String startDate;
  final String endDate;

  const SpecialCard({
    required this.id,
    required this.icon,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.backgroundColor,
    required this.buttonText,
    required this.ctaAction,
    required this.ctaActionValue,
    required this.priority,
    required this.isActive,
    required this.startDate,
    required this.endDate,
  });

  factory SpecialCard.fromJson(Map<String, dynamic> json) {
    return SpecialCard(
      id: json['id']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'star',
      imageUrl: json['imageUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      backgroundColor: json['backgroundColor']?.toString() ?? '#FFFFFF',
      buttonText: json['buttonText']?.toString() ?? 'View',
      ctaAction: json['ctaAction']?.toString() ?? 'No Action',
      ctaActionValue: json['ctaActionValue']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] != false,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
    );
  }
}

class CmsSection {
  final String id;
  final String title;
  final String type;
  final int priority;
  final bool isActive;
  final Map<String, dynamic> settings;

  const CmsSection({
    required this.id,
    required this.title,
    required this.type,
    required this.priority,
    required this.isActive,
    required this.settings,
  });

  factory CmsSection.fromJson(Map<String, dynamic> json) {
    return CmsSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] != false,
      settings: json['settings'] is Map
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
    );
  }
}

class CustomSectionServiceItem {
  final String id;
  final String title;
  final String imageUrl;
  final double rating;
  final String reviewsCount;
  final String startingPrice;
  final String actionType;
  final String actionValue;

  const CustomSectionServiceItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.startingPrice,
    required this.actionType,
    required this.actionValue,
  });

  factory CustomSectionServiceItem.fromJson(Map<String, dynamic> json) {
    return CustomSectionServiceItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '4.5') ?? 4.5,
      reviewsCount: json['reviewsCount']?.toString() ?? '',
      startingPrice: json['startingPrice']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? 'Open Shop',
      actionValue: json['actionValue']?.toString() ?? '',
    );
  }
}

class CustomSection {
  final String id;
  final String title;
  final String subtitle;
  final String bannerImageUrl;
  final String bannerBadgeText;
  final String bannerButtonText;
  final String bannerActionType;
  final String bannerActionValue;
  final String seeAllActionType;
  final String seeAllActionValue;
  final List<CustomSectionServiceItem> serviceItems;
  final int priority;
  final bool isActive;

  const CustomSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bannerImageUrl,
    required this.bannerBadgeText,
    this.bannerButtonText = 'Explore now',
    required this.bannerActionType,
    required this.bannerActionValue,
    required this.seeAllActionType,
    required this.seeAllActionValue,
    required this.serviceItems,
    required this.priority,
    required this.isActive,
  });

  factory CustomSection.fromJson(Map<String, dynamic> json) {
    return CustomSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      bannerImageUrl: json['bannerImageUrl']?.toString() ?? '',
      bannerBadgeText: json['bannerBadgeText']?.toString() ?? '',
      bannerButtonText: json['bannerButtonText'] != null
          ? json['bannerButtonText'].toString()
          : 'Explore now',
      bannerActionType: json['bannerActionType']?.toString() ?? 'No Action',
      bannerActionValue: json['bannerActionValue']?.toString() ?? '',
      seeAllActionType: json['seeAllActionType']?.toString() ?? 'No Action',
      seeAllActionValue: json['seeAllActionValue']?.toString() ?? '',
      serviceItems:
          (json['serviceItems'] as List?)
              ?.map(
                (e) => CustomSectionServiceItem.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] != false,
    );
  }
}

class Subcategory {
  final String id;
  final String categoryId;
  final String name;
  final String description;
  final String imageUrl;
  final int displayOrder;
  final bool isActive;

  const Subcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      displayOrder: int.tryParse(json['displayOrder']?.toString() ?? '0') ?? 0,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'displayOrder': displayOrder,
    'isActive': isActive,
  };
}

class CatalogService {
  final String id;
  final String categoryId;
  final String subcategoryId;
  final String title;
  final String description;
  final String imageUrl;
  final double price;
  final double originalPrice;
  final String pricingType; // 'fixed', 'starting', 'inspection', 'range'
  final double minPrice;
  final double maxPrice;
  final double visitingCharges;
  final bool isFreeInspection;
  final String durationText;
  final List<String> bulletPoints;
  final double rating;
  final int reviewsCount;
  final bool isActive;

  const CatalogService({
    required this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    required this.price,
    this.originalPrice = 0.0,
    this.pricingType = 'fixed',
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
    this.visitingCharges = 0.0,
    this.isFreeInspection = false,
    this.durationText = '30-45 mins',
    this.bulletPoints = const [],
    this.rating = 4.8,
    this.reviewsCount = 42,
    this.isActive = true,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) {
    return CatalogService(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      subcategoryId: json['subcategoryId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      originalPrice:
          double.tryParse(json['originalPrice']?.toString() ?? '0.0') ?? 0.0,
      pricingType: json['pricingType']?.toString() ?? 'fixed',
      minPrice: double.tryParse(json['minPrice']?.toString() ?? '0.0') ?? 0.0,
      maxPrice: double.tryParse(json['maxPrice']?.toString() ?? '0.0') ?? 0.0,
      visitingCharges:
          double.tryParse(json['visitingCharges']?.toString() ?? '0.0') ?? 0.0,
      isFreeInspection: json['isFreeInspection'] == true,
      durationText: json['durationText']?.toString() ?? '30-45 mins',
      bulletPoints: (json['bulletPoints'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rating: double.tryParse(json['rating']?.toString() ?? '4.8') ?? 4.8,
      reviewsCount:
          int.tryParse(json['reviewsCount']?.toString() ?? '42') ?? 42,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'subcategoryId': subcategoryId,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'price': price,
    'originalPrice': originalPrice,
    'pricingType': pricingType,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'visitingCharges': visitingCharges,
    'isFreeInspection': isFreeInspection,
    'durationText': durationText,
    'bulletPoints': bulletPoints,
    'rating': rating,
    'reviewsCount': reviewsCount,
    'isActive': isActive,
  };

  /// Returns user-friendly pricing label (e.g. "₹199", "Starts at ₹199", "Quote on Inspection")
  String get formattedPrice {
    if (pricingType == 'inspection') {
      return isFreeInspection ? 'Free Inspection' : '₹${visitingCharges.toStringAsFixed(0)} Visiting Fee';
    } else if (pricingType == 'starting') {
      return 'Starts at ₹${price.toStringAsFixed(0)}';
    } else if (pricingType == 'range' && minPrice > 0 && maxPrice > 0) {
      return '₹${minPrice.toStringAsFixed(0)} - ₹${maxPrice.toStringAsFixed(0)}';
    } else {
      return '₹${price.toStringAsFixed(0)}';
    }
  }

  /// Convert to ShopService for existing booking flow compatibility
  ShopService toShopService() {
    return ShopService(
      id: id,
      title: title,
      price: price,
      originalPrice: originalPrice,
      rating: rating,
      reviewsCount: reviewsCount,
      durationText: durationText,
      bulletPoints: bulletPoints,
      imageUrl: imageUrl,
      pricingType: pricingType,
      minPrice: minPrice,
      maxPrice: maxPrice,
      visitingCharges: visitingCharges,
      isFreeInspection: isFreeInspection,
      isEnabled: isActive,
      isAvailable: true,
    );
  }
}

