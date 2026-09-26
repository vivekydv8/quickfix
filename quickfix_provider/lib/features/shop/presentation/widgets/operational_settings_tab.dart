import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quickfix_provider/core/theme/app_colors.dart';
import 'package:quickfix_provider/core/theme/app_text_styles.dart';
import 'package:quickfix_provider/features/auth/models/shop_model.dart';

class OperationalSettingsTab extends StatelessWidget {
  final ShopModel shop;
  final bool isDark;
  final String estimatedServiceTime;
  final String priceRange;
  final double serviceRadius;
  final double visitingCharges;
  final bool emergencyAvailable;
  final List<String> holidays;
  final Map<String, dynamic> workingHours;
  final bool bannerUploading;
  
  final VoidCallback onPickAndUploadBanner;
  final ValueChanged<String> onEstimatedServiceTimeChanged;
  final ValueChanged<String> onPriceRangeChanged;
  final VoidCallback onSaveShopCardFields;
  final ValueChanged<double> onServiceRadiusChanged;
  final ValueChanged<double> onVisitingChargesChanged;
  final ValueChanged<bool> onEmergencyAvailableChanged;
  final Function(String, bool) onToggleWorkingDay;
  final VoidCallback onAddHolidayDialog;
  final ValueChanged<String> onRemoveHoliday;
  final VoidCallback? onManageCategories;

