import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickfix/core/router/app_router.dart';
import 'package:quickfix/core/logging/app_logger.dart';
import 'package:quickfix/core/network/api_endpoints.dart';
import 'package:quickfix/core/storage/hive_service.dart';
import 'package:quickfix/core/network/dns_bypass_helper.dart';

// ─── Background Handler (top-level, vm:entry-point required) ────────────────

/// **Firebase & Notifications**: Handles incoming background push notifications.
/// 
/// Since this executes in a completely separate Dart VM isolate when the application
/// is suspended or terminated, it must be annotated with `@pragma('vm:entry-point')`.
/// It re-initializes Firebase and Hive independently to save notification histories to disk.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await Hive.initFlutter();
  final box = await Hive.openBox('local_notifications');
  final notificationData = _parseMessage(message);
  if (notificationData != null) {
    await box.put(notificationData['id'], notificationData);
  }
  AppLogger.info(
    'Background message received: ${message.messageId}',
    tag: 'FCM',
  );
}

Map<String, dynamic>? _parseMessage(RemoteMessage message) {
  final notification = message.notification;
  final data = message.data;
  final title = notification?.title ?? data['title'] ?? '';
  final type = data['type']?.toString() ?? 'general';

  // Completely block and turn off "QuickFix Update" & system update notifications
  if (title.toLowerCase().contains('quickfix update') ||
      title.toLowerCase().contains('update available') ||
      type == 'system_update' ||
      type == 'app_update') {
    return null;
  }

  final id = (data['notificationId'] ??
          data['id'] ??
          message.messageId ??
          DateTime.now().millisecondsSinceEpoch.toString())
      .toString();
  return {
    'id': id,
    'title': title.isNotEmpty ? title : 'Notification',
    'body': notification?.body ?? data['body'] ?? '',
    'time': DateTime.now().toIso8601String(),
    'isRead': false,
    'type': type,
    'bookingId': data['bookingId'] ?? '',
    'orderId': data['orderId'] ?? '',
    'deepLink': data['deepLink'] ?? '',
    'iconColor': data['iconColor'] ?? 'primary',
  };
}

// ─── NotificationService ─────────────────────────────────────────────────────

