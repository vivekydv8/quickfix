import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfix/features/notifications/domain/models/notification_item.dart';
import 'package:quickfix/features/notifications/presentation/controllers/notifications_provider.dart';
import 'package:quickfix/features/notifications/repositories/notifications_repository.dart';

class MockNotificationsRepository implements NotificationsRepository {
  List<NotificationItem> items = [];
  bool shouldThrowOnRead = false;
  bool shouldThrowOnDelete = false;

  @override
  Future<List<NotificationItem>> getNotifications() async {
    return items;
  }

  @override
  Future<NotificationItem> markAsRead(String id) async {
    if (shouldThrowOnRead) throw Exception("Network failure on markAsRead");
    final idx = items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(isRead: true);
      return items[idx];
    }
    throw Exception("Not found");
  }

  @override
  Future<void> markAllAsRead() async {
    if (shouldThrowOnRead) throw Exception("Network failure on markAllAsRead");
    items = items.map((n) => n.copyWith(isRead: true)).toList();
  }

  @override
  Future<void> deleteNotification(String id) async {
    if (shouldThrowOnDelete) throw Exception("Network failure on delete");
    items.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> deleteAllNotifications() async {
    if (shouldThrowOnDelete) throw Exception("Network failure on deleteAll");
    items.clear();
  }

  @override
  Future<int> getUnreadCount() async {
    return items.where((n) => !n.isRead).length;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationItem Model Tests', () {
    test('NotificationItem.fromJson parses full valid json correctly', () {
      final json = {
        'id': 'notif-101',
        'title': 'Booking Accepted',
        'body': 'Provider on the way',
        'time': '2026-09-20T10:00:00Z',
        'createdAt': '2026-09-20T10:00:00Z',
        'isRead': false,
        'icon': 'check_circle',
        'iconColor': 'success',
        'type': 'booking',
        'bookingId': 'BK-1234',
        'deepLink': '/orders/BK-1234'
      };

      final item = NotificationItem.fromJson(json);
      expect(item.id, 'notif-101');
      expect(item.title, 'Booking Accepted');
      expect(item.body, 'Provider on the way');
      expect(item.isRead, false);
      expect(item.bookingId, 'BK-1234');
      expect(item.deepLink, '/orders/BK-1234');
    });

    test('NotificationItem handles missing fields with safe defaults', () {
      final json = {'id': 'notif-default'};
      final item = NotificationItem.fromJson(json);

      expect(item.id, 'notif-default');
      expect(item.title, '');
      expect(item.body, '');
      expect(item.isRead, false);
      expect(item.type, 'general');
    });

    test('NotificationItem.toJson serializes all fields properly', () {
      const item = NotificationItem(
        id: 'notif-serial',
        title: 'Discount',
        body: 'Flat 50% Off',
        isRead: true,
        type: 'promotion',
      );

      final map = item.toJson();
      expect(map['id'], 'notif-serial');
      expect(map['title'], 'Discount');
      expect(map['isRead'], true);
      expect(map['type'], 'promotion');
    });

    test('NotificationItem.copyWith creates modified copy', () {
      const original = NotificationItem(
        id: 'notif-orig',
        title: 'Original',
        body: 'Text',
        isRead: false,
      );

      final updated = original.copyWith(isRead: true);
      expect(updated.id, 'notif-orig');
      expect(updated.title, 'Original');
      expect(updated.isRead, true);
      expect(original.isRead, false);
    });
  });

  group('NotificationsNotifier & Riverpod State Management Tests', () {
    late MockNotificationsRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockNotificationsRepository();
      mockRepo.items = [
        const NotificationItem(
          id: 'n1',
          title: 'Booking Confirmed',
          body: 'Your service is booked',
          isRead: false,
        ),
        const NotificationItem(
          id: 'n2',
          title: 'Provider Assigned',
          body: 'John Doe has been assigned',
          isRead: false,
        ),
        const NotificationItem(
          id: 'n3',
          title: 'Payment Received',
          body: 'Receipt #998',
          isRead: true,
        ),
        const NotificationItem(
          id: 'n4',
          title: 'QuickFix Update Available',
          body: 'System update v2.0',
          type: 'app_update',
          isRead: false,
        ),
      ];

      container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build() fetches notifications and filters system app updates', () async {
      final list = await container.read(notificationsProvider.future);
      expect(list.length, 3);
      expect(list.any((n) => n.id == 'n1'), isTrue);
      expect(list.any((n) => n.id == 'n2'), isTrue);
      expect(list.any((n) => n.id == 'n3'), isTrue);
      expect(list.any((n) => n.id == 'n4'), isFalse); // Filtered out
    });

    test('unreadNotificationsCountProvider calculates unread notifications', () async {
      await container.read(notificationsProvider.future);
      final unreadCount = container.read(unreadNotificationsCountProvider);
      expect(unreadCount, 2); // n1 and n2 are unread
    });

    test('markAsRead updates item state and decreases unread count', () async {
      await container.read(notificationsProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 2);

      await container.read(notificationsProvider.notifier).markAsRead('n1');

      final currentList = container.read(notificationsProvider).value!;
      final n1 = currentList.firstWhere((n) => n.id == 'n1');
      expect(n1.isRead, isTrue);

      final unreadCountAfter = container.read(unreadNotificationsCountProvider);
      expect(unreadCountAfter, 1);
    });

    test('markAsRead rolls back state if repository call fails', () async {
      await container.read(notificationsProvider.future);
      mockRepo.shouldThrowOnRead = true;

      try {
        await container.read(notificationsProvider.notifier).markAsRead('n1');
        fail('Should have thrown an exception');
      } catch (_) {}

      // Verify rollback
      final currentList = container.read(notificationsProvider).value!;
      final n1 = currentList.firstWhere((n) => n.id == 'n1');
      expect(n1.isRead, isFalse);
      expect(container.read(unreadNotificationsCountProvider), 2);
    });

    test('markAllAsRead marks all notifications as read', () async {
      await container.read(notificationsProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 2);

      await container.read(notificationsProvider.notifier).markAllAsRead();

      final currentList = container.read(notificationsProvider).value!;
      for (final item in currentList) {
        expect(item.isRead, isTrue);
      }
      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('deleteNotification permanently removes notification from state', () async {
      await container.read(notificationsProvider.future);
      expect(container.read(notificationsProvider).value!.length, 3);

      await container.read(notificationsProvider.notifier).deleteNotification('n1');

      final currentList = container.read(notificationsProvider).value!;
      expect(currentList.length, 2);
      expect(currentList.any((n) => n.id == 'n1'), isFalse);
      expect(container.read(unreadNotificationsCountProvider), 1);
    });

    test('deleteNotification rolls back item if repository fails', () async {
      await container.read(notificationsProvider.future);
      mockRepo.shouldThrowOnDelete = true;

      try {
        await container.read(notificationsProvider.notifier).deleteNotification('n1');
        fail('Should have thrown an exception');
      } catch (_) {}

      // Verify rollback
      final currentList = container.read(notificationsProvider).value!;
      expect(currentList.length, 3);
      expect(currentList.any((n) => n.id == 'n1'), isTrue);
      expect(container.read(unreadNotificationsCountProvider), 2);
    });

    test('clearAll removes all notifications from state', () async {
      await container.read(notificationsProvider.future);
      expect(container.read(notificationsProvider).value!.length, 3);

      await container.read(notificationsProvider.notifier).clearAll();

      final currentList = container.read(notificationsProvider).value!;
      expect(currentList.isEmpty, isTrue);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });
  });
}
