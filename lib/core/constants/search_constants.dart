import 'package:flutter/material.dart';

class SearchConstants {
  SearchConstants._();

  static const List<String> recentSearches = [
    'Music',
    'Tech meetup',
    'Free events',
    'Party',
    'Networking',
  ];

  static const List<Map<String, dynamic>> trendingCategories = [
    {'label': 'Music', 'icon': Icons.music_note, 'color': Colors.purple},
    {'label': 'Tech', 'icon': Icons.computer, 'color': Colors.blue},
    {'label': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'label': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.green},
    {'label': 'Art', 'icon': Icons.palette, 'color': Colors.pink},
    {'label': 'Party', 'icon': Icons.nightlife, 'color': Colors.red},
  ];
}
