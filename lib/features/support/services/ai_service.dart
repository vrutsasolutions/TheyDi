import 'dart:math';

/// ---------------------------------------------------------------------------
/// Darla AI Service
/// ---------------------------------------------------------------------------
/// Handles all automatic replies from Darla.
///
/// NOTE:
/// This is currently rule-based (offline).
///
/// Later you can replace the getReply() method with:
/// • Gemini API
/// • OpenAI API
/// • Firebase Vertex AI
/// without changing the UI.
/// ---------------------------------------------------------------------------
class AIService {
  AIService._();

  /// Singleton instance
  static final AIService instance = AIService._();

  final Random _random = Random();

  /// -------------------------------------------------------------------------
  /// Main AI Reply Method
  /// -------------------------------------------------------------------------
  Future<String> getReply(String message) async {
    // Simulate AI thinking time
    await Future.delayed(
      Duration(milliseconds: 1000 + _random.nextInt(1000)),
    );

    final text = message.toLowerCase().trim();

    // -----------------------------------------------------------------------
    // Greetings
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'hi',
      'hello',
      'hey',
      'good morning',
      'good evening',
    ])) {
      return "Hello 👋 I'm Darla.\n\nHow can I help you today?";
    }

    // -----------------------------------------------------------------------
    // Profile Verification
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'verify',
      'verification',
      'verified',
      'face verification',
    ])) {
      return '''
To verify your profile:

1️⃣ Open Profile

2️⃣ Tap Get Verified

3️⃣ Complete Face Verification

4️⃣ Wait for admin approval

You'll receive a verified badge after approval.
''';
    }

    // -----------------------------------------------------------------------
    // Create Event
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'event',
      'create event',
      'host event',
    ])) {
      return '''
Creating an event is easy.

• Go to Home

• Tap Create Event

• Fill in the details

• Upload images

• Publish your event

Your event will immediately appear to nearby users.
''';
    }

    // -----------------------------------------------------------------------
    // Friend Circles
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'circle',
      'friend circle',
      'group',
    ])) {
      return '''
Friend Circles help you organize your friends.

You can:

• Create circles

• Invite friends

• Share events privately

• Start group chats

Open Friend Circles from your profile to get started.
''';
    }

    // -----------------------------------------------------------------------
    // Payments
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'payment',
      'pay',
      'refund',
      'ticket',
    ])) {
      return '''
Need help with payments?

You can:

• View payment history

• Check ticket status

• Request refunds (eligible events)

If your payment failed, please try again after checking your internet connection.
''';
    }

    // -----------------------------------------------------------------------
    // Report User
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'report',
      'fake',
      'abuse',
      'spam',
      'harassment',
    ])) {
      return '''
To report a user:

Open their profile

↓

Tap ⋮

↓

Report User

Our moderation team reviews every report carefully.
''';
    }

    // -----------------------------------------------------------------------
    // Block User
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'block',
      'blocked',
    ])) {
      return '''
To block someone:

Profile

↓

More Options

↓

Block User

Blocked users won't be able to contact you.
''';
    }

    // -----------------------------------------------------------------------
    // Account
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'delete account',
      'remove account',
      'account',
    ])) {
      return '''
Need account help?

You can update:

• Profile

• Password

• Privacy

• Notifications

For account deletion, contact support from Help & Support.
''';
    }

    // -----------------------------------------------------------------------
    // Privacy
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'privacy',
      'policy',
      'terms',
    ])) {
      return '''
Privacy Policy and Terms & Conditions are available under:

Settings

↓

Privacy & Safety

↓

Privacy Policy

or

↓

Terms & Conditions
''';
    }

    // -----------------------------------------------------------------------
    // Contact Support
    // -----------------------------------------------------------------------
    if (_contains(text, [
      'support',
      'contact',
      'email',
      'help',
    ])) {
      return '''
I'm always here to help.

If you still need assistance, contact the TheyDi support team through Help & Support inside the app.
''';
    }

    // -----------------------------------------------------------------------
    // Default Reply
    // -----------------------------------------------------------------------
    return '''
Sorry, I couldn't understand that.

Try asking about:

• Create Event

• Friend Circles

• Verification

• Payments

• Privacy

• Report User

• Settings
''';
  }

  /// -------------------------------------------------------------------------
  /// Keyword Matcher
  /// -------------------------------------------------------------------------
  bool _contains(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// -------------------------------------------------------------------------
  /// Suggested Questions
  /// -------------------------------------------------------------------------
  List<String> get suggestedQuestions => const [
        "How do I verify my profile?",
        "How can I create an event?",
        "How do Friend Circles work?",
        "How do I report a user?",
        "How do payments work?",
        "How do I block someone?",
        "Where is Privacy Policy?",
        "Contact Support",
      ];
}