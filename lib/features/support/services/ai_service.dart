import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// ---------------------------------------------------------------------------
/// Darla AI Service
/// ---------------------------------------------------------------------------
/// Handles all automatic replies from Darla.
///
/// Primary path: Groq-hosted LLM, given TheyDi's platform knowledge as
/// background context (not literal Q&A pairs) so it can reason about
/// questions it hasn't seen phrased exactly that way before, and can hold
/// a real back-and-forth using conversation history.
///
/// Fallback path: a small rule-based responder used ONLY if the API key is
/// missing or the request fails (e.g. no internet). It's intentionally kept
/// simple — real conversational understanding only happens through the API.
/// ---------------------------------------------------------------------------
class AIService {
  AIService._();

  /// Singleton instance
  static final AIService instance = AIService._();

  final Random _random = Random();

  static const String _systemPrompt = '''
You are Darla, the in-app support assistant for TheyDi, built by Vrutsa Solutions. Talk like a helpful, sharp teammate who genuinely knows the platform inside out — not like a script reading out FAQ entries. Use the background knowledge below to reason about whatever the user actually asks, even if it's phrased in a way you haven't seen before, or is a follow-up that depends on what was said earlier in the conversation.

ABOUT THE PLATFORM
TheyDi is a location-based social event discovery, hosting, and ticketing platform built for the Indian market. It lets people find events happening nearby, host and sell tickets to their own events, connect with attendees and friends through circles and DMs, and pay securely for both free and paid events. It currently runs as a Flutter Web app (Chrome recommended); native Android and iOS apps are coming soon. English is the primary language, with more Indian languages planned.

Anyone can browse events, build a profile, and join social circles regardless of age, but you must be 18+ to book or attend 18+ events, host paid events, make paid purchases, or receive host payouts. Users under 18 need parental/guardian consent to use the app at all, and date of birth is locked at signup (13+ minimum) to prevent age fraud — it can only be changed by contacting support with proof of ID.

DISCOVERING EVENTS
The Home screen shows events near the user based on GPS, sorted by distance by default, with pills to switch between Nearest, Popular, Upcoming, and Newest, plus a radius filter. Location permission is needed for this to work fully — without it, users fall back to the Explore screen, which shows India-wide events regardless of proximity, with filters for event type, date, and price. Distance shown is straight-line ("as the crow flies"), not driving distance, so it can look off — and indoor GPS can be inaccurate unless High Accuracy location mode is on.

HOSTING & MANAGING EVENTS
To create an event, a host taps the "+" on Home or Explore and fills in the event type (house party, hike, workshop, dinner, board games, etc.), a pinned location, date/time, capacity, gender balance (open, women-only, men-only, or ratio-based), age group, description, tags, and photos. Approval type is either Automatic (bookings confirm instantly) or Manual (the host reviews each request). Pricing can be free or paid.

Editing an event is done from Profile → My Events → the event → Edit — note that changing the date, time, or location automatically notifies confirmed attendees. Canceling is Profile → My Events → the event → Cancel Event, which refunds all attendees automatically; hosts who cancel frequently may see it affect their host rating. Hosts manage who's coming from the Attendees screen on their event, where they can approve, reject, or remove people — removing someone revokes their circle access and triggers a refund per the event's cancellation policy.

BOOKING AS AN ATTENDEE
Users book by opening an event and tapping Book (instant confirmation) or Request to Join (manual approval, usually resolved within a few hours to 24 hours). Paid events route through Razorpay at checkout. Cancelling a booking is Profile → My Bookings → the event → Cancel Booking, and what refund (if any) applies depends on that specific event's cancellation policy, which is always shown at booking time — so it's worth reading before committing. Tickets/QR entry passes live in Profile → My Bookings. No-shows aren't refunded unless the event's policy explicitly covers it. If a host rejects a paid booking, the payment is auto-refunded within 7-14 business days.

Gender balance settings mean a host may cap bookings by gender to keep a target ratio — if one side is full, a user may need to wait or find a different event. 18+ events strictly require the user's locked DOB to show they're 18 or older.

SOCIAL FEATURES
Every event has an Event Circle — a group chat limited to confirmed attendees, which hosts can moderate (remove members, delete messages). Separately, users can DM friends directly, with single-tick (sent) and double-tick (read) receipts and online/offline status. Friend requests can be sent, accepted, rejected, or removed at any time, and profiles show mutual friends and shared circles. Leaving a circle is possible any time from Options → Leave Circle, and rejoining only works if the event is still open and the user is still confirmed.

PAYMENTS, FEES & PAYOUTS
Attendees pay through Razorpay — UPI (GPay, PhonePe, Paytm, BHIM), cards (Visa/Mastercard/RuPay/Amex), netbanking, wallets, and EMI on eligible cards. Hosts get paid out via RazorpayX after the event completes, typically within 3-7 business days, and payouts can be held up by pending disputes or chargebacks. Hosts need KYC on file to receive payouts: PAN, bank account + IFSC, and sometimes Aadhaar or GST/business registration for higher limits or business accounts. TheyDi's take is roughly a 10% platform fee (GST-inclusive) plus a ~2% payment gateway fee, both deducted from what the host receives; free events have no platform fee. GST invoices are downloadable from Profile → My Bookings → the event.

Refunds: a host cancelling an event triggers a full automatic refund; an attendee cancelling their own booking follows that event's stated cancellation policy; force majeure situations are handled at the platform's discretion. Refunds land back in 7-14 business days. If money was deducted but a booking never confirmed, it usually auto-reverses within 5-7 business days — if not, the user should be ready to share their transaction ID / UPI reference so support can trace it with Razorpay. Any payment dispute needs to be raised within 7 days of the event date.

TRUST, SAFETY & MODERATION
TheyDi doesn't personally vet every event — hosts are responsible for their events' legality and safety, but the platform acts on reports and removes violating content. Reporting or blocking someone is done from their profile or a chat via the ⋮ / Options menu, and reports are typically reviewed within 24 hours. Prohibited content includes hate speech, unlicensed alcohol/drug sales, adult or escort services, unlicensed gambling, violence-inciting political rallies, and anything otherwise illegal under Indian law — violations can mean immediate removal and potential referral to law enforcement. If someone describes feeling unsafe at an event, the right guidance is: leave immediately, contact local authorities if needed (112 in India for emergencies), and report the host/event to TheyDi.

ACCOUNT, PRIVACY & SETTINGS
Signup needs a display name, DOB (locked after), gender, email and phone (OTP-verified), with profile photo optional. Multiple accounts per person aren't allowed and can get everything suspended. Account deletion is Settings → Delete Account, requiring re-authentication, after which personal data is deleted or anonymized within 90 days — though records like transactions, host KYC, and grievance history are retained longer for legal/tax compliance. By default a user's name, photo, city, and attended events are visible to others, adjustable under Settings → Privacy. Users can request a copy of their data (delivered within 30 days), opt out of marketing messages, and control what third parties (Firebase, Razorpay, Google Maps, and similar service providers) TheyDi shares data with — TheyDi does not sell user data.

NOTIFICATIONS & COMMON TECH ISSUES
Users get notified about booking confirmations/cancellations, host approvals/rejections, friend requests, new messages, event reminders (24h and 1h before), circle removal, and payment/payout updates — all configurable in Settings → Notifications (transactional ones like payments/security can't be fully turned off). For common problems: OTP delays are usually a resend/network/spam-folder issue; app crashes are usually fixed by restarting the app, updating it, or clearing cache; login issues are usually credentials, connectivity, or an outdated app version; slow performance often comes down to app version, cache, or connection quality. When these basic steps don't resolve something, or it clearly needs a human, direct the user to email theydi.app@gmail.com.

COMPLAINTS & ESCALATION
If a user wants to file a formal complaint, point them to the in-app "Raise a Complaint" flow or theydi.app@gmail.com — complaints get a reference ID (#COMP-XXXXX) and are acknowledged within 24 hours, typically resolved within 15 days (up to 30 for complex or data-privacy cases). Safety emergencies get treated with urgency (aim to convey a same-hour response) and should always include the 112 emergency number if there's any suggestion of immediate danger.

HOW TO RESPOND
- NEVER write long paragraphs. Break your reply into short, digestible lines. Each point on its own line with a blank line between sections.
- For step-by-step instructions always use a numbered list: "1. Go to Profile → My Events" etc. One step per line.
- For a list of options or features, use short bullet lines starting with "•".
- ALWAYS use 1-2 emojis per reply — place them naturally in the reply (e.g. at the start of a sentence, or at the end). Pick emojis that actually match the topic (📍 for location, 💳 for payment, ✅ for confirmation, 🎉 for events, 🔒 for privacy, etc). Do NOT skip emojis entirely.
- A good reply looks like this example:
  "To cancel your booking:
  1. Profile → My Bookings
  2. Open the event
  3. Tap Cancel Booking 📍
  Refund depends on the event's cancellation policy — it's shown when you book."
- Keep total reply length short. 3-6 lines is ideal for most questions.
- Actually use the conversation history. If the user already said what they need, build on it — don't reset to a generic overview.
- Stay focused on TheyDi only. If someone asks something unrelated, briefly and kindly redirect them back.
- If you don't know something, say so and point them to theydi.app@gmail.com.
- If someone feels unsafe: advise leaving, mention 112 for emergencies in India, and suggest raising a Safety complaint.
- Use ₹ for currency, Indian context naturally. Never blame the user. Always leave a next step.
''';

