import 'package:quickfix/features/notifications/datasources/notifications_remote_data_source.dart';
import 'package:quickfix/features/notifications/domain/models/notification_item.dart';
import 'package:quickfix/features/notifications/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  NotificationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<NotificationItem>> getNotifications() {
    return _remoteDataSource.getNotifications();
  }

  @override
  Future<NotificationItem> markAsRead(String id) {
    return _remoteDataSource.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String id) {
    return _remoteDataSource.deleteNotification(id);
  }

  @override
  Future<void> deleteAllNotifications() {
    return _remoteDataSource.deleteAllNotifications();
  }

  @override
  Future<int> getUnreadCount() {
    return _remoteDataSource.getUnreadCount();
  }
}
