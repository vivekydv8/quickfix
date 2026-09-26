import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix_provider/core/theme/app_colors.dart';
import 'package:quickfix_provider/features/auth/models/shop_model.dart';
import 'package:quickfix_provider/features/shop/presentation/controllers/shop_provider.dart';

class CategoryDef {
  final String id;
  final String name;
  final IconData icon;
  final List<SubcategoryDef> subcategories;

  const CategoryDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.subcategories,
  });
}

class SubcategoryDef {
  final String id;
  final String name;
  final String description;

  const SubcategoryDef({
    required this.id,
    required this.name,
    required this.description,
  });
}

const List<CategoryDef> kAvailableCategories = [
  CategoryDef(
    id: 'electrician',
    name: 'Electrician',
    icon: Icons.bolt_rounded,
    subcategories: [
      SubcategoryDef(id: 'fan_repair', name: 'Fan Repair', description: 'Ceiling, exhaust and table fan repair & installation'),
      SubcategoryDef(id: 'switch_socket', name: 'Switch & Socket', description: 'Switchboard repair, socket replacement'),
      SubcategoryDef(id: 'mcb_box', name: 'MCB Box & Fuse', description: 'MCB tripping, fuse wire replacement'),
      SubcategoryDef(id: 'inverter_service', name: 'Inverter & Battery', description: 'Inverter installation, battery checkup'),
    ],
  ),
  CategoryDef(
    id: 'plumbing',
    name: 'Plumbing',
    icon: Icons.plumbing_rounded,
    subcategories: [
      SubcategoryDef(id: 'tap_mixer', name: 'Tap & Mixer', description: 'Water tap leaking, mixer replacement'),
      SubcategoryDef(id: 'pipe_leakage', name: 'Pipe Leakage', description: 'Concealed pipe leak, drainage block'),
      SubcategoryDef(id: 'toilet_fitting', name: 'Toilet Fitting', description: 'Flush tank, jet spray, commode seat'),
      SubcategoryDef(id: 'water_tank', name: 'Water Tank', description: 'Overhead tank cleaning, valve fix'),
    ],
  ),
  CategoryDef(
    id: 'carpenter',
    name: 'Carpenter',
    icon: Icons.handyman_rounded,
    subcategories: [
      SubcategoryDef(id: 'furniture_assembly', name: 'Furniture Assembly', description: 'Bed, wardrobe, dining table assembly'),
      SubcategoryDef(id: 'door_locks', name: 'Door & Locks', description: 'Handle replacement, latch repair'),
      SubcategoryDef(id: 'bed_wardrobe', name: 'Bed & Wardrobe', description: 'Hinges alignment, drawer channel'),
      SubcategoryDef(id: 'drill_hang', name: 'Drill & Hang', description: 'Wall shelves, mirror, frames mounting'),
    ],
  ),
  CategoryDef(
    id: 'ac_repair',
    name: 'AC Service & Repair',
    icon: Icons.ac_unit_rounded,
    subcategories: [
      SubcategoryDef(id: 'split_ac_jet', name: 'Split AC Jet Wash', description: 'Deep foam + jet pump cleaning'),
      SubcategoryDef(id: 'ac_gas_refill', name: 'Gas Refill', description: 'Leak test & refrigerant recharge'),
      SubcategoryDef(id: 'ac_install', name: 'Installation / Uninstallation', description: 'Split or window AC installation'),
      SubcategoryDef(id: 'ac_pcb_repair', name: 'PCB & Compressor Repair', description: 'Inverter PCB diagnostic, capacitor fix'),
    ],
  ),
  CategoryDef(
    id: 'refrigerator_repair',
    name: 'Refrigerator',
    icon: Icons.kitchen_rounded,
    subcategories: [
      SubcategoryDef(id: 'fridge_single_door', name: 'Single Door Refrigerator', description: 'Cooling coil, thermostat, relay fix'),
      SubcategoryDef(id: 'fridge_double_door', name: 'Double Door Frost-Free', description: 'Defrost timer, bimetal sensor'),
      SubcategoryDef(id: 'fridge_gas', name: 'Gas Recharge', description: 'Gas leak diagnosis and recharge'),
      SubcategoryDef(id: 'fridge_compressor', name: 'Compressor Repair', description: 'Compressor replacement and relay swap'),
    ],
  ),
  CategoryDef(
    id: 'washing_machine_repair',
    name: 'Washing Machine',
    icon: Icons.local_laundry_service_rounded,
    subcategories: [
      SubcategoryDef(id: 'wm_top_load', name: 'Top Load Automatic', description: 'Pulsator, spin drum, drain valve fixes'),
      SubcategoryDef(id: 'wm_front_load', name: 'Front Load Automatic', description: 'Drum bearing, door gasket fix'),
      SubcategoryDef(id: 'wm_semi_auto', name: 'Semi-Automatic', description: 'Wash motor, spin timer repair'),
      SubcategoryDef(id: 'wm_motor_pcb', name: 'Motor & PCB Board', description: 'Display panel, PCB repair'),
    ],
  ),
  CategoryDef(
    id: 'ro_water_purifier',
    name: 'RO & Purifier',
    icon: Icons.water_drop_rounded,
    subcategories: [
      SubcategoryDef(id: 'ro_complete_service', name: 'Complete Service', description: 'Full membrane flush, filter cleaning'),
      SubcategoryDef(id: 'ro_membrane_filter', name: 'Membrane & Filter Change', description: 'Sediment, carbon, RO membrane swap'),
      SubcategoryDef(id: 'ro_pump_adapter', name: 'Pump & Adapter Fix', description: 'Booster pump repair, SMPS supply'),
      SubcategoryDef(id: 'ro_installation', name: 'RO Installation / Shift', description: 'Wall mount uninstall and reinstall'),
    ],
  ),
  CategoryDef(
    id: 'mobile_repair',
    name: 'Mobile Repair',
    icon: Icons.phone_android_rounded,
    subcategories: [
      SubcategoryDef(id: 'mob_screen', name: 'Screen & Display', description: 'Cracked glass, AMOLED/LCD replacement'),
      SubcategoryDef(id: 'mob_battery', name: 'Battery Replacement', description: 'Battery drain check and OEM swap'),
      SubcategoryDef(id: 'mob_port_mic', name: 'Charging Port & Mic', description: 'Type-C/Lightning connector, mic repair'),
      SubcategoryDef(id: 'mob_water_damage', name: 'Water Damage & Motherboard', description: 'Ultrasonic cleaning, IC fix'),
    ],
  ),
  CategoryDef(
    id: 'laptop_repair',
    name: 'Laptop & PC',
    icon: Icons.laptop_mac_rounded,
    subcategories: [
      SubcategoryDef(id: 'laptop_os_format', name: 'OS & Software Fix', description: 'Windows/macOS install, virus removal'),
      SubcategoryDef(id: 'laptop_ssd_ram', name: 'SSD & RAM Upgrade', description: 'NVMe SSD boost, RAM expansion'),
      SubcategoryDef(id: 'laptop_screen_hinge', name: 'Screen & Hinge Repair', description: 'Body fabrication, screen replacement'),
      SubcategoryDef(id: 'laptop_thermal_clean', name: 'Deep Thermal Cleaning', description: 'Fan dust removal, thermal paste repasting'),
    ],
  ),
  CategoryDef(
    id: 'tv_repair',
    name: 'TV Repair',
    icon: Icons.tv_rounded,
    subcategories: [
      SubcategoryDef(id: 'tv_panel', name: 'LED Screen & Panel', description: 'Horizontal lines, backlight LED strip fix'),
      SubcategoryDef(id: 'tv_sound', name: 'Sound & Audio Fix', description: 'Speaker crackling, audio IC fix'),
      SubcategoryDef(id: 'tv_mounting', name: 'Wall Mounting & Setup', description: 'Swivel / fixed wall mount installation'),
      SubcategoryDef(id: 'tv_motherboard', name: 'Power Board & Motherboard', description: 'Dead TV, standby red light repair'),
    ],
  ),
  CategoryDef(
    id: 'other_services',
    name: 'Other Services',
    icon: Icons.cleaning_services_rounded,
    subcategories: [
      SubcategoryDef(id: 'deep_cleaning', name: 'Deep Home Cleaning', description: 'Complete home sanitization and deep scrubbing'),
      SubcategoryDef(id: 'sofa_cleaning', name: 'Sofa & Carpet Cleaning', description: 'Shampooing, vacuuming, and stain removal'),
      SubcategoryDef(id: 'kitchen_cleaning', name: 'Kitchen Cleaning', description: 'Chimney, tiles degreasing, and platform wash'),
      SubcategoryDef(id: 'bathroom_cleaning', name: 'Bathroom Cleaning', description: 'Tile descaling, fittings shine, and sanitization'),
    ],
  ),
];

