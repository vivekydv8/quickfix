import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/core/network/network_providers.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/features/notifications/domain/models/notification_item.dart';
import 'package:quickfix/features/notifications/datasources/notifications_remote_data_source.dart';
import 'package:quickfix/features/notifications/repositories/notifications_repository.dart';
import 'package:quickfix/features/notifications/repositories/notifications_repository_impl.dart';

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  final client = ref.watch(dioClientProvider);
  return NotificationsRemoteDataSource(client);
});

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final remote = ref.watch(notificationsRemoteDataSourceProvider);
  return NotificationsRepositoryImpl(remote);
});

class NotificationsNotifier extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    return _fetchNotifications();
  }

  Future<List<NotificationItem>> _fetchNotifications() async {
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final remoteList = await repo.getNotifications();
      return _filterValid(remoteList);
    } catch (e) {
      // Fallback to local cache if available
      final cached = HiveService.getDataCache('user_notifications');
      if (cached != null && cached is List) {
        final list = cached
            .map((e) =>
                NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return _filterValid(list);
      }
      rethrow;
    }
  }

  List<NotificationItem> _filterValid(List<NotificationItem> list) {
    return list.where((item) {
      final title = item.title.toLowerCase();
      final type = item.type.toLowerCase();
      // Filter out system app updates
      if (title.contains('quickfix update') ||
          title.contains('update available') ||
          type == 'system_update' ||
          type == 'app_update') {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  Future<void> markAsRead(String id) async {
    final previousList = state.value;
    if (previousList == null) return;

    final targetIndex = previousList.indexWhere((n) => n.id == id);
    if (targetIndex == -1 || previousList[targetIndex].isRead) {
      return; // Already read or not found
    }

    // Optimistic update
    final updatedList = previousList.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = AsyncValue.data(updatedList);
    await HiveService.saveDataCache(
      'user_notifications',
      updatedList.map((e) => e.toJson()).toList(),
    );

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead(id);
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(previousList);
      await HiveService.saveDataCache(
        'user_notifications',
        previousList.map((e) => e.toJson()).toList(),
      );
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final previousList = state.value;
    if (previousList == null || previousList.isEmpty) return;

    final hasUnread = previousList.any((n) => !n.isRead);
    if (!hasUnread) return;

    // Optimistic update
    final updatedList =
        previousList.map((n) => n.copyWith(isRead: true)).toList();
    state = AsyncValue.data(updatedList);
    await HiveService.saveDataCache(
      'user_notifications',
      updatedList.map((e) => e.toJson()).toList(),
    );

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAllAsRead();
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(previousList);
      await HiveService.saveDataCache(
        'user_notifications',
        previousList.map((e) => e.toJson()).toList(),
      );
      rethrow;
    }
  }

  Future<void> deleteNotification(String id) async {
    final previousList = state.value;
    if (previousList == null) return;

    // Cancel OS tray notification
    unawaited(NotificationService.cancelNotification(id));

    // Optimistic removal
    final updatedList = previousList.where((n) => n.id != id).toList();
    state = AsyncValue.data(updatedList);
    await HiveService.saveDataCache(
      'user_notifications',
      updatedList.map((e) => e.toJson()).toList(),
    );

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.deleteNotification(id);
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(previousList);
      await HiveService.saveDataCache(
        'user_notifications',
        previousList.map((e) => e.toJson()).toList(),
      );
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final previousList = state.value;
    if (previousList == null || previousList.isEmpty) return;

    // Cancel all OS tray notifications
    unawaited(NotificationService.cancelAllNotifications());

    // Optimistic clear
    state = const AsyncValue.data([]);
    await HiveService.saveDataCache('user_notifications', []);

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.deleteAllNotifications();
    } catch (e) {
      // Rollback on failure
      state = AsyncValue.data(previousList);
      await HiveService.saveDataCache(
        'user_notifications',
        previousList.map((e) => e.toJson()).toList(),
      );
      rethrow;
    }
  }

  void resetState() {
    state = const AsyncValue.data([]);
    HiveService.saveDataCache('user_notifications', []);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationItem>>(() {
  return NotificationsNotifier();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.when(
    data: (list) => list.where((item) => !item.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final syncNotificationsProvider = FutureProvider<void>((ref) async {
  await ref.read(notificationsProvider.notifier).refresh();
});
