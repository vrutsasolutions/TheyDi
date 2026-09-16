import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/search_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_routes.dart';
import '../../events/models/event_model.dart';
import '../../inbox/community/models/community_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen — searches Events, Communities, and People simultaneously.
// "event" renamed to "experience" in all UI display text.
// Responsive: no fixed heights that cause overflow on narrow screens.
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  // Results per category
  List<EventModel> _eventResults = [];
  List<CommunityModel> _communityResults = [];
  List<Map<String, dynamic>> _peopleResults = [];

  bool _isSearching = false;
  bool _hasSearched = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _eventResults = [];
        _communityResults = [];
        _peopleResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final queryLower = query.toLowerCase();
    try {
      // Run all three queries in parallel
      final results = await Future.wait([
        _searchEvents(queryLower),
        _searchCommunities(queryLower),
        _searchPeople(queryLower),
      ]);

      if (mounted) {
        setState(() {
          _eventResults = results[0] as List<EventModel>;
          _communityResults = results[1] as List<CommunityModel>;
          _peopleResults = results[2] as List<Map<String, dynamic>>;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  Future<List<EventModel>> _searchEvents(String queryLower) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('dateTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('dateTime')
        .limit(100)
        .get();

    final all = snapshot.docs.map((d) => EventModel.fromFirestore(d)).toList();
    return all.where((e) {
      return e.title.toLowerCase().contains(queryLower) ||
          e.category.toLowerCase().contains(queryLower) ||
          e.venue.toLowerCase().contains(queryLower) ||
          e.city.toLowerCase().contains(queryLower) ||
          e.description.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<List<CommunityModel>> _searchCommunities(String queryLower) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('communities')
        .limit(100)
        .get();

    final all =
        snapshot.docs.map((d) => CommunityModel.fromFirestore(d)).toList();
    return all.where((c) {
      return c.name.toLowerCase().contains(queryLower) ||
          c.description.toLowerCase().contains(queryLower) ||
          c.category.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _searchPeople(String queryLower) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(100)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      if (doc.id == myUid) continue;
      final data = doc.data();
      final name = ((data['displayName'] as String?) ?? '').toLowerCase();
      final username = ((data['username'] as String?) ?? '').toLowerCase();
      final interests = (data['interests'] as List<dynamic>? ?? [])
          .map((i) => i.toString().toLowerCase())
          .toList();
      final city = ((data['city'] as String?) ?? '').toLowerCase();

      if (name.contains(queryLower) ||
          username.contains(queryLower) ||
          city.contains(queryLower) ||
          interests.any((i) => i.contains(queryLower))) {
        results.add({'uid': doc.id, ...data});
      }
    }
    return results;
  }

  void _searchFor(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  int get _totalResults =>
      _eventResults.length + _communityResults.length + _peopleResults.length;

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
              // ── Search bar ──────────────────────────────────────────────────
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
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: TheyDiColors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: TheyDiTextStyles.bodyMedium,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Experiences, communities, people...',
                            hintStyle: TheyDiTextStyles.bodySmall
                                .copyWith(color: TheyDiColors.textMuted),
                            prefixIcon: const Icon(Icons.search,
                                color: TheyDiColors.textMuted, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: TheyDiColors.textMuted, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 12),

              // ── Content ─────────────────────────────────────────────────────
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

  // ── Suggestions ─────────────────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text('Trending categories', style: TheyDiTextStyles.labelLarge)
            .animate(delay: 100.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 12),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SearchConstants.trendingCategories.map((cat) {
            return GestureDetector(
              onTap: () => _searchFor(cat['label'] as String),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: TheyDiColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TheyDiColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat['icon'] as IconData,
                        size: 18, color: cat['color'] as Color),
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

        Text('Popular searches', style: TheyDiTextStyles.labelLarge)
            .animate(delay: 200.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 12),

        ...List.generate(SearchConstants.recentSearches.length, (index) {
          final search = SearchConstants.recentSearches[index];
          return GestureDetector(
            onTap: () => _searchFor(search),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TheyDiColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TheyDiColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up,
                      size: 16, color: TheyDiColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(search, style: TheyDiTextStyles.bodySmall),
                  ),
                  const Icon(Icons.north_west,
                      size: 14, color: TheyDiColors.textMuted),
                ],
              ),
            ),
          )
              .animate(delay: Duration(milliseconds: 250 + 40 * index))
              .fade(duration: 300.ms);
        }),
      ],
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────
  Widget _buildResults() {
    if (_totalResults == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text('Nothing found', style: TheyDiTextStyles.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Try different keywords or browse categories',
                style: TheyDiTextStyles.bodySmall
                    .copyWith(color: TheyDiColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tabs ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            controller: _tabController,
            indicatorColor: TheyDiColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: TheyDiColors.primary,
            unselectedLabelColor: TheyDiColors.textSecondary,
            labelStyle: TheyDiTextStyles.labelMedium,
            tabs: [
              Tab(
                  text: 'Experiences${_eventResults.isNotEmpty ? ' (${_eventResults.length})' : ''}'),
              Tab(
                  text: 'Communities${_communityResults.isNotEmpty ? ' (${_communityResults.length})' : ''}'),
              Tab(
                  text: 'People${_peopleResults.isNotEmpty ? ' (${_peopleResults.length})' : ''}'),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ExperienceResultsList(results: _eventResults),
              _CommunityResultsList(results: _communityResults),
              _PeopleResultsList(results: _peopleResults),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Experience Results ─────────────────────────────────────────────────────────
class _ExperienceResultsList extends StatelessWidget {
  final List<EventModel> results;
  const _ExperienceResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptyTab(
          icon: Icons.event_outlined, message: 'No experiences found');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _ExperienceResultCard(event: results[index])
            .animate(delay: Duration(milliseconds: 50 * index))
            .fade(duration: 300.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

class _ExperienceResultCard extends StatelessWidget {
  final EventModel event;
  const _ExperienceResultCard({required this.event});

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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TheyDiColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  event.category.isNotEmpty ? event.category[0] : 'E',
                  style: TheyDiTextStyles.displayMedium
                      .copyWith(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TheyDiTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(dateStr,
                            style: TheyDiTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: TheyDiColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${event.venue}, ${event.city}',
                        style: TheyDiTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: event.isFree
                    ? Colors.green.withValues(alpha: 0.15)
                    : TheyDiColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                style: TheyDiTextStyles.caption.copyWith(
                  color: event.isFree ? Colors.green : TheyDiColors.primary,
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

// ── Community Results ─────────────────────────────────────────────────────────
class _CommunityResultsList extends StatelessWidget {
  final List<CommunityModel> results;
  const _CommunityResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptyTab(
          icon: Icons.diversity_3_outlined, message: 'No communities found');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final c = results[index];
        return GestureDetector(
          onTap: () => context.push(AppRoutes.communityChat, extra: c),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TheyDiColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: (c.coverImageUrl?.isNotEmpty ?? false)
                        ? Image.network(c.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                child: Text(c.initials,
                                    style: TheyDiTextStyles.labelMedium
                                        .copyWith(color: Colors.white))))
                        : Center(
                            child: Text(c.initials,
                                style: TheyDiTextStyles.labelMedium
                                    .copyWith(color: Colors.white))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: TheyDiTextStyles.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(c.category,
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.primary)),
                      Text(
                          '${c.memberCount} member${c.memberCount == 1 ? '' : 's'}',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: TheyDiColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: TheyDiColors.textMuted, size: 20),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: 50 * index))
              .fade(duration: 300.ms)
              .slideY(begin: 0.08, end: 0),
        );
      },
    );
  }
}

// ── People Results ────────────────────────────────────────────────────────────
class _PeopleResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  const _PeopleResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptyTab(
          icon: Icons.person_search_outlined, message: 'No people found');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final person = results[index];
        final name = (person['displayName'] as String?) ?? 'User';
        final username = (person['username'] as String?) ?? '';
        final city = (person['city'] as String?) ?? '';
        final uid = person['uid'] as String? ?? '';
        final interests = (person['interests'] as List<dynamic>? ?? [])
            .map((i) => i.toString())
            .take(3)
            .toList();
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return GestureDetector(
          onTap: () =>
              context.push(AppRoutes.userProfile, extra: {'uid': uid}),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TheyDiColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TheyDiColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: TheyDiTextStyles.labelLarge
                            .copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TheyDiTextStyles.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (username.isNotEmpty)
                        Text('@$username',
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.primary)),
                      if (city.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: TheyDiColors.textMuted),
                          const SizedBox(width: 2),
                          Text(city, style: TheyDiTextStyles.caption),
                        ]),
                      if (interests.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: interests
                              .map((i) => Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: TheyDiColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(i,
                                        style: TheyDiTextStyles.caption
                                            .copyWith(
                                                color: TheyDiColors.primary,
                                                fontSize: 10)),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: TheyDiColors.textMuted, size: 20),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: 50 * index))
              .fade(duration: 300.ms)
              .slideY(begin: 0.08, end: 0),
        );
      },
    );
  }
}

// ── Empty tab placeholder ─────────────────────────────────────────────────────
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(message,
              style: TheyDiTextStyles.bodySmall
                  .copyWith(color: TheyDiColors.textSecondary)),
        ],
      ),
    );
  }
}