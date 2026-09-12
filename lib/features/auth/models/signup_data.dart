import 'package:cloud_firestore/cloud_firestore.dart';

class SignupData {
  String email;
  String password;
  String name;
  String city;
  String displayName;
  String username; // ← NEW: unique @username
  String bio;
  List<String> interests;

  DateTime? dateOfBirth;
  String gender;
  String? profileImageUrl;
  bool emailVerified; // ← NEW: set true after OTP
  bool isVerified; // ← NEW: set true after face verify

  // ── NEW: "what brings you here" + social link ──
  String purpose; // 'Social' | 'Professional'
  String jobTitle; // only used when purpose == 'Professional'
  String organization; // only used when purpose == 'Professional'
  String socialPlatform; // 'LinkedIn' | 'Instagram' | 'Twitter'
  String socialLink;

  SignupData({
    required this.email,
    required this.password,
    required this.name,
    this.city = '',
    this.displayName = '',
    this.username = '',
    this.bio = '',
    List<String>? interests,
    this.dateOfBirth,
    this.gender = '',
    this.profileImageUrl,
    this.emailVerified = false,
    this.isVerified = false,
    this.purpose = '',
    this.jobTitle = '',
    this.organization = '',
    this.socialPlatform = '',
    this.socialLink = '',
  }) : interests = interests ?? [];

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  Map<String, dynamic> toFirestoreMap(String uid) {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'displayName': displayName.isNotEmpty ? displayName : name,
      'username': username.toLowerCase(),
      'city': city,
      'bio': bio,
      'interests': interests,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'age': age,
      'gender': gender,
      'profileImageUrl': profileImageUrl ?? '',
      'photoUrl': profileImageUrl ?? '',
      'eventsCreated': 0,
      'eventsAttended': 0,
      'isVerified': isVerified,
      'verificationStatus': isVerified ? 'verified' : 'none',
      'trustScore': isVerified ? 80 : 50,
      'purpose': purpose,
      'jobTitle': purpose == 'Professional' ? jobTitle : '',
      'organization': purpose == 'Professional' ? organization : '',
      'socialPlatform': socialPlatform,
      'socialLink': socialLink,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}