/// Enterprise service for managing system notifications and remote alerts.
/// 
/// Interacts with [FirebaseMessaging] to handle downstream cloud notifications
/// and uses [FlutterLocalNotificationsPlugin] to display foreground banner alerts on mobile platforms.
/// Includes support for token synchronization, background persistence, and deep-link routing on click.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Booking updates, payment receipts, and platform alerts.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Initializes the Firebase Messaging and Local Notification channels.
  /// 
  /// Performs background registration, checks for permissions, sets up local Android notifications,
  /// attaches foreground listeners, and handles application launching via notification tapping.
  static Future<void> init() async {
    try {
      // 1. Ensure Hive notifications box is open
      if (!Hive.isBoxOpen('local_notifications')) {
        await Hive.openBox('local_notifications');
      }

      // 2. Register background message handler FIRST
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 3. Initialize flutter_local_notifications
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');
      const InitializationSettings initSettings = InitializationSettings(
        android: initAndroid,
      );
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final Map<String, dynamic> data = Uri.splitQueryString(payload);
              handleNotificationClick(data);
            } catch (e) {
              AppLogger.error(
                'Failed to parse notification payload',
                tag: 'FCM',
                error: e,
              );
            }
          }
        },
      );

      // 4. Request notification permissions
      await requestPermissions();

      // 5. Create the Android notification channel
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_channel);
      }

      // 6. Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        AppLogger.info('Foreground message: ${message.messageId}', tag: 'FCM');
        final notificationData = _parseMessage(message);
        if (notificationData == null) return;
        final box = Hive.box('local_notifications');
        await box.put(notificationData['id'], notificationData);

        final title = notificationData['title'] as String? ?? '';
        final body = notificationData['body'] as String? ?? '';

        if (title.isNotEmpty && !kIsWeb) {
          final data = message.data;
          final payload = Uri(
            queryParameters: data.map((k, v) => MapEntry(k, v.toString())),
          ).query;

          _localNotificationsPlugin.show(
            notificationData['id'].hashCode,
            title,
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@drawable/ic_notification',
                importance: Importance.max,
                priority: Priority.high,
                ticker: 'ticker',
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.public,
                styleInformation: BigTextStyleInformation(
                  body,
                  contentTitle: title,
                ),
              ),
            ),
            payload: payload,
          );
        }
      });

      // 7. Background notification tap handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info(
          'Notification tap from background: ${message.messageId}',
          tag: 'FCM',
        );
        handleNotificationClick(message.data);
      });

      // 8. Token refresh — re-sync when token rotates
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        AppLogger.info('FCM token refreshed: $newToken', tag: 'FCM');
        await syncTokenWithBackend(newToken);
      });

      // 9. Terminated state + topic subscription + initial token sync (run asynchronously in background)
      unawaited(_initStartup());
    } catch (e, s) {
      AppLogger.error(
        'NotificationService.init failed',
        tag: 'FCM',
        error: e,
        stackTrace: s,
      );
    }
  }

  static Future<void> _initStartup() async {
    // Handle app launch via notification (terminated state)
    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 2));
      if (initialMessage != null) {
        AppLogger.info(
          'App launched via terminated notification: ${initialMessage.messageId}',
          tag: 'FCM',
        );
        Future.delayed(const Duration(milliseconds: 1200), () {
          handleNotificationClick(initialMessage.data);
        });
      }
    } catch (e) {
      AppLogger.error('Failed to get initial message', tag: 'FCM', error: e);
    }

    // Subscribe to customer topic
    try {
      await subscribeToTopic('customers');
    } catch (e) {
      AppLogger.error(
        'Failed to subscribe to customers topic',
        tag: 'FCM',
        error: e,
      );
    }

    // Sync current FCM token to backend on app startup if logged in
    try {
      final fcmToken = await getToken().timeout(const Duration(seconds: 2));
      if (fcmToken != null) {
        // Only sync if user is logged in
        final authToken = HiveService.getAuthToken();
        if (authToken != null) {
          await syncTokenWithBackend(fcmToken);
        }
      }
    } catch (e) {
      AppLogger.error('Failed to sync token on startup', tag: 'FCM', error: e);
    }
  }

  static Future<void> requestPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        carPlay: false,
        criticalAlert: false,
      );
      AppLogger.info(
        'Notification permission: ${settings.authorizationStatus}',
        tag: 'FCM',
      );

      // Android 13+ — request POST_NOTIFICATIONS runtime permission explicitly
      if (Platform.isAndroid) {
        await Permission.notification.request();
        final androidPlugin = _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      }
    } catch (e) {
      AppLogger.error(
        'Error requesting notification permissions',
        tag: 'FCM',
        error: e,
      );
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      AppLogger.info('Subscribed to topic: $topic', tag: 'FCM');
    } catch (e) {
      AppLogger.error(
        'Failed to subscribe to topic: $topic',
        tag: 'FCM',
        error: e,
      );
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      AppLogger.info('Unsubscribed from topic: $topic', tag: 'FCM');
    } catch (e) {
      AppLogger.error(
        'Failed to unsubscribe from topic: $topic',
        tag: 'FCM',
        error: e,
      );
    }
  }

  static Future<String?> getToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      AppLogger.info('FCM Token: ${token?.substring(0, 20)}...', tag: 'FCM');
      return token;
    } catch (e) {
      AppLogger.error('Failed to get FCM Token', tag: 'FCM', error: e);
      return null;
    }
  }

  /// **API Usage & Firebase**: Transmits the registration token to the backend server.
  /// 
  /// Appends the user's JWT authorization header. If the local network has routing restrictions,
  /// it routes requests through the [DnsBypassHelper] with custom certificate overrides.
  /// After a successful synchronization, the token is written to Hive to avoid repetitive requests.
  static Future<void> syncTokenWithBackend(String token) async {
    final authToken = HiveService.getAuthToken();
    if (authToken == null) {
      AppLogger.info('Skipping token sync — user not logged in', tag: 'FCM');
      return;
    }

    try {
      final dioClient = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (DnsBypassHelper.shouldBypass(ApiEndpoints.baseUrl)) {
        dioClient.options.baseUrl = DnsBypassHelper.bypassUrl(
          ApiEndpoints.baseUrl,
          dioClient.options.headers,
        );
        ((dioClient.httpClientAdapter) as IOHttpClientAdapter)
            .createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback = DnsBypassHelper.verifyCertificate;
          return client;
        };
      }

      final response = await dioClient.post(
        '/api/auth/profile/update',
        data: {'fcmToken': token},
      );

      if (response.statusCode == 200) {
        AppLogger.info('FCM Token synced to backend successfully', tag: 'FCM');
        // Update cached profile with new token
        final cached = HiveService.getCachedProfile();
        if (cached != null) {
          final updated = Map<String, dynamic>.from(cached);
          updated['fcmToken'] = token;
          await HiveService.saveCachedProfile(updated);
        }
      }
    } catch (e) {
      AppLogger.error(
        'Failed to sync FCM Token to backend',
        tag: 'FCM',
        error: e,
      );
    }
  }

  /// Called after successful login to register the FCM token immediately
  static Future<void> onUserLoggedIn() async {
    try {
      await requestPermissions();
      final fcmToken = await getToken();
      if (fcmToken != null) {
        await syncTokenWithBackend(fcmToken);
      }
      await subscribeToTopic('customers');
    } catch (e) {
      AppLogger.error(
        'Failed to register FCM after login',
        tag: 'FCM',
        error: e,
      );
    }
  }

  /// **Important Logic & Routing**: Maps push payload variables to GoRouter navigation paths.
  /// 
  /// Inspects parameter tags to direct users:
  /// - `booking` / `booking_status`: Navigates to live GPS tracking (`/tracking/:id`).
  /// - `offer` / `promotion`: Navigates to promotion list page (`/offers`).
  /// - `support`: Navigates to support chat/email.
  static void handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final bookingId = data['bookingId']?.toString();
    final deepLink = data['deepLink']?.toString();

    AppLogger.info(
      'Notification tap: type=$type, bookingId=$bookingId',
      tag: 'FCM',
    );

    if (deepLink != null && deepLink.isNotEmpty) {
      try {
        appRouter.push(deepLink);
        return;
      } catch (_) {}
    }

    switch (type) {
      case 'booking':
      case 'booking_status':
      case 'Booking':
        if (bookingId != null && bookingId.isNotEmpty) {
          appRouter.push('/tracking/$bookingId');
        } else {
          appRouter.push('/orders');
        }
        break;
      case 'offer':
      case 'promotion':
        appRouter.push('/offers');
        break;
      case 'support':
        appRouter.push('/support');
        break;
      case 'payment':
        appRouter.push('/orders');
        break;
      case 'general':
      default:
        appRouter.push('/notifications');
        break;
    }
  }

  /// Cancels a specific locally displayed system tray notification
  static Future<void> cancelNotification(String id) async {
    try {
      if (kIsWeb) return;
      final notifId = id.hashCode;
      await _localNotificationsPlugin.cancel(notifId);
      AppLogger.info('Cancelled local notification: $id (hash: $notifId)', tag: 'FCM');
    } catch (e) {
      AppLogger.info('Local notification cancellation skipped or unavailable: $e', tag: 'FCM');
    }
  }

  /// Cancels all displayed system notifications
  static Future<void> cancelAllNotifications() async {
    try {
      if (kIsWeb) return;
      await _localNotificationsPlugin.cancelAll();
      AppLogger.info('Cancelled all local notifications', tag: 'FCM');
    } catch (e) {
      AppLogger.info('Local notifications cancellation skipped or unavailable: $e', tag: 'FCM');
    }
  }
}
