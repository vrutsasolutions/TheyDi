import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Small online status indicator shown on top of avatars.
///
/// - Reads `users/{uid}.isOnline`
/// - Shows a green dot only when online
/// - Hides completely when offline
class AvatarOnlineStatusDot extends StatelessWidget {
  final String uid;
  final double size;

  const AvatarOnlineStatusDot({super.key, required this.uid, this.size = 9});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final isOnline = data?['isOnline'] == true;

        if (!isOnline) return const SizedBox.shrink();

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
          ),
        );
      },
    );
  }
}
