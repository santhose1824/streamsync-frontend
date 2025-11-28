import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/notifications/models/app_notifications.dart';

/// Background message handler for Firebase (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background Firebase message: ${message.notification?.title}');
  // Show notification using Awesome Notifications
  await AwesomeNotificationService.showNotificationFromFirebase(message);
}

class AwesomeNotificationService {
  static final AwesomeNotifications _notifications = AwesomeNotifications();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Stream to emit notifications to BLoC
  static final _notificationController = StreamController<AppNotification>.broadcast();
  static Stream<AppNotification> get onNotificationReceived => _notificationController.stream;

  static bool _initialized = false;

  /// Initialize Awesome Notifications
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    print('🔔 Initializing Awesome Notifications...');

    // 1. Initialize Awesome Notifications
    // ✅ Pass null to use the default app icon
    await _notifications.initialize(
      null,

      // Notification channels
      [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'General app notifications',
          defaultColor: const Color(0xFF6C63FF),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'high_importance_channel',
          channelName: 'Important Notifications',
          channelDescription: 'High priority notifications',
          defaultColor: const Color(0xFFFF0000),
          ledColor: Colors.red,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],

      // Debug mode
      debug: true,
    );

    print('✅ Awesome Notifications initialized');

    // 2. Request notification permission
    final isAllowed = await _notifications.isNotificationAllowed();
    print('🔔 Notification permission: $isAllowed');

    if (!isAllowed) {
      print('🔔 Requesting notification permission...');
      final granted = await _notifications.requestPermissionToSendNotifications();
      print('🔔 Permission granted: $granted');
    }

    // 3. Setup Firebase permission
    print('🔔 Requesting Firebase permission...');
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('🔔 Firebase Permission: ${settings.authorizationStatus}');

    // 4. Get FCM token immediately
    final token = await _messaging.getToken();
    print('🔑 Initial FCM Token: ${token?.substring(0, 20)}...');

    // 5. Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
      // TODO: You might want to register the new token with backend
    });

    // 6. Setup Firebase listeners
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground Firebase message received');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
      print('   Data: ${message.data}');

      showNotificationFromFirebase(message);
    });

    // Notification tapped (from background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification opened app from background');
      print('   Title: ${message.notification?.title}');

      _handleFirebaseNotificationTap(message);
    });

    // App launched from notification (terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔔 App launched from notification (terminated state)');
      print('   Title: ${initialMessage.notification?.title}');

      _handleFirebaseNotificationTap(initialMessage);
    }

    // 7. Setup Awesome Notifications listeners
    _notifications.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
      onNotificationCreatedMethod: _onNotificationCreatedMethod,
      onNotificationDisplayedMethod: _onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: _onDismissActionReceivedMethod,
    );

    print('✅ All notification listeners setup complete');
  }

  /// Get FCM token
  static Future<String?> getFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        print('🔑 FCM Token retrieved: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM Token is null');
      }
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Show notification from Firebase RemoteMessage
  static Future<void> showNotificationFromFirebase(RemoteMessage message) async {
    print('📬 Creating local notification from Firebase message...');

    final notificationId = message.data['id'] ??
        message.data['notificationId'] ??
        message.messageId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final title = message.notification?.title ?? message.data['title'] ?? 'New Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    print('   ID: $notificationId');
    print('   Title: $title');
    print('   Body: $body');

    try {
      await _notifications.createNotification(
        content: NotificationContent(
          id: notificationId.hashCode,
          channelKey: 'high_importance_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.Default,
          payload: {
            'id': notificationId,
            'title': title,
            'body': body,
            ...message.data,
          },
          wakeUpScreen: true,
          category: NotificationCategory.Message,
          autoDismissible: true,
        ),
      );

      print('✅ Local notification created successfully');

      // Emit to stream for BLoC
      final appNotification = _convertFirebaseToAppNotification(message);
      _notificationController.add(appNotification);

      print('✅ Notification emitted to stream');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  /// Handle notification tap from Firebase
  static void _handleFirebaseNotificationTap(RemoteMessage message) {
    print('👆 Handling notification tap...');
    final appNotification = _convertFirebaseToAppNotification(message);
    _notificationController.add(appNotification);
  }

  /// Convert RemoteMessage to AppNotification
  static AppNotification _convertFirebaseToAppNotification(RemoteMessage message) {
    final notificationId = message.data['id'] ??
        message.data['notificationId'] ??
        message.messageId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    return AppNotification(
      id: notificationId,
      title: message.notification?.title ?? message.data['title'] ?? '',
      body: message.notification?.body ?? message.data['body'] ?? '',
      isRead: false,
      isDeleted: false,
      createdAt: DateTime.now(),
      metadata: message.data.isNotEmpty ? message.data : null,
    );
  }

  /// Called when notification is created
  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreatedMethod(
      ReceivedNotification receivedNotification,
      ) async {
    print('🔔 Awesome Notification created: ${receivedNotification.title}');
  }

  /// Called when notification is displayed
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification,
      ) async {
    print('🔔 Awesome Notification displayed: ${receivedNotification.title}');
  }

  /// Called when user taps notification
  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
      ReceivedAction receivedAction,
      ) async {
    print('🔔 Awesome Notification tapped: ${receivedAction.title}');
    print('   Button pressed: ${receivedAction.buttonKeyPressed}');

    // Convert payload to AppNotification
    if (receivedAction.payload != null) {
      final payload = receivedAction.payload!;

      final appNotification = AppNotification(
        id: payload['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: payload['title'] ?? '',
        body: payload['body'] ?? '',
        isRead: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        metadata: payload,
      );

      _notificationController.add(appNotification);
      print('✅ Notification from tap emitted to stream');
    }
  }

  /// Called when notification is dismissed
  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceivedMethod(
      ReceivedAction receivedAction,
      ) async {
    print('🔔 Awesome Notification dismissed: ${receivedAction.title}');
  }

  /// Test method - manually show notification (for debugging)
  static Future<void> showTestNotification() async {
    print('🧪 Showing test notification...');

    try {
      await _notifications.createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'high_importance_channel',
          title: '🧪 Test Notification',
          body: 'This is a test notification from Awesome Notifications',
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
      );
      print('✅ Test notification created');
    } catch (e) {
      print('❌ Error creating test notification: $e');
    }
  }

  /// Get current badge count
  static Future<int> getBadgeCount() async {
    return await _notifications.getGlobalBadgeCounter();
  }

  /// Set badge count
  static Future<void> setBadgeCount(int count) async {
    await _notifications.setGlobalBadgeCounter(count);
    print('📛 Badge count set to: $count');
  }

  /// Reset badge count
  static Future<void> resetBadgeCount() async {
    await _notifications.resetGlobalBadge();
    print('📛 Badge count reset');
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Dispose
  static void dispose() {
    _notificationController.close();
  }
}