  const OperationalSettingsTab({
    super.key,
    required this.shop,
    required this.isDark,
    required this.estimatedServiceTime,
    required this.priceRange,
    required this.serviceRadius,
    required this.visitingCharges,
    required this.emergencyAvailable,
    required this.holidays,
    required this.workingHours,
    required this.bannerUploading,
    required this.onPickAndUploadBanner,
    required this.onEstimatedServiceTimeChanged,
    required this.onPriceRangeChanged,
    required this.onSaveShopCardFields,
    required this.onServiceRadiusChanged,
    required this.onVisitingChargesChanged,
    required this.onEmergencyAvailableChanged,
    required this.onToggleWorkingDay,
    required this.onAddHolidayDialog,
    required this.onRemoveHoliday,
    this.onManageCategories,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Service Categories & Subcategories ───────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SERVICE CATEGORIES & SUBCATEGORIES',
                      style: AppTextStyles.headingSmall(isDark).copyWith(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onManageCategories,
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Manage'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (shop.categories.isEmpty && shop.subcategories.isEmpty)
                  Text(
                    'No categories or subcategories configured yet. Tap "Manage" to configure what services you offer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  )
                else ...[
                  if (shop.categories.isNotEmpty) ...[
                    Text(
                      'Active Categories (${shop.categories.length}):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: shop.categories.map((c) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            c.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (shop.subcategories.isNotEmpty) ...[
                    Text(
                      'Offered Subcategories (${shop.subcategories.length}):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: shop.subcategories.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            s.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Shop Card Appearance ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHOP CARD APPEARANCE',
                  style: AppTextStyles.headingSmall(
                    isDark,
                  ).copyWith(fontSize: 11, color: AppColors.primary),
                ),
                const SizedBox(height: 16),

                // Cover Banner
                GestureDetector(
                  onTap: bannerUploading ? null : onPickAndUploadBanner,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 130,
                          width: double.infinity,
                          child: shop.imagePath.startsWith('data:')
                              ? Image.memory(
                                  base64Decode(
                                    shop.imagePath.split(',').last,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  shop.imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    child: const Icon(
                                      Icons.store,
                                      color: AppColors.primary,
                                      size: 40,
                                    ),
                                  ),
                                ),
                        ),
                        Container(
                          height: 130,
                          width: double.infinity,
                          color: Colors.black45,
                          child: bannerUploading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tap to change shop banner',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Estimated Service Time dropdown
                DropdownButtonFormField<String>(
                  initialValue: estimatedServiceTime,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Service Time',
                    prefixIcon: Icon(Icons.timer_outlined),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '15 mins', child: Text('15 mins')),
                    DropdownMenuItem(value: '20 mins', child: Text('20 mins')),
                    DropdownMenuItem(value: '30 mins', child: Text('30 mins')),
                    DropdownMenuItem(value: '45 mins', child: Text('45 mins')),
                    DropdownMenuItem(value: '1 Hour', child: Text('1 Hour')),
                    DropdownMenuItem(value: '1.5 Hours', child: Text('1.5 Hours')),
                    DropdownMenuItem(value: '2 Hours', child: Text('2 Hours')),
                  ],
                  onChanged: (val) {
                    if (val != null) onEstimatedServiceTimeChanged(val);
                  },
                ),
                const SizedBox(height: 12),

                // Price Level dropdown
                DropdownButtonFormField<String>(
                  initialValue: priceRange,
                  decoration: const InputDecoration(
                    labelText: 'Price Level',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '₹', child: Text('₹  — Budget')),
                    DropdownMenuItem(value: '₹₹', child: Text('₹₹ — Moderate')),
                    DropdownMenuItem(value: '₹₹₹', child: Text('₹₹₹ — Premium')),
                    DropdownMenuItem(value: '₹₹₹₹', child: Text('₹₹₹₹ — Luxury')),
                    DropdownMenuItem(value: 'Starting ₹199', child: Text('Starting ₹199')),
                    DropdownMenuItem(value: 'From ₹299', child: Text('From ₹299')),
                    DropdownMenuItem(value: 'Affordable', child: Text('Affordable')),
                    DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                  ],
                  onChanged: (val) {
                    if (val != null) onPriceRangeChanged(val);
                  },
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSaveShopCardFields,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Card Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Visiting Charges and Radius Slider Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERVICE BOUNDARY',
                  style: AppTextStyles.headingSmall(
                    isDark,
                  ).copyWith(fontSize: 11, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Service Radius',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.secondary,
                      ),
                    ),
                    Text(
                      '${serviceRadius.toStringAsFixed(0)} KM',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: serviceRadius,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: AppColors.primary,
                  onChanged: onServiceRadiusChanged,
                ),
                Divider(
                  height: 32,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visiting / Consult Charges',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.secondary,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 36,
                      child: TextFormField(
                        key: ValueKey('visiting_charges_$visitingCharges'),
                        initialValue: visitingCharges.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.secondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          prefixText: '₹',
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (val) {
                          final numVal = double.tryParse(val);
                          if (numVal != null) {
                            onVisitingChargesChanged(numVal);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 32,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Availability',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.secondary,
                            ),
                          ),
                          Text(
                            'Show active for immediate booking requests',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: emergencyAvailable,
                      activeThumbColor: AppColors.primary,
                      onChanged: onEmergencyAvailableChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Working Hours List Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORKING HOURS',
                  style: AppTextStyles.headingSmall(
                    isDark,
                  ).copyWith(fontSize: 11, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                ...workingHours.keys.map((day) {
                  final dayData = workingHours[day] as Map<String, dynamic>;
                  final isClosed = dayData['isClosed'] as bool? ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : AppColors.secondary,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              isClosed
                                  ? 'CLOSED'
                                  : '${dayData['openTime']} - ${dayData['closeTime']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isClosed
                                    ? AppColors.danger
                                    : (isDark ? Colors.white : AppColors.secondary),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Checkbox(
                              value: !isClosed,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                onToggleWorkingDay(day, val ?? true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Holidays Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HOLIDAYS SCHEDULE',
                      style: AppTextStyles.headingSmall(isDark).copyWith(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: onAddHolidayDialog,
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (holidays.isEmpty)
                  Text(
                    'No holidays scheduled. The shop is active daily.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: holidays
                        .map(
                          (date) => Chip(
                            label: Text(
                              date,
                              style: const TextStyle(fontSize: 11),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 14,
                            ),
                            onDeleted: () => onRemoveHoliday(date),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
