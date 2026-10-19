import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user to Firestore after signup
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    final docRef = _db.collection('users').doc(uid);
    final snap = await docRef.get();

    if (snap.exists) {
      // Document already exists — don't overwrite, just fill missing fields
      final data = snap.data() ?? {};
      final updates = <String, dynamic>{};
      if ((data['displayName'] ?? '').toString().isEmpty) {
        updates['displayName'] = name;
      }
      if ((data['name'] ?? '').toString().isEmpty) {
        updates['name'] = name;
      }
      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
      return;
    }

    // Document does not exist — create it
    await docRef.set({
      'uid': uid,
      'name': name,
      'displayName': name,
      'email': email,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'eventsJoined': [],
      'eventsHosted': [],
      'city': '',
      'bio': '',
      'photoUrl': '',
      'age': null,
      'gender': '',
      'interests': [],
      'isVerified': false,
    });
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection('users').doc(uid).update(data);
  }
}

final userService = UserService();