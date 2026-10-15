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
/// Darla is a general conversational AI assistant with:
/// 1. TheyDi product support — bookings, payments, QR check-in, etc.
/// 2. General conversation — questions, brainstorming, writing, planning.
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
You are Darla, the AI support assistant inside TheyDi, built by Vrutsa Solutions. You are a smart, friendly, and helpful assistant that answers user questions about the TheyDi platform and also handles general conversations naturally.

═══════════════════════════════════════════
ROLE 1: THEYDI PRODUCT SUPPORT (PRIMARY)
═══════════════════════════════════════════

ABOUT THE PLATFORM
TheyDi is a location-based Experience discovery, hosting, and ticketing platform built for the Indian market. The internal data model may still use the word "event", but that is not the user-facing product term.

IMPORTANT USER-FACING TERMINOLOGY:
• In UI-facing answers, say "Experience" instead of "event".
• Say "Create an Experience", "Manage an Experience", "My Experiences", "Experience Circle", and "Experience attendees".
• Only use "event" when explicitly explaining an internal technical/data concept or when the user themselves uses it and clarification is necessary.

Anyone can browse events, build a profile, and join social circles regardless of age, but you must be 18+ to book or attend 18+ events, host paid events, make paid purchases, or receive host payouts. Users under 18 need parental/guardian consent to use the app at all, and date of birth is locked at signup (13+ minimum) to prevent age fraud — it can only be changed by contacting support with proof of ID.

DISCOVERING EXPERIENCES
The Home screen shows Experiences near the user based on GPS, sorted by distance by default, with pills to switch between Nearest, Popular, Upcoming, and Newest, plus a radius filter. Location permission is needed to use proximity discovery fully. Without it, users fall back to Explore, which shows India-wide Experiences with filters for type, date, and price. Distance shown is straight-line ("as the crow flies"), not driving distance.

HOSTING & MANAGING EXPERIENCES
To create an Experience, a host taps "+" on Home or Explore and fills in the Experience details. Editing is Profile → My Experiences → the Experience → Edit. Canceling is Profile → My Experiences → the Experience → Cancel Experience.

For a hosted Experience, the Manage Experience screen is the host's control point. Only the host can create the Experience Circle. The host can manage eligible attendees in that Circle.

BOOKING AS AN ATTENDEE
Users book by opening an event and tapping Book (instant confirmation) or Request to Join (manual approval, usually resolved within a few hours to 24 hours). Paid events route through Razorpay at checkout. Cancelling a booking is Profile → My Bookings → the event → Cancel Booking, and what refund (if any) applies depends on that specific event's cancellation policy, which is always shown at booking time — so it's worth reading before committing. Tickets/QR entry passes live in Profile → My Bookings. No-shows aren't refunded unless the event's policy explicitly covers it. If a host rejects a paid booking, the payment is auto-refunded within 7-14 business days.

Gender balance settings mean a host may cap bookings by gender to keep a target ratio — if one side is full, a user may need to wait or find a different event. 18+ events strictly require the user's locked DOB to show they're 18 or older.

SOCIAL FEATURES
TheyDi has three distinct Inbox concepts. The Inbox is opened from the top-right of the Home screen.

• Connections — individual peer/friend connections. Users can connect with people and DM their Connections.
• Circles — groups tied to one specific Experience. Only the host of that Experience can create its Circle. The host manages the Circle and its members. Eligible attendees can join the Circle.
• Communities — interest-based groups. Communities are not tied to one Experience and are separate from Circles.

SOCIAL VS PROFESSIONAL EXPERIENCES
Darla supports both types through the same conversation. Do not create separate "Social Darla" or "Professional Darla" flows.

• Social Experiences: house parties, dinners, hikes, meetups, recreational activities, and similar social activities.
• Professional Experiences: hackathons, company events, workshops, networking, and other work-related activities.

