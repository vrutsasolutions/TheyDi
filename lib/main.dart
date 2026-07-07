import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    // Connect to the local Cloud Functions Emulator to bypass CORS
    // FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator('localhost', 5001);
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
  final collections = ['events', 'users', 'reviews', 'bookings', 'circles', 'notifications'];
  for (final colName in collections) {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection(colName).get();
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
    final messageDocs = await FirebaseFirestore.instance.collectionGroup('messages').get();
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

class TheyDiApp extends ConsumerWidget {
  const TheyDiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TheyDi',
      debugShowCheckedModeBanner: false,
      theme: TheyDiTheme.dark,
      routerConfig: router,
    );
  }
}