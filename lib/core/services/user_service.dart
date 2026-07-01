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
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
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

      // Add these two fields
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
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