class ManageCategoriesDialog extends ConsumerStatefulWidget {
  final ShopModel shop;

  const ManageCategoriesDialog({super.key, required this.shop});

  @override
  ConsumerState<ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState
    extends ConsumerState<ManageCategoriesDialog> {
  late Set<String> _selectedCategories;
  late Set<String> _selectedSubcategories;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategories = widget.shop.categories
        .map((c) => c.toLowerCase().trim())
        .toSet();
    _selectedSubcategories = widget.shop.subcategories
        .map((s) => s.toLowerCase().trim())
        .toSet();

    // If categories was empty, auto-detect from shop services
    if (_selectedCategories.isEmpty && widget.shop.services.isNotEmpty) {
      for (final cat in kAvailableCategories) {
        if (_selectedCategories.contains(cat.id)) continue;
        for (final srv in widget.shop.services) {
          final title = (srv['title'] ?? '').toString().toLowerCase();
          if (title.contains(cat.id) || title.contains(cat.name.toLowerCase())) {
            _selectedCategories.add(cat.id);
          }
        }
      }
    }
  }

  void _toggleCategory(String catId) {
    setState(() {
      if (_selectedCategories.contains(catId)) {
        _selectedCategories.remove(catId);
        // Remove subcategories of this category
        final catDef = kAvailableCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => kAvailableCategories.first,
        );
        for (final sub in catDef.subcategories) {
          _selectedSubcategories.remove(sub.id);
        }
      } else {
        _selectedCategories.add(catId);
        // Auto-select all subcategories of newly added category
        final catDef = kAvailableCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => kAvailableCategories.first,
        );
        for (final sub in catDef.subcategories) {
          _selectedSubcategories.add(sub.id);
        }
      }
    });
  }

  void _toggleSubcategory(String subId, String parentCatId) {
    setState(() {
      if (_selectedSubcategories.contains(subId)) {
        _selectedSubcategories.remove(subId);
      } else {
        _selectedSubcategories.add(subId);
        // Ensure parent category is selected
        _selectedCategories.add(parentCatId);
      }
    });
  }

  void _selectAllForCategory(CategoryDef cat) {
    setState(() {
      _selectedCategories.add(cat.id);
      for (final sub in cat.subcategories) {
        _selectedSubcategories.add(sub.id);
      }
    });
  }

  void _clearAllForCategory(CategoryDef cat) {
    setState(() {
      for (final sub in cat.subcategories) {
        _selectedSubcategories.remove(sub.id);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one main category.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ref
        .read(shopManagementProvider.notifier)
        .updateCategoriesAndSubcategories(
          categories: _selectedCategories.toList(),
          subcategories: _selectedSubcategories.toList(),
        );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categories & Subcategories updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save categories. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        child: Column(
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Services & Categories',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          '${_selectedCategories.length} Categories • ${_selectedSubcategories.length} Subcategories Selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Categories & Subcategories List ────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: kAvailableCategories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final cat = kAvailableCategories[index];
                  final isCatSelected = _selectedCategories.contains(cat.id);
                  final selectedCountInCat = cat.subcategories
                      .where((s) => _selectedSubcategories.contains(s.id))
                      .length;

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? (isCatSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.03))
                          : (isCatSelected
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCatSelected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        width: isCatSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: isCatSelected,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isCatSelected
                              ? AppColors.primary
                              : (isDark ? Colors.white12 : Colors.grey.shade200),
                          child: Icon(
                            cat.icon,
                            size: 18,
                            color: isCatSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (selectedCountInCat > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$selectedCountInCat/${cat.subcategories.length}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Checkbox(
                          value: isCatSelected,
                          activeColor: AppColors.primary,
                          onChanged: (_) => _toggleCategory(cat.id),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subcategories:',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _selectAllForCategory(cat),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Select All',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () => _clearAllForCategory(cat),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: cat.subcategories.map((sub) {
                                    final isSubSelected =
                                        _selectedSubcategories.contains(sub.id);
                                    return FilterChip(
                                      label: Text(sub.name),
                                      selected: isSubSelected,
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      checkmarkColor: AppColors.primary,
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.shade100,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSubSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSubSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                      side: BorderSide(
                                        color: isSubSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.white10 : Colors.grey.shade300),
                                      ),
                                      onSelected: (_) =>
                                          _toggleSubcategory(sub.id, cat.id),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // ── Dialog Footer ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
