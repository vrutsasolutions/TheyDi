class EventConstants {
  EventConstants._();

  static const List<String> eventCategories = [
    'Music',
    'Tech',
    'Sports',
    'Art',
    'Food',
    'Networking',
    'Gaming',
    'Fitness',
    'Comedy',
    'Workshop',
    'Party',
    'Social',
    'Other',
  ];

  // New: category options scoped to the Purpose selector on Create
  // Experience (Social vs Professional), plus 'Other' in both so a host
  // can free-type something not listed. This is a subset/regrouping of
  // eventCategories above, not a replacement for it — eventCategories is
  // still used for the Home feed's category chips.
  static const List<String> socialEventCategories = [
    'Party',
    'Social',
    'Music',
    'Food',
    'Fitness',
    'Gaming',
    'Art',
    'Comedy',
    'Other',
  ];

  static const List<String> professionalEventCategories = [
    'Tech',
    'Business',
    'AI',
    'Startups',
    'Networking',
    'Workshop',
    'Other',
  ];

  static const List<String> adultAgeGroups = [
    'Young Adults (18–25)',
    'Adults (26–40)',
    'Middle Age (41–60)',
    'Seniors (60+)',
  ];

  static const List<String> homeCategories = [
    'All',
    'Music',
    'Tech',
    'Sports',
    'Art',
    'Food',
    'Networking',
    'Gaming',
    'Fitness',
    'Comedy',
    'Workshop',
    'Party',
    'Social',

    'Other',
  ];

  static const List<String> exploreFilters = [
    'All',
    'Today',
    'Free',
    'This Week',
  ];
}