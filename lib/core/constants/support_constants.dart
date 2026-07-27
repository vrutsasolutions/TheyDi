class SupportConstants {
  SupportConstants._();

  static const List<Map<String, String>> faqs = [
    {
      'q': 'How do I create an event?',
      'a':
          'Go to the My Events tab and tap the + button at the bottom. Fill in your event details like title, description, venue, date, and pricing. Tap "Create Event" to publish it.',
    },
    {
      'q': 'How do I join an event?',
      'a':
          'Browse events on the Home or Explore tab. Tap on an event to see details, then tap "Join" at the bottom. Free events are instant, paid events will take you through checkout.',
    },
    {
      'q': 'Can I cancel my RSVP?',
      'a':
          'Yes! Open the event you joined and tap the "Joined — Tap to Cancel" button. For paid events, refund requests will be processed within 3-5 business days.',
    },
    {
      'q': 'How do payments work?',
      'a':
          'For paid events, you\'ll see a checkout screen with the event price plus a 5% platform fee. We support UPI, credit/debit cards, and net banking. All transactions are secured.',
    },
    {
      'q': 'How do I edit my profile?',
      'a':
          'Go to the Profile tab and tap "Edit Profile". You can change your display name, bio, city, and interests. Changes are saved instantly.',
    },
    {
      'q': 'How do I change my city?',
      'a':
          'Go to Profile → Edit Profile → change the city dropdown. The Home feed will automatically show events in your new city.',
    },
    {
      'q': 'Is my data safe?',
      'a':
          'Yes. We use Firebase Authentication for secure login, and all data is stored in Google Cloud Firestore with encryption. You can control your privacy settings under Privacy & Safety.',
    },
    {
      'q': 'How do I delete my account?',
      'a':
          'Go to Profile → Privacy & Safety → scroll to the bottom and tap "Delete Account". This action is permanent and all your data will be removed.',
    },
  ];

  static const List<String> reportTypes = [
    'Technical Bug',
    'Inappropriate Behavior',
    'Spam',
    'Payment Issue',
    'Other',
  ];
}