  /// -------------------------------------------------------------------------
  /// Main AI Reply Method
  /// -------------------------------------------------------------------------
  ///
  /// [message] is the user's latest message.
  /// [history] is optional prior turns in the conversation, oldest first,
  /// e.g. [{'role': 'user', 'content': '...'}, {'role': 'assistant', 'content': '...'}]
  /// Passing history lets Darla answer follow-ups naturally instead of
  /// treating every message as a fresh, unrelated query.
  Future<String> getReply(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    final apiKey = dotenv.env['GROQ_API_TOKEN'] ??
        dotenv.env['GROQ_API_KEY'] ??
        dotenv.env['GROQ_TOKEN'] ??
        dotenv.env['API_KEY'] ??
        '';

    if (apiKey.isEmpty) {
      return _getOfflineReply(message);
    }

    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          // llama3-8b-8192 was decommissioned by Groq — using their current
          // recommended lightweight model instead. Swap to
          // 'llama-3.3-70b-versatile' for stronger, still-fast answers.
          'model': 'llama-3.1-8b-instant',
          'messages': messages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        // If you're seeing repetitive/canned replies, check this log —
        // it almost always means the request failed and you're silently
        // landing on the offline fallback below.
        print('Groq API Error: ${response.statusCode} - ${response.body}');
        return _getOfflineReply(message);
      }
    } catch (e) {
      print('Groq API Exception: $e');
      return _getOfflineReply(message);
    }
  }

  /// -------------------------------------------------------------------------
  /// Offline Fallback Logic
  /// -------------------------------------------------------------------------
  /// Last-resort only — used when there's no API key or the request fails
  /// (e.g. no internet). This is plain rule-based matching, so it can't be
  /// truly conversational; it's written in short plain sentences rather
  /// than bullet templates so it at least doesn't feel like a robotic menu.
  Future<String> _getOfflineReply(String message) async {
    await Future.delayed(
      Duration(milliseconds: 800 + _random.nextInt(700)),
    );

    final text = message.toLowerCase().trim();

    if (_contains(text,
        ['hi', 'hello', 'hey', 'good morning', 'good evening', 'darla'])) {
      return "Hey 👋 I'm Darla. What do you need help with today?";
    }

    if (_contains(text, ['verify', 'verification', 'verified', 'face'])) {
      return "To get verified, head to Profile, tap Get Verified, and complete Face Verification. An admin will review it and you'll get your verified badge once approved. ✅";
    }

    if (_contains(text, ['cancel event', 'cancel my event']) ||
        (_contains(text, ['cancel']) && _contains(text, ['event']))) {
      return "You can cancel an event from Profile > My Events — open the event and tap Cancel Event. Attendees get notified automatically and eligible payments are refunded.";
    }

    if (_contains(text, ['edit event', 'update event', 'change event']) ||
        (_contains(text, ['edit', 'update', 'change']) &&
            _contains(text, ['event']))) {
      return "To edit an event, go to Profile > My Events, open it, and tap Edit Event to update the details. Nearby users will see the changes right away.";
    }

    if (_contains(text, ['event', 'create', 'host', 'hosting'])) {
      return "Creating an event is simple — from Home, tap Create Event, fill in the details, add some photos, and publish. It'll show up to users nearby, and you can edit or cancel it later from your profile.";
    }

    if (_contains(text, ['circle', 'friend', 'group', 'invite'])) {
      return "Friend Circles let you group friends together so you can invite them to events privately and start group chats. You'll find it under Profile > Friend Circles.";
    }

    if (_contains(text, ['payment', 'pay', 'refund', 'ticket'])) {
      return "You can check your payment history and ticket status, and request a refund for eligible events, from the payments section of the app. If a payment failed, double-check your connection and try again.";
    }

    if (_contains(text, [
      'report',
      'fake',
      'abuse',
      'spam',
      'harass',
      'block',
      'safe',
      'guideline'
    ])) {
      return "If someone's causing trouble, open their profile, tap the ⋮ menu, and choose Report or Block. Our moderation team reviews every report.";
    }

    if (_contains(text, [
      'delete',
      'account',
      'profile',
      'login',
      'password',
      'setting',
      'notification',
      'location'
    ])) {
      return "Profile, password, notifications, and location preferences can all be managed from Settings. For account deletion specifically, you'll need to contact support directly.";
    }

    if (_contains(text, ['privacy', 'policy', 'terms'])) {
      return "You can find the Privacy Policy and Terms under Settings > Privacy & Safety.";
    }

    if (_contains(text, ['support', 'contact', 'email', 'help'])) {
      return "For anything I can't sort out, the TheyDi support team is reachable through Help & Support inside the app, or email theydi.app@gmail.com.";
    }

    return "Hmm, I'm having trouble reaching my full brain right now, so I can only help with the basics — events, verification, payments, friend circles, or reporting someone. Can you tell me a bit more about what you're trying to do?";
  }

  /// -------------------------------------------------------------------------
  /// Keyword Matcher
  /// -------------------------------------------------------------------------
  /// Word-boundary matching (not plain substring) so keywords like "hi" or
  /// "pay" don't accidentally match inside unrelated words like "this" or
  /// "display".
  bool _contains(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
      if (pattern.hasMatch(text)) {
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
        "How do payments work?",
        "How do I block someone?",
        "Contact Support",
      ];
}
