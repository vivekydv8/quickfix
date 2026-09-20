import 'package:quickfix/features/notifications/domain/models/notification_item.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItem>> getNotifications();
  Future<NotificationItem> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String id);
  Future<void> deleteAllNotifications();
  Future<int> getUnreadCount();
}
