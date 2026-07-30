import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use real URL paths (e.g. /user/abc123) instead of hash routing
  // (e.g. /#/user/abc123) on web. Without this, Flutter web ignores
  // the actual path in the address bar on cold load and always boots
  // at the router's initialLocation — which silently breaks every
  // shared /user/:id, /event/:id, and /circle/:id deep link.
  usePathUrlStrategy();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be registered before runApp, so FCM can wake this handler
  // even when the app is fully terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (kDebugMode) {
    // Commented out to use deployed production Cloud Functions
    // final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    //     ? '10.0.2.2'
    //     : 'localhost';
    // FirebaseFunctions.instanceFor(region: 'asia-south1')
    //     .useFunctionsEmulator(host, 5001);

    // Kept commented out to preserve live user data in Firestore
    // FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }

  // Run database mojibake migration in background
  _fixDatabaseMojibake();

  runApp(const ProviderScope(child: TheyDiApp()));
}

String _cleanText(String text) {
  if (text.isEmpty) return text;
  var cleaned = text;
  final replacements = {
    'â€“': '–', // en dash
    'â€”': '—', // em dash
    'â‚¹': '₹', // rupee symbol
    'ðŸ“\x8d': '📍',
    'ðŸ“ ': '📍 ',
    'ðŸ“': '📍',
    'ðŸŽ‰': '🎉',
    'ðŸ”ž': '🔞',
    'ðŸš€': '🚀',
    'Â·': '·',
    'Â': '',
    'â”€': '─',
    'â†’': '→',
    'â•': '─',
  };
  replacements.forEach((src, dst) {
    cleaned = cleaned.replaceAll(src, dst);
  });
  return cleaned;
}

Future<void> _fixDatabaseMojibake() async {
  final collections = [
    'events',
    'users',
    'reviews',
    'bookings',
    'circles',
    'notifications'
  ];
  for (final colName in collections) {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection(colName).get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        var changed = false;
        final updatedData = <String, dynamic>{};

        data.forEach((key, value) {
          if (value is String) {
            final cleaned = _cleanText(value);
            if (cleaned != value) {
              updatedData[key] = cleaned;
              changed = true;
            }
          } else if (value is List) {
            final cleanedList = [];
            var listChanged = false;
            for (final item in value) {
              if (item is String) {
                final cleaned = _cleanText(item);
                if (cleaned != item) {
                  listChanged = true;
                  cleanedList.add(cleaned);
                } else {
                  cleanedList.add(item);
                }
              } else {
                cleanedList.add(item);
              }
            }
            if (listChanged) {
              updatedData[key] = cleanedList;
              changed = true;
            }
          }
        });

        if (changed) {
          await doc.reference.update(updatedData);
        }
      }
    } catch (_) {
      // Silently ignore permission/access errors for protected collections
    }
  }

  // Collection group query for subcollection 'messages'
  try {
    final messageDocs =
        await FirebaseFirestore.instance.collectionGroup('messages').get();
    for (final doc in messageDocs.docs) {
      final data = doc.data();
      var changed = false;
      final updatedData = <String, dynamic>{};
      data.forEach((key, value) {
        if (value is String) {
          final cleaned = _cleanText(value);
          if (cleaned != value) {
            updatedData[key] = cleaned;
            changed = true;
          }
        }
      });
      if (changed) {
        await doc.reference.update(updatedData);
      }
    }
  } catch (_) {
    // Silently ignore permission/access errors
  }
}

class TheyDiApp extends ConsumerStatefulWidget {
  const TheyDiApp({super.key});

  @override
  ConsumerState<TheyDiApp> createState() => _TheyDiAppState();
}

class _TheyDiAppState extends ConsumerState<TheyDiApp>
    with WidgetsBindingObserver {
  StreamSubscription? _authSub;
  bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Handle the case where the app was fully closed and the user tapped
    // a notification to open it (cold start). Runs once, after the first
    // frame, so the router/navigator is ready to handle navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.checkInitialMessage();
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed ||
            WidgetsBinding.instance.lifecycleState == null) {
          _updateOnlineStatus(true);
        }

        // Initialize push notifications once we have a logged-in user.
        // Guarded so it only runs once per app session, not on every
        // auth state emission (e.g. token refreshes).
        if (!_pushInitialized) {
          _pushInitialized = true;
          PushNotificationService.initialize();
        } else {
          // User is already initialized (e.g. re-login as different user) -
          // still make sure the token on file matches the current uid.
          PushNotificationService.saveTokenToFirestore();
        }
      } else {
        // User logged out - allow re-init on next login.
        _pushInitialized = false;
      }
    });
    _updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updateOnlineStatus(false);
    }
  }

  void _updateOnlineStatus(bool isOnline) {
    Future.microtask(() {
      try {
        NotificationService.setOnlineStatus(isOnline);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TheyDi',
      debugShowCheckedModeBanner: false,
      theme: TheyDiTheme.dark,
      routerConfig: router,
    );
  }
}