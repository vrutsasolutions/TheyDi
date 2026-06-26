import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../events/models/event_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<EventModel> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  static const List<String> _recentSearches = [
    'Music',
    'Tech meetup',
    'Free events',
    'Party',
    'Networking',
  ];

  static const List<Map<String, dynamic>> _trendingCategories = [
    {'label': 'Music', 'icon': Icons.music_note, 'color': Colors.purple},
    {'label': 'Tech', 'icon': Icons.computer, 'color': Colors.blue},
    {'label': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'label': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.green},
    {'label': 'Art', 'icon': Icons.palette, 'color': Colors.pink},
    {'label': 'Party', 'icon': Icons.nightlife, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Debounce 500ms — waits for user to stop typing
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      // Firestore doesn't support full-text search natively,
      // so we fetch all upcoming events and filter client-side.
      // For production, consider Algolia or Typesense.
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('dateTime',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('dateTime')
          .limit(100)
          .get();

      final allEvents = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      final queryLower = query.toLowerCase();
      final filtered = allEvents.where((e) {
        return e.title.toLowerCase().contains(queryLower) ||
            e.category.toLowerCase().contains(queryLower) ||
            e.venue.toLowerCase().contains(queryLower) ||
            e.city.toLowerCase().contains(queryLower) ||
            e.description.toLowerCase().contains(queryLower);
      }).toList();

      if (mounted) {
        setState(() {
          _results = filtered;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  void _searchFor(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [TheyDiColors.cardLight, TheyDiColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: TheyDiColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: TheyDiColors.divider),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: TheyDiTextStyles.bodyMedium,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText:
                                'Search events, categories, cities...',
                            hintStyle: TheyDiTextStyles.bodySmall
                                .copyWith(
                                    color: TheyDiColors.textMuted),
                            prefixIcon: const Icon(Icons.search,
                                color: TheyDiColors.textMuted,
                                size: 20),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color:
                                                TheyDiColors.textMuted,
                                            size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          _onSearchChanged('');
                                        },
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 12),

              // Content
              Expanded(
                child: _isSearching
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary),
                      )
                    : _hasSearched
                        ? _buildResults()
                        : _buildSuggestions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Before searching — show suggestions
  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Trending categories
        Text('Trending categories',
                style: TheyDiTextStyles.labelLarge)
            .animate(delay: 100.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _trendingCategories.map((cat) {
            return GestureDetector(
              onTap: () => _searchFor(cat['label'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: TheyDiColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TheyDiColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat['icon'] as IconData,
                        size: 18,
                        color: cat['color'] as Color),
                    const SizedBox(width: 8),
                    Text(cat['label'] as String,
                        style: TheyDiTextStyles.labelMedium),
                  ],
                ),
              ),
            );
          }).toList(),
        ).animate(delay: 150.ms).fade(duration: 400.ms),

        const SizedBox(height: 28),

        // Recent searches
        Text('Popular searches',
                style: TheyDiTextStyles.labelLarge)
            .animate(delay: 200.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 12),

        ...List.generate(_recentSearches.length, (index) {
          final search = _recentSearches[index];
          return GestureDetector(
            onTap: () => _searchFor(search),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TheyDiColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TheyDiColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up,
                      size: 16, color: TheyDiColors.textMuted),
                  const SizedBox(width: 10),
                  Text(search, style: TheyDiTextStyles.bodySmall),
                  const Spacer(),
                  Icon(Icons.north_west,
                      size: 14, color: TheyDiColors.textMuted),
                ],
              ),
            ),
          )
              .animate(
                delay: Duration(milliseconds: 250 + 40 * index),
              )
              .fade(duration: 300.ms);
        }),
      ],
    );
  }

  // After searching — show results
  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('No events found',
                style: TheyDiTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or browse categories',
              style: TheyDiTextStyles.bodySmall
                  .copyWith(color: TheyDiColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${_results.length} result${_results.length == 1 ? '' : 's'}',
            style: TheyDiTextStyles.labelMedium
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final event = _results[index];
              return _SearchResultCard(event: event)
                  .animate(
                    delay: Duration(milliseconds: 50 * index),
                  )
                  .fade(duration: 300.ms)
                  .slideY(begin: 0.08, end: 0);
            },
          ),
        ),
      ],
    );
  }
}

// ── Search Result Card ──
class _SearchResultCard extends StatelessWidget {
  final EventModel event;
  const _SearchResultCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  event.category.isNotEmpty
                      ? event.category[0]
                      : 'E',
                  style: TheyDiTextStyles.displayMedium
                      .copyWith(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TheyDiTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TheyDiTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: TheyDiColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.venue}, ${event.city}',
                          style: TheyDiTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Price badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: event.isFree
                    ? Colors.green.withValues(alpha: 0.15)
                    : TheyDiColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                style: TheyDiTextStyles.caption.copyWith(
                  color: event.isFree
                      ? Colors.green
                      : TheyDiColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
