import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:theydi/core/router/app_router.dart'; // wherever rootNavigatorKey lives
import 'package:theydi/core/router/app_routes.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _listenersRegistered = false; // ADD THIS

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    print('FCM DEBUG 0: PushNotificationService.initialize() called');

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('FCM DEBUG 2: Permission status = ${settings.authorizationStatus}');

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(settings: initSettings);
      print('FCM DEBUG 4: Local notifications initialized');

      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'High importance notifications for TheyDi',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      print('FCM DEBUG 5: Notification channel created');

      print('FCM DEBUG 6: About to save FCM token...');
      await saveTokenToFirestore();
      print('FCM DEBUG 7: saveTokenToFirestore() completed');

      // ── Only register listeners ONCE, ever ──
      if (!_listenersRegistered) {
        _listenersRegistered = true;

        _messaging.onTokenRefresh.listen(
          (newToken) async {
            print('FCM DEBUG 8: FCM token refreshed');
            await saveTokenToFirestore();
            print('FCM DEBUG 10: Refreshed token saved');
          },
          onError: (error) =>
              print('FCM DEBUG ERROR: Token refresh error = $error'),
        );

        FirebaseMessaging.onMessage.listen(
          (RemoteMessage message) async {
            print('FCM DEBUG 11: Foreground FCM message received');
            final notification = message.notification;
            if (notification == null) {
              print('FCM DEBUG 14: Message has no notification payload');
              return;
            }
            await _localNotifications.show(
              id: notification.hashCode,
              title: notification.title,
              body: notification.body,
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'high_importance_channel',
                  'High Importance Notifications',
                  channelDescription:
                      'High importance notifications for TheyDi',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
            );
            print('FCM DEBUG 17: Foreground local notification displayed');
          },
          onError: (error) =>
              print('FCM DEBUG ERROR: onMessage error = $error'),
        );

        FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) {
            print('FCM DEBUG 18: Notification opened from background');
            _handleMessageNavigation(message);
          },
          onError: (error) =>
              print('FCM DEBUG ERROR: onMessageOpenedApp error = $error'),
        );
      }

      print('FCM DEBUG 20: PushNotificationService initialized');
    } catch (e, stackTrace) {
      print('FCM DEBUG ERROR: initialize() failed');
      print('FCM DEBUG ERROR: $e');
      print('FCM DEBUG STACK: $stackTrace');
    }
  }

  /// Handles the case where the app was fully closed and the user
  /// tapped a notification to open it.
  static Future<void> checkInitialMessage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    print('FCM DEBUG 21: Checking initial FCM message...');

    try {
      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        print(
          'FCM DEBUG 22: Initial notification found',
        );

        print(
          'FCM DEBUG 23: Initial message data = '
          '${initialMessage.data}',
        );

        _handleMessageNavigation(initialMessage);
      } else {
        print(
          'FCM DEBUG 24: No initial notification message',
        );
      }
    } catch (e, stackTrace) {
      print(
        'FCM DEBUG ERROR: getInitialMessage failed',
      );

      print('FCM DEBUG ERROR: $e');
      print('FCM DEBUG STACK: $stackTrace');
    }
  }

  static void _handleMessageNavigation(
    RemoteMessage message,
  ) {
    print(
      'FCM DEBUG 25: Handling notification navigation',
    );

    print(
      'FCM DEBUG 26: Notification data = ${message.data}',
    );

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      print(
          'FCM DEBUG 26a: No navigator context available yet, skipping navigation');
      return;
    }

    final type = message.data['type'];

    switch (type) {
      case 'nearby_event':
      case 'event':
        final eventId = message.data['eventId'];
        if (eventId != null && eventId.isNotEmpty) {
          context.push('/event/$eventId');
        }
        break;

      case 'circle':
        final circleId = message.data['circleId'];
        if (circleId != null && circleId.isNotEmpty) {
          context.push('/circle/$circleId');
        }
        break;

      case 'chat':
        // TODO: dmChat/circleChat both require an `extra` object
        // (CircleModel, or {otherUid, otherName}) that a bare chatId
        // string can't supply. This needs a Firestore lookup first —
        // e.g. fetch the chat/circle doc for `chatId`, then:
        //   context.push(AppRoutes.dmChat, extra: {...});
        // Not wired yet — falls through to notifications screen for now.
        context.push(AppRoutes.notifications);
        break;

      default:
        print('FCM DEBUG 26b: Unhandled notification type = $type');
    }
  }

  /// Gets the current FCM token and saves it to the
  /// currently authenticated user's Firestore document.
  static Future<void> saveTokenToFirestore() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    print(
      'FCM DEBUG 27: saveTokenToFirestore() started',
    );

    try {
      // ------------------------------------------------------------
      // 1. Get currently authenticated user
      // ------------------------------------------------------------
      final user = FirebaseAuth.instance.currentUser;

      print(
        'FCM DEBUG 28: Firebase Auth user = '
        '${user?.uid}',
      );

      if (user == null) {
        print(
          'FCM DEBUG ERROR: No logged-in Firebase user',
        );
        return;
      }

      // ------------------------------------------------------------
      // 2. Request FCM token
      // ------------------------------------------------------------
      print(
        'FCM DEBUG 29: Requesting FCM token...',
      );

      final token = await _messaging.getToken();

      print(
        'FCM DEBUG 30: getToken() completed',
      );

      // Do NOT print the actual token.
      // We only need to know whether one exists.

      print(
        'FCM DEBUG 31: Token exists = ${token != null}',
      );

      if (token == null) {
        print(
          'FCM DEBUG ERROR: FCM token is NULL',
        );
        return;
      }

      // ------------------------------------------------------------
      // 3. Save token to Firestore
      // ------------------------------------------------------------
      print(
        'FCM DEBUG 32: Saving FCM token to Firestore...',
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': token,
        },
        SetOptions(merge: true),
      );

      print(
        'FCM DEBUG 33: TOKEN SAVED SUCCESSFULLY',
      );

      print(
        'FCM DEBUG 34: Firestore path = '
        'users/${user.uid}',
      );
    } catch (e, stackTrace) {
      print(
        'FCM DEBUG ERROR: saveTokenToFirestore failed',
      );

      print(
        'FCM DEBUG ERROR: $e',
      );

      print(
        'FCM DEBUG STACK: $stackTrace',
      );
    }
  }
}

/// Background FCM handler.
///
/// IMPORTANT:
/// This function must remain a top-level function.
///
/// It is called when an FCM message arrives while the
/// application is running in the background/terminated state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  print(
    'FCM DEBUG 35: Background FCM message received',
  );

  print(
    'FCM DEBUG 36: Background message ID = '
    '${message.messageId}',
  );

  print(
    'FCM DEBUG 37: Background message data = '
    '${message.data}',
  );

  // For notification payloads, Android will normally
  // display the system notification automatically.
}