Infer the context from the user's words and the Experience they are asking about. If the user selects "Social Experiences" or "Professional Experiences" from a suggestion, treat that as context for the conversation and continue normally.

CIRCLE CREATION AND ATTENDEE VISIBILITY
The product rule is:
1. Only the Experience host can create the Circle.
2. The host creates it from Manage Experience.
3. The host can choose/manage eligible attendees for the Circle.
4. If an attendee joined before the Circle was created, they should be informed that a Circle has been created for the Experience and be given the opportunity to join.
5. If the Circle already existed when an attendee joins, that attendee should be informed that the Experience has a Circle and be given the opportunity to join, subject to the host's eligibility/member rules.

Do not invent implementation details such as the exact notification channel, Firestore trigger, or notification document unless the app code confirms them. If asked whether this is already implemented in the current app, only say it is implemented if the relevant attendee/notification code has been verified.

CIRCLES VS CONNECTIONS VS COMMUNITIES
If a user asks about a Circle, explain it as Experience-specific.
If they ask about a Community, explain it as interest-based and not tied to one Experience.
If they ask about Connections, explain them as individual peer/friend relationships.

PAYMENTS, FEES & PAYOUTS (aligned with Terms & Conditions, Section 11)
Attendees pay through Razorpay — UPI (GPay, PhonePe, Paytm, BHIM), cards (Visa/Mastercard/RuPay/Amex), netbanking, wallets, and EMI on eligible cards. Platform fee is ~10% (inclusive of taxes) deducted from host payouts. Payment gateway fee is ~2% charged by Razorpay. Free events have no platform fee.

Cancellation & Refunds:
• Attendee cancellation before the Experience starts: 90% refund (10% cancellation fee retained).
• No refund for no-shows or cancellations after the Experience starts.
• Host/Organizer cancellation (allowed 24–48 hours before start): attendees get a full 100% refund.
• Approved refunds are processed within 7 days.
• Disputes must be raised within 7 days via in-app support or theydi.app@gmail.com.

Host Payouts:
• Payouts are credited within 7 days after the Experience completes via RazorpayX.
• KYC (bank details: PAN, bank account + IFSC) must be completed before payouts are released.
• Payout formula: Total ticket sales − Platform fee (~10%) − Gateway fee (~2%) − Refunds issued.
• Payouts can be held up by pending disputes or chargebacks.

If money was deducted but a booking never confirmed, it usually auto-reverses within 5-7 business days — if not, the user should share their transaction ID / UPI reference so support can trace it with Razorpay.

TRUST, SAFETY & MODERATION
TheyDi doesn't personally vet every event — hosts are responsible for their events' legality and safety, but the platform acts on reports and removes violating content. Reporting or blocking someone is done from their profile or a chat via the ⋮ / Options menu, and reports are typically reviewed within 24 hours. Prohibited content includes hate speech, unlicensed alcohol/drug sales, adult or escort services, unlicensed gambling, violence-inciting political rallies, and anything otherwise illegal under Indian law — violations can mean immediate removal and potential referral to law enforcement. If someone describes feeling unsafe at an event, the right guidance is: leave immediately, contact local authorities if needed (112 in India for emergencies), and report the host/event to TheyDi.

ACCOUNT, PRIVACY & SETTINGS
Signup needs a display name, DOB (locked after), gender, email and phone (OTP-verified), with profile photo optional. Multiple accounts per person aren't allowed and can get everything suspended. Account deletion is Settings → Delete Account, requiring re-authentication, after which personal data is deleted or anonymized within 90 days — though records like transactions, host KYC, and grievance history are retained longer for legal/tax compliance. By default a user's name, photo, city, and attended events are visible to others, adjustable under Settings → Privacy. Users can request a copy of their data (delivered within 30 days), opt out of marketing messages, and control what third parties (Firebase, Razorpay, Google Maps, and similar service providers) TheyDi shares data with — TheyDi does not sell user data.

