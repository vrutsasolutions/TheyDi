class AppConstants {
  AppConstants._();

  static const String baseUrl = 'https://api.theydi.app/v1';
  static const String localUrl = 'http://10.0.2.2:3000/v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int defaultPageSize = 20;
  static const double defaultRadiusKm = 10.0;
  static const double maxRadiusKm = 50.0;
  static const double minRadiusKm = 1.0;

  static const int maxGuestsLimit = 500;
  static const int minGuestsLimit = 2;
  static const int minAgeAdult = 18;

  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyOnboardingDone = 'onboarding_done';

  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(seconds: 2);

  static final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');
  static final passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$');

  static const String appName = 'TheyDi';
  static const String appTagline = 'Find your next gathering';
  static const String supportEmail = 'support@theydi.app';

  static const double platformFeePercent = 7.5;
}

enum EventCategory {
  house('House Party', '🏠'),
  rooftop('Rooftop', '🌇'),
  brunch('Brunch', '☕'),
  networking('Networking', '🤝'),
  gaming('Gaming', '🎮'),
  fitness('Fitness', '🏋️'),
  art('Art & Culture', '🎨'),
  music('Music', '🎵'),
  food('Food & Drinks', '🍜'),
  outdoor('Outdoor', '🌿'),
  workshop('Workshop', '🛠️'),
  sports('Sports', '⚽'),
  other('Other', '✨');

  const EventCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum BookingStatus {
  pending,
  approved,
  rejected,
  confirmed,
  cancelled,
  completed,
}
