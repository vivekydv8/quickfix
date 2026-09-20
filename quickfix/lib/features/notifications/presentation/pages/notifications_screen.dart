import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickfix/core/theme/app_colors.dart';
import 'package:quickfix/core/utils/haptics.dart';
import 'package:quickfix/features/home/presentation/controllers/home_providers.dart';
import 'package:quickfix/features/notifications/domain/models/notification_item.dart';
import 'package:quickfix/features/notifications/presentation/controllers/notifications_provider.dart';
import 'package:quickfix/core/network/error_handler.dart';
import 'package:quickfix/core/widgets/error_widgets.dart';
import 'package:quickfix/core/network/connectivity_provider.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/core/widgets/section_header.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  IconData _iconForColor(String iconColor) {
    switch (iconColor) {
      case 'success':
        return Icons.check_circle_outlined;
      case 'info':
        return Icons.account_balance_wallet_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _colorForTag(String iconColor, bool isDark) {
    switch (iconColor) {
      case 'success':
        return AppColors.success;
      case 'info':
        return AppColors.info;
      case 'warning':
        return AppColors.warning;
      case 'error':
        return Colors.red;
      case 'primary':
        return AppColors.primaryAccent;
      default:
        return AppColors.accent;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      if (next.value == true &&
          previous?.value == false &&
          notificationsAsync.hasError) {
        ref.invalidate(notificationsProvider);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(currentNavIndexProvider.notifier).state = 0;
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: Text(
            'Notifications',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              AppHaptics.lightTap();
              ref.read(currentNavIndexProvider.notifier).state = 0;
              context.go('/home');
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                AppHaptics.lightTap();
                try {
                  await ref.read(notificationsProvider.notifier).markAllAsRead();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to mark all as read. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Mark all read',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_outlined, color: Colors.white),
              tooltip: 'Sync alerts',
              onPressed: () {
                AppHaptics.lightTap();
                ref.read(notificationsProvider.notifier).refresh();
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primaryAccent,
          onRefresh: () async =>
              await ref.read(notificationsProvider.notifier).refresh(),
          child: notificationsAsync.when(
            loading: () => _buildSkeleton(isDark),
            error: (err, st) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top -
                    50,
                alignment: Alignment.center,
                child: CommonErrorWidget(
                  message: ErrorHandler.handle(err, st).message,
                  onRetry: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
                ),
              ),
            ),
            data: (notifications) {
              if (notifications.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height -
                        kToolbarHeight -
                        MediaQuery.of(context).padding.top -
                        50,
                    alignment: Alignment.center,
                    child: const EmptyStateWidget(
                      title: 'All caught up!',
                      message:
                          'We\'ll notify you about bookings, offers, and updates here.',
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                );
              }

              // Group notifications
              final today = <NotificationItem>[];
              final yesterday = <NotificationItem>[];
              final earlier = <NotificationItem>[];

              for (final item in notifications) {
                final timeVal = item.createdAt.isNotEmpty
                    ? item.createdAt
                    : item.time;
                final parsedDate = DateTime.tryParse(timeVal);
                if (parsedDate != null) {
                  final localDate = parsedDate.toLocal();
                  final dateStr = _formatDate(localDate);
                  if (dateStr == 'Today') {
                    today.add(item);
                  } else if (dateStr == 'Yesterday') {
                    yesterday.add(item);
                  } else {
                    earlier.add(item);
                  }
                } else {
                  if (timeVal.toLowerCase().contains('just now')) {
                    today.add(item);
                  } else {
                    earlier.add(item);
                  }
                }
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  if (today.isNotEmpty) ...[
                    SectionHeader(title: 'Today', isDark: isDark),
                    ...today.asMap().entries.map((e) =>
                        _buildNotificationCard(e.value, e.key, isDark)),
                  ],
                  if (yesterday.isNotEmpty) ...[
                    SectionHeader(title: 'Yesterday', isDark: isDark),
                    ...yesterday.asMap().entries.map((e) =>
                        _buildNotificationCard(e.value, e.key, isDark)),
                  ],
                  if (earlier.isNotEmpty) ...[
                    SectionHeader(title: 'Earlier', isDark: isDark),
                    ...earlier.asMap().entries.map((e) =>
                        _buildNotificationCard(e.value, e.key, isDark)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      NotificationItem item, int index, bool isDark) {
    final id = item.id.isNotEmpty ? item.id : index.toString();
    final isRead = item.isRead;
    final iconColor = item.iconColor;
    final color = _colorForTag(iconColor, isDark);
    final icon = _iconForColor(iconColor);

    final timeVal =
        item.createdAt.isNotEmpty ? item.createdAt : item.time;
    String timeStr = 'Just now';

    final parsedDate = DateTime.tryParse(timeVal);
    if (parsedDate != null) {
      final localDate = parsedDate.toLocal();
      timeStr = _formatTime(localDate);
    } else {
      timeStr = timeVal;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: Key('notif_$id'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        onDismissed: (_) async {
          AppHaptics.lightTap();
          try {
            await ref
                .read(notificationsProvider.notifier)
                .deleteNotification(item.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification permanently deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Failed to delete notification. Restoring item...'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
        child: GestureDetector(
          onTap: () {
            AppHaptics.lightTap();
            if (!isRead) {
              ref.read(notificationsProvider.notifier).markAsRead(item.id);
            }
            NotificationService.handleNotificationClick(item.toJson());
          },
          child: Container(
            decoration: BoxDecoration(
              color: !isRead
                  ? (isDark
                      ? AppColors.primaryAccent.withValues(alpha: 0.1)
                      : AppColors.primaryAccent.withValues(alpha: 0.05))
                  : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !isRead
                    ? Colors.transparent
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: 1,
              ),
              boxShadow: [
                if (isRead && !isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  if (!isRead)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: AppColors.primaryAccent),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                timeStr,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate(delay: (30 * index).ms).fadeIn().slideY(begin: 0.05, end: 0),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    final base = isDark ? AppColors.surfaceDark : Colors.grey.shade200;
    final highlight = isDark ? AppColors.borderDark : Colors.grey.shade100;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            height: 88,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}
