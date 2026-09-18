class EventConstants {
  EventConstants._();

  // ── Social interests/categories ───────────────────────────────────────────
  static const List<String> socialCategories = [
    'Music', 'Food', 'Gaming', 'Fitness', 'Comedy', 'Party',
    'Sports', 'Art', 'Travel', 'Photography', 'Dance', 'Movies',
    'Yoga', 'Cooking', 'Hiking', 'DIY & Crafts', 'Pets',
    'Nature', 'Nightlife', 'Board Games', 'Social', 'Other',
  ];

  // ── Professional interests/categories ────────────────────────────────────
  static const List<String> professionalCategories = [
    'Tech', 'Networking', 'Workshop', 'Hackathon', 'Conference',
    'Startup', 'Career', 'Design', 'Marketing', 'Finance',
    'Healthcare', 'Education', 'AI', 'Leadership', 'Sales',
    'Product Management', 'Data Science', 'Cybersecurity',
    'Blockchain', 'Content Creation', 'E-commerce', 'Other',
  ];

  // ── All interests combined — for signup step 3 & create community ─────────
  // Both lists merged; user can pick multiple regardless of tab.
  static const List<String> allInterests = [
    // Social
    'Music', 'Food', 'Gaming', 'Fitness', 'Comedy', 'Party',
    'Sports', 'Art', 'Travel', 'Photography', 'Dance', 'Movies',
    'Yoga', 'Cooking', 'Hiking', 'DIY & Crafts', 'Pets',
    'Nature', 'Nightlife', 'Board Games',
    // Professional
    'Tech', 'Networking', 'Workshop', 'Hackathon', 'Conference',
    'Startup', 'Career', 'Design', 'Marketing', 'Finance',
    'Healthcare', 'Education', 'AI', 'Leadership', 'Sales',
    'Product Management', 'Data Science', 'Cybersecurity',
    'Blockchain', 'Content Creation', 'E-commerce',
  ];

  // ── Legacy flat list — kept for backward compat ───────────────────────────
  static const List<String> eventCategories = [
    'Music', 'Tech', 'Sports', 'Art', 'Food', 'Networking',
    'Gaming', 'Fitness', 'Comedy', 'Workshop', 'Party', 'Social', 'Other',
  ];

  static const List<String> adultAgeGroups = [
    'Young Adults (18–25)',
    'Adults (26–40)',
    'Middle Age (41–60)',
    'Seniors (60+)',
  ];

  static const List<String> homeCategories = [
    'All', 'Music', 'Tech', 'Sports', 'Art', 'Food', 'Networking',
    'Gaming', 'Fitness', 'Comedy', 'Workshop', 'Party', 'Social', 'Other',
  ];

  static const List<String> exploreFilters = [
    'All', 'Today', 'Free', 'This Week',
  ];
}