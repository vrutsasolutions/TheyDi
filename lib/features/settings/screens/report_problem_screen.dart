import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:theydi/core/router/app_routes.dart';
import 'package:intl/intl.dart';

class ReportProblemScreen extends StatelessWidget {
  const ReportProblemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Report History'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;
        // Debug logs for auth state
        // ignore: avoid_print
        print('ReportHistory: currentUser: $user');
        // ignore: avoid_print
        print('ReportHistory: currentUser.uid: ${user?.uid}');

        if (user == null) {
          // Not signed in — navigate to login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(AppRoutes.login);
          });
          return const Scaffold();
        }

        final queryStream = FirebaseFirestore.instance
            .collection('reports')
            .where('reporterUid', isEqualTo: user.uid)
            .snapshots();

        // Log the query path and uid
        // ignore: avoid_print
        print(
            'ReportHistory: Firestore query -> reports where reporterUid=${user.uid}');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Report History'),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: queryStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                if (error is FirebaseException) {
                  // Log firebase exception
                  // ignore: avoid_print
                  print(
                      'ReportHistory: FirebaseException code=${error.code} message=${error.message}');

                  if (error.code == 'permission-denied') {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No reports found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }

                  if (error.code == 'unauthenticated') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.go(AppRoutes.login);
                    });
                    return const SizedBox.shrink();
                  }
                }

                // Generic error fallback
                // ignore: avoid_print
                print('ReportHistory: Unknown error: $error');

                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Unable to load report history right now. Please try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No reports found.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              final reports = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aDate = parseCreatedAt(aData['createdAt']);
                  final bDate = parseCreatedAt(bData['createdAt']);
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final data = reports[index].data() as Map<String, dynamic>;

                  String formattedDate = '';

                  final createdAt = parseCreatedAt(data['createdAt']);
                  if (createdAt != null) {
                    formattedDate = DateFormat(
                      'dd MMM yyyy • hh:mm a',
                    ).format(createdAt);
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.flag),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  data['reportedName'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  (data['status'] ?? 'pending')
                                      .toString()
                                      .toUpperCase(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Reason: ${data['reason'] ?? '-'}'),
                          const SizedBox(height: 4),
                          Text('Type: ${data['type'] ?? '-'}'),
                          const SizedBox(height: 4),
                          Text('Source: ${data['source'] ?? '-'}'),
                          const SizedBox(height: 4),
                          Text(
                            'Reported User ID:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(data['reportedUid'] ?? '-'),
                          const SizedBox(height: 8),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  DateTime? parseCreatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
