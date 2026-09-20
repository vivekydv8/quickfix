import 'package:flutter/material.dart';

/// Representation of a top-level service category within the QuickFix customer app.
class MainCategory {
  final String id;
  final String displayName;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final String? badge;

  const MainCategory({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    this.badge,
  });
}

/// The 11 authoritative top-level service categories for QuickFix.
const List<MainCategory> kMainCategories = [
  MainCategory(
    id: 'electrician',
    displayName: 'Electrician',
    subtitle: 'Switch, fan, wiring & fuse repair',
    icon: Icons.bolt_rounded,
    accentColor: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFFFBEB),
    badge: 'Popular',
  ),
  MainCategory(
    id: 'plumbing',
    displayName: 'Plumbing',
    subtitle: 'Tap, pipe, leakage & tank repair',
    icon: Icons.plumbing_rounded,
    accentColor: Color(0xFF0284C7),
    backgroundColor: Color(0xFFF0F9FF),
  ),
  MainCategory(
    id: 'carpenter',
    displayName: 'Carpenter',
    subtitle: 'Furniture repair, locks & assembly',
    icon: Icons.carpenter_rounded,
    accentColor: Color(0xFFD97706),
    backgroundColor: Color(0xFFFFFDF5),
  ),
  MainCategory(
    id: 'ac_repair',
    displayName: 'AC Service & Repair',
    subtitle: 'Gas refill, deep servicing & repair',
    icon: Icons.ac_unit_rounded,
    accentColor: Color(0xFF06B6D4),
    backgroundColor: Color(0xFFECFEFF),
    badge: 'Warranty',
  ),
  MainCategory(
    id: 'refrigerator_repair',
    displayName: 'Refrigerator',
    subtitle: 'Cooling issues, compressor & gas',
    icon: Icons.kitchen_rounded,
    accentColor: Color(0xFF3B82F6),
    backgroundColor: Color(0xFFEFF6FF),
  ),
  MainCategory(
    id: 'washing_machine_repair',
    displayName: 'Washing Machine',
    subtitle: 'Spin, motor, drum & drain issues',
    icon: Icons.local_laundry_service_rounded,
    accentColor: Color(0xFF8B5CF6),
    backgroundColor: Color(0xFFF5F3FF),
  ),
  MainCategory(
    id: 'ro_water_purifier',
    displayName: 'RO & Purifier',
    subtitle: 'Filter change, service & repair',
    icon: Icons.water_drop_rounded,
    accentColor: Color(0xFF14B8A6),
    backgroundColor: Color(0xFFF0FDFA),
    badge: 'Essential',
  ),
  MainCategory(
    id: 'mobile_repair',
    displayName: 'Mobile Repair',
    subtitle: 'Screen, battery, mic & charging port',
    icon: Icons.phone_android_rounded,
    accentColor: Color(0xFFEC4899),
    backgroundColor: Color(0xFFFDF2F8),
    badge: 'Express',
  ),
  MainCategory(
    id: 'laptop_repair',
    displayName: 'Laptop & PC',
    subtitle: 'OS install, SSD, motherboard & display',
    icon: Icons.laptop_mac_rounded,
    accentColor: Color(0xFF6366F1),
    backgroundColor: Color(0xFFEEF2FF),
  ),
  MainCategory(
    id: 'tv_repair',
    displayName: 'TV Repair',
    subtitle: 'LED/LCD display, sound & power repair',
    icon: Icons.tv_rounded,
    accentColor: Color(0xFFE11D48),
    backgroundColor: Color(0xFFFFF1F2),
  ),
  MainCategory(
    id: 'other_services',
    displayName: 'Other Services',
    subtitle: 'Chimney, microwave, geyser & more',
    icon: Icons.miscellaneous_services_rounded,
    accentColor: Color(0xFF64748B),
    backgroundColor: Color(0xFFF8FAFC),
  ),
];

/// Helper to lookup a [MainCategory] by its identifier.
MainCategory getMainCategoryById(String id) {
  final normalized = id.toLowerCase().trim();
  return kMainCategories.firstWhere(
    (c) => c.id.toLowerCase() == normalized,
    orElse: () => MainCategory(
      id: id,
      displayName: id.replaceAll('_', ' ').toUpperCase(),
      subtitle: 'Home repair & servicing',
      icon: Icons.home_repair_service_rounded,
      accentColor: const Color(0xFF6E42E5),
      backgroundColor: const Color(0xFFF5F3FF),
    ),
  );
}
