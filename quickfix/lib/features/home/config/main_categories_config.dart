import 'package:flutter/material.dart';

/// Representation of a top-level service category within the QuickFix customer app.
class MainCategory {
  final String id;
  final String displayName;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final Color glowColor;
  final String? badge;
  final List<String> sampleSubcategories;

  const MainCategory({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.gradientColors,
    required this.glowColor,
    this.badge,
    this.sampleSubcategories = const [],
  });
}

/// The 11 authoritative top-level service categories for QuickFix with popular-app styling.
const List<MainCategory> kMainCategories = [
  MainCategory(
    id: 'electrician',
    displayName: 'Electrician',
    subtitle: 'Switch, fan, wiring & fuse repair',
    icon: Icons.bolt_rounded,
    accentColor: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFFFBEB),
    gradientColors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    glowColor: Color(0xFFF59E0B),
    badge: 'Popular',
    sampleSubcategories: ['Fan Repair', 'Switch & Socket', 'MCB Box', 'Inverter'],
  ),
  MainCategory(
    id: 'plumbing',
    displayName: 'Plumbing',
    subtitle: 'Tap, pipe, leakage & tank repair',
    icon: Icons.plumbing_rounded,
    accentColor: Color(0xFF0284C7),
    backgroundColor: Color(0xFFF0F9FF),
    gradientColors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    glowColor: Color(0xFF0284C7),
    badge: 'Express',
    sampleSubcategories: ['Tap & Mixer', 'Pipe Leakage', 'Toilet Fitting', 'Water Tank'],
  ),
  MainCategory(
    id: 'carpenter',
    displayName: 'Carpenter',
    subtitle: 'Furniture repair, locks & assembly',
    icon: Icons.handyman_rounded,
    accentColor: Color(0xFFD97706),
    backgroundColor: Color(0xFFFFFDF5),
    gradientColors: [Color(0xFFF59E0B), Color(0xFFB45309)],
    glowColor: Color(0xFFD97706),
    sampleSubcategories: ['Furniture Assembly', 'Door Locks', 'Bed & Wardrobe', 'Drill & Hang'],
  ),
  MainCategory(
    id: 'ac_repair',
    displayName: 'AC Service & Repair',
    subtitle: 'Gas refill, deep servicing & repair',
    icon: Icons.ac_unit_rounded,
    accentColor: Color(0xFF06B6D4),
    backgroundColor: Color(0xFFECFEFF),
    gradientColors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
    glowColor: Color(0xFF06B6D4),
    badge: 'Warranty',
    sampleSubcategories: ['Split AC Jet Wash', 'Gas Refill', 'Installation', 'PCB Repair'],
  ),
  MainCategory(
    id: 'refrigerator_repair',
    displayName: 'Refrigerator',
    subtitle: 'Cooling issues, compressor & gas',
    icon: Icons.kitchen_rounded,
    accentColor: Color(0xFF2563EB),
    backgroundColor: Color(0xFFEFF6FF),
    gradientColors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
    glowColor: Color(0xFF2563EB),
    sampleSubcategories: ['Single Door', 'Double Door Frost-Free', 'Gas Recharge', 'Compressor'],
  ),
  MainCategory(
    id: 'washing_machine_repair',
    displayName: 'Washing Machine',
    subtitle: 'Spin, motor, drum & drain issues',
    icon: Icons.local_laundry_service_rounded,
    accentColor: Color(0xFF8B5CF6),
    backgroundColor: Color(0xFFF5F3FF),
    gradientColors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
    glowColor: Color(0xFF8B5CF6),
    badge: 'Verified',
    sampleSubcategories: ['Top Load Automatic', 'Front Load', 'Semi-Automatic', 'Motor / PCB'],
  ),
  MainCategory(
    id: 'ro_water_purifier',
    displayName: 'RO & Purifier',
    subtitle: 'Filter change, service & repair',
    icon: Icons.opacity_rounded,
    accentColor: Color(0xFF14B8A6),
    backgroundColor: Color(0xFFF0FDFA),
    gradientColors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
    glowColor: Color(0xFF14B8A6),
    badge: 'Essential',
    sampleSubcategories: ['Complete Service', 'Membrane / Filter', 'Pump / Adapter', 'Installation'],
  ),
  MainCategory(
    id: 'mobile_repair',
    displayName: 'Mobile Repair',
    subtitle: 'Screen, battery, mic & charging port',
    icon: Icons.phone_android_rounded,
    accentColor: Color(0xFFEC4899),
    backgroundColor: Color(0xFFFDF2F8),
    gradientColors: [Color(0xFFF472B6), Color(0xFFDB2777)],
    glowColor: Color(0xFFEC4899),
    badge: 'Express',
    sampleSubcategories: ['Screen / Display', 'Battery Swap', 'Charging Port', 'Water Damage'],
  ),
  MainCategory(
    id: 'laptop_repair',
    displayName: 'Laptop & PC',
    subtitle: 'OS install, SSD, motherboard & display',
    icon: Icons.laptop_chromebook_rounded,
    accentColor: Color(0xFF6366F1),
    backgroundColor: Color(0xFFEEF2FF),
    gradientColors: [Color(0xFF818CF8), Color(0xFF4338CA)],
    glowColor: Color(0xFF6366F1),
    badge: 'Expert',
    sampleSubcategories: ['OS / Windows Format', 'SSD & RAM Boost', 'Screen / Hinge', 'Thermal Clean'],
  ),
  MainCategory(
    id: 'tv_repair',
    displayName: 'TV Repair',
    subtitle: 'LED/LCD display, sound & power repair',
    icon: Icons.tv_rounded,
    accentColor: Color(0xFFE11D48),
    backgroundColor: Color(0xFFFFF1F2),
    gradientColors: [Color(0xFFFB7185), Color(0xFFBE123C)],
    glowColor: Color(0xFFE11D48),
    sampleSubcategories: ['LED Screen Panel', 'Sound / Audio', 'Wall Mounting', 'Power Motherboard'],
  ),
  MainCategory(
    id: 'other_services',
    displayName: 'Other Services',
    subtitle: 'Chimney, microwave, geyser & more',
    icon: Icons.construction_rounded,
    accentColor: Color(0xFF64748B),
    backgroundColor: Color(0xFFF8FAFC),
    gradientColors: [Color(0xFF94A3B8), Color(0xFF475569)],
    glowColor: Color(0xFF64748B),
    sampleSubcategories: ['Chimney Cleaning', 'Microwave Repair', 'Geyser Service', 'Pest Control'],
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
      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      glowColor: const Color(0xFF6E42E5),
      sampleSubcategories: const ['Repair', 'Inspection', 'Service'],
    ),
  );
}