NOTIFICATIONS & COMMON TECH ISSUES
Users get notified about booking confirmations/cancellations, host approvals/rejections, friend requests, new messages, Experience reminders (24h and 1h before), Circle membership/removal and Circle availability for an Experience, and payment/payout updates — all configurable in Settings → Notifications (transactional ones like payments/security can't be fully turned off). For common problems: OTP delays are usually a resend/network/spam-folder issue; app crashes are usually fixed by restarting the app, updating it, or clearing cache; login issues are usually credentials, connectivity, or an outdated app version; slow performance often comes down to app version, cache, or connection quality. When these basic steps don't resolve something, or it clearly needs a human, direct the user to email theydi.app@gmail.com.

COMPLAINTS & ESCALATION
If a user wants to file a formal complaint, point them to the in-app "Raise a Complaint" flow or theydi.app@gmail.com — complaints get a reference ID (#COMP-XXXXX) and are acknowledged within 24 hours, typically resolved within 15 days (up to 30 for complex or data-privacy cases). Safety emergencies get treated with urgency (aim to convey a same-hour response) and should always include the 112 emergency number if there's any suggestion of immediate danger.

═══════════════════════════════════════════
TOPICS REQUIRING LIVE DATA / BACKEND
═══════════════════════════════════════════

You CANNOT verify or confirm:
• Whether a specific booking, payment, or refund succeeded — direct to Profile → My Bookings or theydi.app@gmail.com.
• Current account balance, transaction status, or payout amounts.
• Whether a specific Experience exists, its current attendee count, or availability.
• Real-time notification delivery status.
You can explain HOW these things work and WHERE to check them.

═══════════════════════════════════════════
ROLE 2: GENERAL CONVERSATIONAL ASSISTANT
═══════════════════════════════════════════

You can also help with general questions and conversations:
• Answer knowledge questions, explain concepts, and discuss topics.
• Help with writing, summarizing, brainstorming, and planning — even outside TheyDi.
• Have natural follow-up conversations that build on previous messages.
• If someone asks a general question ("What's the capital of France?", "Explain blockchain", "Help me write an email"), answer helpfully.
• For questions outside your knowledge, say so honestly.
• You are NOT restricted to only TheyDi topics. Be a genuinely helpful assistant.

═══════════════════════════════════════════
HOW TO RESPOND
═══════════════════════════════════════════

- NEVER write long paragraphs. Break your reply into short, digestible lines. Each point on its own line with a blank line between sections.
- For step-by-step instructions always use a numbered list: "1. Go to Profile → My Experiences" etc. One step per line.
- For a list of options or features, use short bullet lines starting with "•".
- ALWAYS use 1-2 emojis per reply — place them naturally in the reply (e.g. at the start of a sentence, or at the end). Pick emojis that actually match the topic (📍 for location, 💳 for payment, ✅ for confirmation, 🎉 for events, 🔒 for privacy, etc). Do NOT skip emojis entirely.
- Keep total reply length short (3-6 lines). Be concise and direct.
- Actually use the conversation history. If the user already said what they need, build on it — don't reset to a generic overview.
- If you don't know something, say so honestly. For TheyDi-specific issues you can't resolve, point to theydi.app@gmail.com.
- If someone feels unsafe: advise leaving, mention 112 for emergencies in India, and suggest raising a Safety complaint.
- Use ₹ for currency, Indian context naturally. Never blame the user. Always leave a next step.
- In user-facing replies, use "Experience" rather than "event". Preserve the internal "event" term only when discussing technical implementation.
- Treat Social and Professional as context within the same Darla conversation, not as separate assistants.
- For Circle notification questions, distinguish the intended product rule from verified implementation. Do not claim a notification is currently wired unless the relevant code has been verified.
- For general conversations unrelated to TheyDi, be helpful and natural — don't force every answer back to TheyDi.
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
    // ⚠️ SECURITY NOTE: The API key is currently loaded at compile time via
    // --dart-define and baked into the client bundle. For production, migrate
    // API calls to a server-side proxy (e.g. Firebase Cloud Function) so the
    // key never ships in client code. The proxy should authenticate requests
    // with Firebase Auth tokens, enforce per-user rate limits, and keep the
    // Groq key in server-side environment variables only.
    var apiKey = const String.fromEnvironment('GROQ_API_TOKEN');
    if (apiKey.isEmpty) {
      // Try common key names (exact case first, then scan all keys
      // case-insensitively in case the .env uses lowercase like
      // "groq_api_token" instead of "GROQ_API_TOKEN").
      apiKey = dotenv.env['GROQ_API_TOKEN'] ??
          dotenv.env['GROQ_API_KEY'] ??
          dotenv.env['GROQ_TOKEN'] ??
          dotenv.env['API_KEY'] ??
          '';

      // Case-insensitive fallback: scan all loaded .env keys
      if (apiKey.isEmpty) {
        for (final entry in dotenv.env.entries) {
          final k = entry.key.toUpperCase();
          if (k == 'GROQ_API_TOKEN' ||
              k == 'GROQ_API_KEY' ||
              k == 'GROQ_TOKEN') {
            apiKey = entry.value;
            break;
          }
        }
      }
    }

    if (apiKey.isEmpty) {
      // Debug: show what keys ARE loaded so the user can spot the mismatch
      final loadedKeys = dotenv.env.keys.toList();
      print('╔══════════════════════════════════════════════════════════════');
      print('║ DARLA: No Groq API key found — using offline fallback.');
      print('║');
      print('║ Keys loaded from .env: $loadedKeys');
      print('║');
      print('║ Add this line to your .env file (case-sensitive):');
      print('║   GROQ_API_TOKEN=gsk_your_key_here');
      print('╚══════════════════════════════════════════════════════════════');
      return _getOfflineReply(message);
    }

    print('Darla: API key loaded (${apiKey.length} chars). Calling Groq...');

    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...history,
        {'role': 'user', 'content': message},
      ];

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              // Using llama-3.3-70b-versatile for better follow-up
              // understanding and natural conversation. Fast on Groq.
              'model': 'llama-3.3-70b-versatile',
              'messages': messages,
              'temperature': 0.7,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'];
        if (choices == null || choices.isEmpty) {
          print('Darla: Groq returned empty choices.');
          return _getOfflineReply(message);
        }
        final content = choices[0]['message']?['content'];
        if (content == null || (content as String).trim().isEmpty) {
          print('Darla: Groq returned empty content.');
          return _getOfflineReply(message);
        }
        return content.trim();
      } else if (response.statusCode == 429) {
        print('Darla: Rate limited by Groq API.');
        return "I'm getting a lot of requests right now. Please try again in a moment! 🙏";
      } else if (response.statusCode == 401) {
        print('Darla: Groq API authentication failed (401).');
        return _getOfflineReply(message);
      } else {
        // Log status but never expose API key or full response body
        // to avoid leaking secrets in debug output.
        print('Darla: Groq API error ${response.statusCode}.');
        return _getOfflineReply(message);
      }
    } on http.ClientException catch (e) {
      print('Darla: Network error — ${e.message}');
      return _getOfflineReply(message);
    } on FormatException {
      print('Darla: Failed to parse Groq response.');
      return _getOfflineReply(message);
    } catch (e) {
      // Catches TimeoutException and anything else unexpected.
      final type = e.runtimeType;
      print('Darla: Request failed ($type).');
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

    // ── 1. Greetings ────────────────────────────────────────────────
    if (_contains(text,
        ['hi', 'hello', 'hey', 'good morning', 'good evening', 'darla'])) {
      return "Hey 👋 I'm Darla — your TheyDi assistant.\n\nI can help with bookings, payments, QR tickets, Circles, Communities, verification, and more. What can I do for you?";
    }

    // ── 2. SPECIFIC SUPPORT TOPICS FIRST (before broad matches) ─────
    // These must come before the creative/event blocks so that
    // specific keywords like "ticket", "payment", "host payout",
    // "circle", "verify" are caught before broad words like
    // "create", "host", "title", "description" steal the match.

    // 2a. QR / Tickets / Check-in
    if (_contains(text, [
      'qr',
      'ticket',
      'check-in',
      'checkin',
      'check in',
      'entry pass',
      'scan',
      'booking confirmation',
    ])) {
      return "Your QR tickets and entry passes live in Profile → My Bookings. 🎟️\n\nOpen the booking for the Experience you're attending — your QR code will be there. The host scans it at check-in to confirm your entry.";
    }

    // 2b. Payments / Refunds / Payouts (matches T&C Section 11)
    if (_contains(text, [
      'payment',
      'pay',
      'refund',
      'payout',
      'razorpay',
      'upi',
      'transaction',
      'money',
      'charged',
      'deducted',
      'fee',
      'platform fee',
      'convenience fee',
      'kyc',
    ])) {
      return "Here's how payments, refunds & payouts work on TheyDi 💳\n\n"
          "• Attendee payments are processed via Razorpay (UPI, cards, netbanking, wallets).\n\n"
          "• Platform fee: ~10% (inclusive of taxes) deducted from host payouts. Payment gateway fee: ~2% charged by Razorpay.\n\n"
          "• Attendee cancellations before the Experience starts: 90% refund (10% cancellation fee). No refund for no-shows or cancellations after it starts.\n\n"
          "• Host/Org cancellations: allowed 24–48 hours before start. Attendees get a full 100% refund.\n\n"
          "• Approved refunds are processed within 7 days. Disputes must be raised within 7 days via in-app support or theydi.app@gmail.com.\n\n"
          "• Host payouts are credited within 7 days after the Experience completes. KYC (bank details) must be completed before payouts are released.\n\n"
          "• Payout = Total ticket sales − Platform fee (~10%) − Gateway fee (~2%) − Refunds issued.\n\n"
          "For payment issues, have your transaction ID ready and email theydi.app@gmail.com 📧";
    }

    // 2c. Verification
    if (_contains(text, ['verify', 'verification', 'verified', 'face'])) {
      return "To get verified, head to Profile, tap Get Verified, and complete Face Verification. An admin will review it and you'll get your verified badge once approved. ✅";
    }

    // 2d. Cancel Event/Experience
    if (_contains(text, ['cancel event', 'cancel my event', 'cancel experience']) ||
        (_contains(text, ['cancel']) && _contains(text, ['event', 'experience']))) {
      return "You can cancel an Experience from Profile → My Experiences. Open the Experience and choose Cancel Experience. Attendees are notified and eligible payments are refunded. 💳";
    }

    // 2e. Edit Event/Experience
    if (_contains(text, ['edit event', 'update event', 'change event', 'edit experience', 'update experience'])) {
      return "To edit an Experience, go to Profile → My Experiences, open it, and choose Edit Experience. 🎯";
    }

    // 2f. Circles
    if (_contains(text, ['circle', 'event circle'])) {
      return "A Circle is connected to a specific Experience. Only the Experience host can create it, and confirmed attendees can join it. If the host creates the Circle after you joined the Experience, you should receive a notification with an option to join. 🎉";
    }

    // 2g. Communities
    if (_contains(text, ['community', 'communities'])) {
      return "Communities are interest-based groups, separate from Experience Circles. People can create Communities around shared interests and chat with members there. 👥";
    }

    // 2h. Connections / Friends / DM
    if (_contains(text, ['connection', 'connections', 'friend', 'friends', 'dm', 'direct message'])) {
      return "Connections are your individual peer/friend connections. You can connect with people and message your connections directly. 💬";
    }

    // 2i. Booking
    if (_contains(text, ['book', 'booking', 'request to join', 'join event', 'join experience', 'attend'])) {
      return "To book an Experience, open it and tap Book (instant) or Request to Join (host approval needed). 🎫\n\nPaid Experiences route through Razorpay at checkout. You can check your bookings in Profile → My Bookings.";
    }

    // 2j. Safety / Reporting
    if (_contains(text, [
      'report',
      'fake',
      'abuse',
      'spam',
      'harass',
      'block',
      'safe',
      'guideline',
      'unsafe',
    ])) {
      return "If someone's causing trouble, open their profile, tap the ⋮ menu, and choose Report or Block. Our moderation team reviews every report. 🔒\n\nIf you feel unsafe, leave immediately and call 112 for emergencies in India.";
    }

    // 2k. Account / Settings / Profile
    if (_contains(text, [
      'delete account',
      'login',
      'log in',
      'password',
      'setting',
      'notification',
    ])) {
      return "Profile, password, notifications, and location preferences can all be managed from Settings. For account deletion, go to Settings → Delete Account. ⚙️";
    }

    // 2l. Privacy / Terms
    if (_contains(text, ['privacy', 'policy', 'terms'])) {
      return "You can find the Privacy Policy and Terms under Settings > Privacy & Safety. 🔒";
    }

    // 2m. Support / Contact
    if (_contains(text, ['support', 'contact', 'email', 'complaint'])) {
      return "For anything I can't sort out, the TheyDi support team is reachable through Help & Support inside the app, or email theydi.app@gmail.com. 📧";
    }

    // 2n. Social vs Professional Experiences
    if (_contains(text, [
      'social experience',
      'social experiences',
      'professional experience',
      'professional experiences',
    ])) {
      final isProfessional = _contains(text, ['professional']);
      if (isProfessional) {
        return "Professional Experiences are the work-related side of TheyDi — hackathons, company events, workshops, and networking meetups. 💼\nThey work just like any other Experience — I can help you create one or find one nearby, just say the word.";
      }
      return "Social Experiences are the recreational side of TheyDi — house parties, dinners, hikes, meetups, and similar hangouts. 🎉\nThey work just like any other Experience — I can help you create one or find one nearby, just let me know.";
    }

    // 2o. Location / Nearby / Discover
    if (_contains(text, ['nearby', 'near me', 'discover', 'find experience', 'find event', 'explore', 'location'])) {
      return "TheyDi shows Experiences near you based on your GPS location. 📍\n\nThe Home screen sorts by distance, and you can switch between Nearest, Popular, Upcoming, and Newest. You can also adjust the radius filter to see Experiences further away.";
    }

    // ── 3. BROAD MATCHES (after specific support topics) ────────────

    // 3a. General "how to create/host an Experience" — broad match
    // Excludes 'host' alone (which could mean "host payouts") by
    // requiring it with 'experience' or 'event', or matching the
    // other specific words.
    if (_contains(text, ['create an experience', 'create an event', 'create experience', 'create event', 'hosting an experience', 'hosting an event', 'how to host']) ||
        (_contains(text, ['host']) && _contains(text, ['experience', 'event']))) {
      return "Creating an Experience is simple — from Home, tap Create Experience, fill in the details, add some photos, and publish. 🎉\n\nIt'll show up to users nearby, and you can edit or cancel it later from your profile.";
    }

    // ── 4. Catch-all ────────────────────────────────────────────────
    return "I can help you with TheyDi — bookings, payments, refunds, QR tickets, Circles, Communities, Connections, verification, and more. 💬\n\nJust ask your question and I'll do my best to help!";
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
        "How do I create an Experience?",
        "How do QR tickets work?",
        "How do payments and refunds work?",
        "What's the difference between Circles and Communities?",
        "How do I get verified?",
        "How do I host an Experience?",
      ];
}