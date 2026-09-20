import 'package:quickfix/core/network/dio_client.dart';
import 'package:quickfix/core/network/api_response_validator.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/features/notifications/domain/models/notification_item.dart';

class NotificationsRemoteDataSource {
  final DioClient _client;

  NotificationsRemoteDataSource(this._client);

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final response = await _client.get('/notifications');
      final list = ApiResponseValidator.requireList(
        response.data,
        context: 'getNotifications',
      );
      final rawList =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await HiveService.saveDataCache('user_notifications', rawList);
      return rawList.map((e) => NotificationItem.fromJson(e)).toList();
    } catch (e) {
      final cached = HiveService.getDataCache('user_notifications');
      if (cached != null && cached is List) {
        return cached
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  Future<NotificationItem> markAsRead(String id) async {
    final response = await _client.patch('/notifications/$id/read');
    final data = ApiResponseValidator.requireMap(
      response.data,
      context: 'markAsRead',
    );
    final notifMap = data['notification'] != null
        ? Map<String, dynamic>.from(data['notification'] as Map)
        : data;
    return NotificationItem.fromJson(notifMap);
  }

  Future<void> markAllAsRead() async {
    await _client.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _client.delete('/notifications/$id');
  }

  Future<void> deleteAllNotifications() async {
    await _client.delete('/notifications');
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _client.get('/notifications/unread-count');
      if (response.data is Map && response.data['count'] != null) {
        return int.tryParse(response.data['count'].toString()) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}

