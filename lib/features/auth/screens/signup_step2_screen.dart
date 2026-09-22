import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/location_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

class SignupStep2Screen extends StatefulWidget {
  final SignupData signupData;
  const SignupStep2Screen({super.key, required this.signupData});

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final _searchController = TextEditingController();
  String _selectedCity = '';
  List<String> _filtered = LocationConstants.primaryCities;
  List<String> _filteredOtherCities = LocationConstants.otherCities;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = LocationConstants.primaryCities;
        _filteredOtherCities = LocationConstants.otherCities;
      } else {
        _filtered = LocationConstants.primaryCities
            .where(
              (city) => city.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

        _filteredOtherCities = LocationConstants.otherCities
            .where(
              (city) => city.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  // ── City visual — real photo if available, icon as automatic fallback ──
  // Drop a photo at assets/images/cities/<slug>.jpg (slug = lowercase, spaces
  // → underscores, e.g. "New Delhi" → new_delhi.jpg) and it's picked up
  // automatically — no code changes needed. Until then, the existing icon
  // from LocationConstants.cityIcons is shown.
  //
  // Supported formats: .jpg (preferred), .jpeg, .png
  String _citySlug(String city) =>
      city.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  /// Returns true if a city has a photo in assets/images/cities/
  bool _cityHasPhoto(String city) =>
      _cityPhotoChecked.putIfAbsent(city, () => true);
  final Map<String, bool> _cityPhotoChecked = {};

  void _markNoPhoto(String city) => _cityPhotoChecked[city] = false;

  /// Full-card photo background (used by the grid card builder).
  /// Shows the photo covering the entire card with a gradient overlay
  /// and city name at the bottom. Falls back to the old icon-centered
  /// layout when no photo exists for this city.
  Widget _buildCityCardContent(String city, bool isSelected) {
    final iconPath = LocationConstants.cityIcons[city];
    final slug = _citySlug(city);
    final hasPhoto = _cityHasPhoto(city);

    // ── Photo card ──
    if (hasPhoto) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Try .jpg first; on error try .png; on error fall back to icon layout
          Image.asset(
            'assets/images/cities/$slug.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Image.asset(
                'assets/images/cities/$slug.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  // Mark so next rebuild skips straight to icon layout
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _markNoPhoto(city);
                      setState(() {});
                    }
                  });
                  return _buildIconFallback(iconPath, city, isSelected);
                },
              );
            },
          ),
          // Gradient overlay so text is readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.65),
                ],
                stops: const [0.35, 1.0],
              ),
            ),
          ),
          // Green tint when selected
          if (isSelected)
            Container(
              color: TheyDiColors.primary.withOpacity(0.35),
            ),
          // City name at bottom
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              city,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Checkmark when selected
          if (isSelected)
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: Icon(Icons.check, size: 16, color: Color(0xFF12B76A)),
              ),
            ),
        ],
      );
    }

    // ── Icon fallback (no photo) ──
    return _buildIconFallback(iconPath, city, isSelected);
  }

  /// Icon-centered fallback layout (same as the original design).
  Widget _buildIconFallback(String? iconPath, String city, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(iconPath, width: 55, height: 55, fit: BoxFit.contain),
            )
          else
            Icon(Icons.location_city, size: 44,
                color: isSelected ? Colors.white70 : TheyDiColors.textMuted),
          const SizedBox(height: 10),
          Text(
            city,
            textAlign: TextAlign.center,
            style: TheyDiTextStyles.labelMedium.copyWith(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onCityTap(String city) {
    setState(() => _selectedCity = city);
    widget.signupData.city = city;
    context.push(AppRoutes.signupStep3, extra: widget.signupData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(TheyDiColors.cardLight, TheyDiColors.accent, 0.4)!,
            TheyDiColors.cardLight,
            TheyDiColors.surface,
          ],
          stops: const [0.0, 0.4, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: TheyDiColors.textPrimary,
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: SignupProgressBar(step: 2, totalSteps: 5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pick your city',
                            style: TheyDiTextStyles.displayMedium)
                        .animate()
                        .fade(duration: 400.ms),
                    const SizedBox(height: 6),
                    Text('Step 2 of 5 — Where do you hang out?',
                            style: TheyDiTextStyles.bodySmall)
                        .animate(delay: 80.ms)
                        .fade(duration: 300.ms),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearch,
                        style: TheyDiTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: TheyDiColors.cardLight,
                          hintText: 'Search city...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: TheyDiColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ).animate(delay: 150.ms).fade(duration: 300.ms),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Popular Cities
                      Text(
                        "Popular Cities",
                        style: TheyDiTextStyles.displayMedium.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ///
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final city = _filtered[index];
                          final isSelected = city == _selectedCity;

                          final hasPhoto = _cityHasPhoto(city);

                          return GestureDetector(
                            onTap: () => _onCityTap(city),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                // Only apply gradient/color when no photo
                                gradient: (!hasPhoto && isSelected)
                                    ? TheyDiColors.gradientPrimary
                                    : null,
                                color: (!hasPhoto && !isSelected)
                                    ? TheyDiColors.card
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF12B76A)
                                      : TheyDiColors.divider,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? TheyDiColors.primary
                                            .withOpacity(0.25)
                                        : Colors.black.withOpacity(0.06),
                                    blurRadius: isSelected ? 14 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _buildCityCardContent(city, isSelected),
                            ),
                          )
                              .animate(
                                  delay: Duration(milliseconds: 20 * index))
                              .fade(duration: 250.ms)
                              .scale();
                        },
                      ),

                      const SizedBox(height: 28),

                      Text(
                        "Other Cities",
                        style: TheyDiTextStyles.labelMedium.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredOtherCities.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final city = _filteredOtherCities[index];

                          return InkWell(
                            onTap: () => _onCityTap(city),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 4),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFEAEAEA),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 16, color: TheyDiColors.textMuted),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      city,
                                      style: TheyDiTextStyles.bodyMedium,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      size: 18, color: TheyDiColors.textMuted),
                                ],
                              ),
                            ),
                          )
                              .animate(
                                  delay: Duration(milliseconds: 15 * index))
                              .fade(duration: 200.ms);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}