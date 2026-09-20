import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/theme/app_text_styles.dart';
import 'package:quickfix/core/network/network_providers.dart';
import 'package:quickfix/features/home/models/home_models.dart';

class NotifyMeDialog extends ConsumerStatefulWidget {
  final bool isDark;
  final UserLocation currentLoc;
  final String? categoryTitle;

  const NotifyMeDialog({
    super.key,
    required this.isDark,
    required this.currentLoc,
    this.categoryTitle,
  });

  @override
  ConsumerState<NotifyMeDialog> createState() => _NotifyMeDialogState();
}

class _NotifyMeDialogState extends ConsumerState<NotifyMeDialog> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.categoryTitle != null
        ? "We'll notify you on WhatsApp the moment QuickFix launches ${widget.categoryTitle} near your location."
        : "We'll notify you on WhatsApp the moment QuickFix launches near your location.";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: widget.isDark ? AppColors.surfaceDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Get Notified',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTextStyles.bodySmall(
                widget.isDark,
              ).copyWith(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                filled: true,
                fillColor: widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final phone = _phoneController.text.trim();
                        if (phone.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid phone number',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _isSubmitting = true);
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final dioClient = ref.read(dioClientProvider);
                          await dioClient.post(
                            '/demand/submit',
                            data: {
                              'phone': phone,
                              'address': widget.currentLoc.address,
                              'latitude': widget.currentLoc.latitude,
                              'longitude': widget.currentLoc.longitude,
                            },
                          );
                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ You\'re on the list! We\'ll notify you when we launch near you.',
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ You\'re registered! We\'ll notify you when we launch.',
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Notify Me',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
