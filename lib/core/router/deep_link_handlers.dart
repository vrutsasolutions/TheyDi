import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:theydi/core/theme/app_theme.dart';
import 'package:theydi/features/events/models/event_model.dart';
import 'package:theydi/features/events/screens/event_detail_screen.dart';
import 'package:theydi/features/circles/models/circle_model.dart';
import 'package:theydi/features/circles/screens/circle_info_screen.dart';

class DeepLinkEventScreen extends StatelessWidget {
  final String eventId;
  const DeepLinkEventScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('events').doc(eventId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TheyDiColors.primary));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Event not found', style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          final event = EventModel.fromFirestore(snapshot.data!);
          return EventDetailScreen(event: event);
        },
      ),
    );
  }
}

class DeepLinkCircleScreen extends StatelessWidget {
  final String circleId;
  const DeepLinkCircleScreen({super.key, required this.circleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('circles').doc(circleId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TheyDiColors.primary));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Circle not found', style: TextStyle(color: TheyDiColors.textPrimary)));
          }
          final circle = CircleModel.fromFirestore(snapshot.data!);
          return CircleInfoScreen(circle: circle);
        },
      ),
    );
  }
}
