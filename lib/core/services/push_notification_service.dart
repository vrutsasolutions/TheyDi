import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:theydi/core/router/app_router.dart'; // wherever rootNavigatorKey lives
import 'package:theydi/core/router/app_routes.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:theydi/features/events/models/event_model.dart';

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _listenersRegistered = false;

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

      // ── Register a tap handler for LOCALLY-shown notifications ──
      // (the ones we display ourselves via _localNotifications.show()
      // when the app is in the foreground). FirebaseMessaging.onMessageOpenedApp
      // does NOT fire for these — only for notifications the OS displayed
      // natively while the app was backgrounded/closed. Without this,
      // tapping a foreground-shown notification does nothing.
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('FCM DEBUG 19: Local notification tapped (foreground path)');
          _handleLocalNotificationTap(response.payload);
        },
      );
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

            final imageUrl = message.data['imageUrl'];
            AndroidNotificationDetails androidDetails;

            if (imageUrl != null && imageUrl.isNotEmpty) {
              try {
                final response = await http.get(Uri.parse(imageUrl));
                final Uint8List imageBytes = response.bodyBytes;

                androidDetails = AndroidNotificationDetails(
                  'high_importance_channel',
                  'High Importance Notifications',
                  channelDescription:
                      'High importance notifications for TheyDi',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                  styleInformation: BigPictureStyleInformation(
                    ByteArrayAndroidBitmap(imageBytes),
                    largeIcon: ByteArrayAndroidBitmap(imageBytes),
                    contentTitle: notification.title,
                    summaryText: notification.body,
                  ),
                );
                print('FCM DEBUG 15: Image downloaded for rich notification');
              } catch (e) {
                print(
                    'FCM DEBUG ERROR: Failed to download notification image: $e');
                androidDetails = const AndroidNotificationDetails(
                  'high_importance_channel',
                  'High Importance Notifications',
                  channelDescription:
                      'High importance notifications for TheyDi',
                  importance: Importance.high,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                );
              }
            } else {
              androidDetails = const AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'High importance notifications for TheyDi',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              );
            }

            // Encode the data so the tap handler above can reconstruct
            // it and navigate — this is the piece that was missing.
            await _localNotifications.show(
              id: notification.hashCode,
              title: notification.title,
              body: notification.body,
              notificationDetails: NotificationDetails(android: androidDetails),
              payload: jsonEncode(message.data),
            );
            print('FCM DEBUG 17: Foreground local notification displayed');
          },
          onError: (error) =>
              print('FCM DEBUG ERROR: onMessage error = $error'),
        );

        FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) {
            print('FCM DEBUG 18: Notification opened from background');
            _handleMessageNavigation(message.data);
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
        print('FCM DEBUG 22: Initial notification found');
        print('FCM DEBUG 23: Initial message data = ${initialMessage.data}');
        _handleMessageNavigation(initialMessage.data);
      } else {
        print('FCM DEBUG 24: No initial notification message');
      }
    } catch (e, stackTrace) {
      print('FCM DEBUG ERROR: getInitialMessage failed');
      print('FCM DEBUG ERROR: $e');
      print('FCM DEBUG STACK: $stackTrace');
    }
  }

  /// Handles taps on notifications shown locally via
  /// _localNotifications.show() while the app was in the foreground.
  static void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) {
      print('FCM DEBUG 19a: No payload on local notification tap');
      return;
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(payload);
      final data = decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      _handleMessageNavigation(data);
    } catch (e) {
      print('FCM DEBUG ERROR: Failed to decode local notification payload: $e');
    }
  }

  static void _handleMessageNavigation(Map<String, dynamic> data) {
    print('FCM DEBUG 25: Handling notification navigation');
    print('FCM DEBUG 26: Notification data = $data');

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      print(
          'FCM DEBUG 26a: No navigator context available yet, skipping navigation');
      return;
    }

    final type = data['type']?.toString() ?? '';
    final title = (data['title']?.toString() ?? '').toLowerCase();
    final body = (data['body']?.toString() ?? '').toLowerCase();
    final eventId = _nullIfEmpty(data['eventId']);
    final fromUid = _nullIfEmpty(data['fromUid']);
    final circleId = _nullIfEmpty(data['circleId']);
    final chatId = _nullIfEmpty(data['chatId']);

    Future<void> openEventDetail() async {
      if (eventId != null) {
        await _pushEventDetail(context, eventId);
      }
    }

    void goManageEvent() {
      if (eventId != null) {
        context.push(AppRoutes.hostManage, extra: eventId);
      }
    }

    switch (type) {
      case 'system':
        if (title.contains('completed') || title.contains('ended')) {
          if (body.contains('marked as completed') ||
              title.contains('event completed')) {
            goManageEvent();
          } else {
            context.go(AppRoutes.myEvents, extra: {'tab': 2, 'filter': 'All'});
          }
        } else if (title.contains('created') || title.contains('live')) {
          goManageEvent();
        } else if (title.contains('cancelled') || title.contains('declined')) {
          context.go(AppRoutes.myEvents, extra: {'tab': 0, 'filter': 'All'});
        } else {
          openEventDetail();
        }
        break;

      case 'suggested_event':
      case 'reminder':
      case 'nearby_event':
      case 'event':
        openEventDetail();
        break;

      case 'review':
        context.push(AppRoutes.myReviews);
        break;

      case 'booking':
        final isCompletePayment =
            title.contains('complete payment') || body.contains('tap to pay');
        final isApproved = title.contains('approved') &&
            !title.contains('join request') &&
            !isCompletePayment;
        final isJoinRequest = title.contains('join request');
        final isNewBooking =
            title.contains('booking') || body.contains('booked');
        final isCancelled =
            title.contains('cancelled') || title.contains('spot cancelled');

        if (isCompletePayment && eventId != null) {
          _pushEventDetail(context, eventId);
        } else if (isApproved) {
          context.go(AppRoutes.myEvents, extra: {'tab': 0, 'filter': 'All'});
        } else if (isJoinRequest && eventId != null) {
          context.push(AppRoutes.hostManage, extra: eventId);
        } else if ((isNewBooking || isCancelled) && eventId != null) {
          context.push(AppRoutes.hostManage, extra: eventId);
        } else if (eventId != null) {
          _pushEventDetail(context, eventId);
        }
        break;

      case 'payment':
        if (title.contains('payout')) {
          context.push(AppRoutes.hostDashboard);
        } else if (title.contains('new attendee') ||
            title.contains('new booking') ||
            body.contains('booked') ||
            body.contains('joined')) {
          goManageEvent();
        } else {
          context.push(AppRoutes.paymenthistory);
        }
        break;

      case 'dm':
      case 'message':
        if (circleId != null) {
          context.go(AppRoutes.circles);
        } else if (fromUid != null) {
          final senderName =
              _extractSenderName(data['title']?.toString() ?? '');
          context.push(AppRoutes.dmChat, extra: {
            'otherUid': fromUid,
            'otherName': senderName,
          });
        } else {
          context.go(AppRoutes.circles);
        }
        break;

      case 'chat':
        // TODO: same limitation as before — needs a Firestore lookup on
        // chatId to build the right `extra` object. Falls back for now.
        print(
            'FCM DEBUG: chat notification tapped, chatId=$chatId (not yet wired)');
        context.push(AppRoutes.notifications);
        break;

      case 'social':
        final isAccepted = title.contains('accepted');
        final isFriendRequest = title.contains('friend request') && !isAccepted;
        final isAddedToCircle = title.contains('added to a circle') ||
            title.contains('added you to');
        final isReview = title.contains('review');

        if (isReview) {
          context.push(AppRoutes.myReviews);
        } else if (isAddedToCircle) {
          context.go(AppRoutes.circles);
        } else if (isAccepted) {
          context.push(AppRoutes.friendsHub);
        } else if (isFriendRequest) {
          context.push(AppRoutes.friendRequests);
        } else if (fromUid != null) {
          context.push(AppRoutes.userProfile,
              extra: {'uid': fromUid, 'requestId': null});
        }
        break;

      case 'suggested_friends':
        context.push(AppRoutes.friendsHub, extra: {'initialTab': 2});
        break;

      case 'suggested_circles':
        context.push(AppRoutes.circleDiscovery, extra: {'initialTab': 2});
        break;

      case 'circle':
      case 'circle_added':
      case 'circle_join_request':
      case 'circle_approved':
      case 'circle_rejected':
      case 'circle_removed':
        context.go('${AppRoutes.circles}?tab=2');
        break;

      case 'admin_verification':
        context.push(AppRoutes.adminVerification);
        break;

      case 'verification':
        context.go(AppRoutes.profile);
        break;

      default:
        print('FCM DEBUG 26b: Unhandled notification type = $type');
        if (eventId != null) openEventDetail();
        break;
    }
  }

  static String? _nullIfEmpty(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  static String _extractSenderName(String title) {
    final match = RegExp(r'from (.+?)(?:\s*[^\w\s].*)?$').firstMatch(title);
    return match?.group(1)?.trim() ?? 'User';
  }

  /// Fetch event from Firestore and push event detail, or show fallback snackbar
  static Future<void> _pushEventDetail(
      BuildContext context, String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (!context.mounted) return;
      if (!doc.exists) {
        // no scaffold context reliably available here from a push tap; just bail
        return;
      }
      final event = EventModel.fromFirestore(doc);
      context.push('/event/$eventId', extra: event);
    } catch (_) {
      // silent fail — no reliable ScaffoldMessenger context on a cold push tap
    }
  }

  /// Gets the current FCM token and saves it to the
  /// currently authenticated user's Firestore document.
  static Future<void> saveTokenToFirestore() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    print('FCM DEBUG 27: saveTokenToFirestore() started');

    try {
      final user = FirebaseAuth.instance.currentUser;
      print('FCM DEBUG 28: Firebase Auth user = ${user?.uid}');

      if (user == null) {
        print('FCM DEBUG ERROR: No logged-in Firebase user');
        return;
      }

      print('FCM DEBUG 29: Requesting FCM token...');
      final token = await _messaging.getToken();
      print('FCM DEBUG 30: getToken() completed');
      print('FCM DEBUG 31: Token exists = ${token != null}');

      if (token == null) {
        print('FCM DEBUG ERROR: FCM token is NULL');
        return;
      }

      print('FCM DEBUG 32: Saving FCM token to Firestore...');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );

      print('FCM DEBUG 33: TOKEN SAVED SUCCESSFULLY');
      print('FCM DEBUG 34: Firestore path = users/${user.uid}');
    } catch (e, stackTrace) {
      print('FCM DEBUG ERROR: saveTokenToFirestore failed');
      print('FCM DEBUG ERROR: $e');
      print('FCM DEBUG STACK: $stackTrace');
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
  print('FCM DEBUG 35: Background FCM message received');
  print('FCM DEBUG 36: Background message ID = ${message.messageId}');
  print('FCM DEBUG 37: Background message data = ${message.data}');
}
