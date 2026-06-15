import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// JoinValidationResult
//
// Returned by JoinValidationService.validate() before any Firestore write.
// The caller uses `outcome` to decide what to do next.
// ─────────────────────────────────────────────────────────────────────────────

enum JoinOutcome {
  /// All checks passed → auto-join (free first-come) or straight to payment
  autoJoin,

  /// Soft mismatch → send to pending with a reason tag visible to the host
  pendingWithTag,

  /// Hard block → show error, no join at all
  blocked,
}

class JoinValidationResult {
  final JoinOutcome outcome;

  /// Human-readable reason shown to the attendee (snackbar / dialog).
  final String? userMessage;

  /// Short tag stored on the pending entry and shown to the host.
  /// e.g. 'Perfect' | 'Age Mismatch' | 'Gender Overflow' | 'Age + Gender'
  final String requestTag;

  /// Individual flags — useful for building the tag string.
  final bool ageMismatch;
  final bool genderOverflow;

  const JoinValidationResult({
    required this.outcome,
    this.userMessage,
    this.requestTag = 'Perfect',
    this.ageMismatch = false,
    this.genderOverflow = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// JoinValidationService
// ─────────────────────────────────────────────────────────────────────────────

class JoinValidationService {
  JoinValidationService._();

  /// Call this BEFORE writing anything to Firestore.
  ///
  /// [eventData]   – the raw Firestore document map of the event
  /// [attendeeDoc] – the raw Firestore document map of the joining user
  static JoinValidationResult validate({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> attendeeDoc,
  }) {
    // ── 1. Capacity check (hard block) ──────────────────────────────────────
    final maxAttendees = (eventData['maxAttendees'] as num?)?.toInt() ?? 0;
    final attendeeUids = List<String>.from(eventData['attendeeUids'] ?? []);
    final currentCount = attendeeUids.length;

    if (maxAttendees > 0 && currentCount >= maxAttendees) {
      return const JoinValidationResult(
        outcome: JoinOutcome.blocked,
        userMessage: 'This event is full. No spots available.',
        requestTag: 'Blocked',
      );
    }

    // ── 2. Age check ────────────────────────────────────────────────────────
    final int userAge = _calculateAge(attendeeDoc);
    final int minAge = (eventData['minAge'] as num?)?.toInt() ?? 0;
    final String ageGroup = (eventData['ageGroup'] as String?) ?? 'All Ages';

    bool ageMismatch = false;

    // Hard block: minAge set (18+) and user is under 18
    if (minAge >= 18 && userAge < 18 && userAge != 99) {
      return const JoinValidationResult(
        outcome: JoinOutcome.blocked,
        userMessage:
            '🔞 This event is for 18+ only. You must be 18 or older to join.',
        requestTag: 'Blocked',
      );
    }

    // Hard block: user hasn't set DOB for an 18+ event
    if (minAge >= 18 && userAge == 99) {
      return const JoinValidationResult(
        outcome: JoinOutcome.blocked,
        userMessage:
            '🔞 Please set your date of birth in your profile to join this 18+ event.',
        requestTag: 'Blocked',
      );
    }

    // Soft mismatch: user age outside the event's age-group range
    if (ageGroup != 'All Ages' && userAge != 99) {
      ageMismatch = !_isInAgeGroup(userAge, ageGroup);
    }

    // ── 3. Gender check ─────────────────────────────────────────────────────
    final String genderBalance =
        (eventData['genderBalance'] as String?) ?? 'Open';
    final String userGender =
        ((attendeeDoc['gender'] as String?) ?? '').toLowerCase();

    bool genderOverflow = false;

    if (genderBalance == 'Female Only' && userGender != 'female') {
      return JoinValidationResult(
        outcome: JoinOutcome.blocked,
        userMessage: 'This event is for female attendees only.',
        requestTag: 'Blocked',
      );
    }

    if (genderBalance == 'Male Only' && userGender != 'male') {
      return JoinValidationResult(
        outcome: JoinOutcome.blocked,
        userMessage: 'This event is for male attendees only.',
        requestTag: 'Blocked',
      );
    }

    if (genderBalance == 'Ratio') {
      genderOverflow =
          _isGenderSlotFull(eventData, attendeeUids, userGender, maxAttendees);
    }

    // ── 4. Compose result ────────────────────────────────────────────────────
    final String tag = _buildTag(ageMismatch, genderOverflow);
    final bool hasIssue = ageMismatch || genderOverflow;

    if (!hasIssue) {
      return const JoinValidationResult(
        outcome: JoinOutcome.autoJoin,
        requestTag: 'Perfect',
      );
    }

    // Soft mismatch → pending with tag (host can still approve)
    return JoinValidationResult(
      outcome: JoinOutcome.pendingWithTag,
      userMessage: _buildUserMessage(ageMismatch, genderOverflow, ageGroup),
      requestTag: tag,
      ageMismatch: ageMismatch,
      genderOverflow: genderOverflow,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int _calculateAge(Map<String, dynamic> userDoc) {
    final dob = userDoc['dob'];
    DateTime? birthDate;
    if (dob is Timestamp) {
      birthDate = dob.toDate();
    } else if (dob is String && dob.isNotEmpty) {
      birthDate = DateTime.tryParse(dob);
    }
    if (birthDate == null) return 99; // unknown
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static bool _isInAgeGroup(int age, String ageGroup) {
    switch (ageGroup) {
      case 'Kids (0–12)':
        return age <= 12;
      case 'Teens (13–17)':
        return age >= 13 && age <= 17;
      case 'Young Adults (18–25)':
        return age >= 18 && age <= 25;
      case 'Adults (26–40)':
        return age >= 26 && age <= 40;
      case 'Middle Age (41–60)':
        return age >= 41 && age <= 60;
      case 'Seniors (60+)':
        return age >= 60;
      default:
        return true;
    }
  }

  /// Returns true if the user's gender slot is already at capacity.
  static bool _isGenderSlotFull(
    Map<String, dynamic> eventData,
    List<String> attendeeUids,
    String userGender,
    int maxAttendees,
  ) {
    if (maxAttendees <= 0) return false;
    final ratio =
        (eventData['genderRatio'] as Map<String, dynamic>?) ?? {};
    double percent = 0.0;
    if (userGender == 'male') {
      percent = (ratio['male'] as num?)?.toDouble() ?? 50.0;
    } else if (userGender == 'female') {
      percent = (ratio['female'] as num?)?.toDouble() ?? 25.0;
    } else {
      percent = (ratio['other'] as num?)?.toDouble() ?? 25.0;
    }

    final int slotCapacity = ((maxAttendees * percent) / 100).ceil();

    // Count how many current attendees share this gender
    // NOTE: gender is not stored on events, so this is a best-effort
    // approximation using the ratio. For production, store gender per
    // attendee uid in a sub-collection. Here we use the ratio proportion.
    final int currentForGender =
        (attendeeUids.length * percent / 100).round();

    return currentForGender >= slotCapacity;
  }

  static String _buildTag(bool ageMismatch, bool genderOverflow) {
    if (ageMismatch && genderOverflow) return 'Age + Gender';
    if (ageMismatch) return 'Age Mismatch';
    if (genderOverflow) return 'Gender Overflow';
    return 'Perfect';
  }

  static String _buildUserMessage(
      bool ageMismatch, bool genderOverflow, String ageGroup) {
    if (ageMismatch && genderOverflow) {
      return 'You\'re outside the "$ageGroup" age group and the gender slot is full. '
          'Your request has been sent — the host can still approve you.';
    }
    if (ageMismatch) {
      return 'This event is designed for "$ageGroup". '
          'Your request has been sent — the host can still approve you.';
    }
    if (genderOverflow) {
      return 'The gender slot for you is currently full. '
          'Your request has been sent — the host can still approve you.';
    }
    return '';
  }
}