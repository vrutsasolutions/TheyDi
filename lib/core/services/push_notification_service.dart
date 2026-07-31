import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Push is Android-only. In particular, do not call Firebase Messaging on
    // web: it attempts to register a firebase-messaging-sw.js service worker.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    print('FCM DEBUG 0: PushNotificationService.initialize() called');

    try {
      // ------------------------------------------------------------
      // 1. Request notification permission
      // ------------------------------------------------------------
      print('FCM DEBUG 1: Requesting notification permission...');

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print(
        'FCM DEBUG 2: Permission status = '
            '${settings.authorizationStatus}',
      );

      // ------------------------------------------------------------
      // 2. Initialize local notifications
      // ------------------------------------------------------------
      print('FCM DEBUG 3: Initializing local notifications...');

      const androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidInit,
      );

      await _localNotifications.initialize(initSettings);

      print('FCM DEBUG 4: Local notifications initialized');

      // ------------------------------------------------------------
      // 3. Create Android notification channel
      // ------------------------------------------------------------
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

      // ------------------------------------------------------------
      // 4. Get and save FCM token
      // ------------------------------------------------------------
      print('FCM DEBUG 6: About to save FCM token...');

      await saveTokenToFirestore();

      print('FCM DEBUG 7: saveTokenToFirestore() completed');

      // ------------------------------------------------------------
      // 5. Listen for token refresh
      // ------------------------------------------------------------
      _messaging.onTokenRefresh.listen(
            (newToken) async {
          print('FCM DEBUG 8: FCM token refreshed');
          print('FCM DEBUG 9: Saving refreshed token...');

          await saveTokenToFirestore();

          print('FCM DEBUG 10: Refreshed token saved');
        },
        onError: (error) {
          print('FCM DEBUG ERROR: Token refresh error = $error');
        },
      );

      // ------------------------------------------------------------
      // 6. Foreground notifications
      // ------------------------------------------------------------
      FirebaseMessaging.onMessage.listen(
            (RemoteMessage message) async {
          print('FCM DEBUG 11: Foreground FCM message received');

          print('FCM DEBUG 12: Message ID = ${message.messageId}');
          print('FCM DEBUG 13: Message data = ${message.data}');

          final notification = message.notification;

          if (notification == null) {
            print(
              'FCM DEBUG 14: Message has no notification payload',
            );
            return;
          }

          print(
            'FCM DEBUG 15: Notification title = '
                '${notification.title}',
          );

          print(
            'FCM DEBUG 16: Notification body = '
                '${notification.body}',
          );

          await _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
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

          print(
            'FCM DEBUG 17: Foreground local notification displayed',
          );
        },
        onError: (error) {
          print('FCM DEBUG ERROR: onMessage error = $error');
        },
      );

      // ------------------------------------------------------------
      // 7. Notification opened while app was in background
      // ------------------------------------------------------------
      FirebaseMessaging.onMessageOpenedApp.listen(
            (RemoteMessage message) {
          print(
            'FCM DEBUG 18: Notification opened from background',
          );

          print(
            'FCM DEBUG 19: Message data = ${message.data}',
          );

          _handleMessageNavigation(message);
        },
        onError: (error) {
          print(
            'FCM DEBUG ERROR: onMessageOpenedApp error = $error',
          );
        },
      );

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

    // TODO:
    //
    // Navigate based on:
    //
    // message.data['type']
    // message.data['eventId']
    // message.data['circleId']
    // message.data['chatId']
    //
    // Example:
    //
    // final type = message.data['type'];
    //
    // if (type == 'chat') {
    //   ...
    // }
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
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
