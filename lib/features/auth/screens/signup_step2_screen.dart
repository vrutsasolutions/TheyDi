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

  // ── NEW: city visual — real photo if available, icon as automatic fallback ──
  // Drop a photo at assets/images/cities/<slug>.jpg (slug = lowercase, spaces
  // → underscores, e.g. "New Delhi" → new_delhi.jpg) and it's picked up
  // automatically — no code changes needed. Until then, the existing icon
  // from LocationConstants.cityIcons is shown.
  String _citySlug(String city) =>
      city.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  Widget _buildCityVisual(String city) {
    final iconPath = LocationConstants.cityIcons[city];
    final photoPath = 'assets/images/cities/${_citySlug(city)}.jpg';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        photoPath,
        width: 55,
        height: 55,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // No photo yet for this city — fall back to the icon.
          if (iconPath == null) return const SizedBox(width: 55, height: 55);
          return Image.asset(iconPath, width: 55, height: 55, fit: BoxFit.contain);
        },
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
            TheyDiColors.accent.withOpacity(0.4),
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

                          return GestureDetector(
                            onTap: () => _onCityTap(city),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? TheyDiColors.gradientPrimary
                                    : null,
                                color: isSelected ? null : TheyDiColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : TheyDiColors.divider,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? TheyDiColors.primary
                                            .withOpacity(0.25)
                                        : Colors.black.withOpacity(0.04),
                                    blurRadius: isSelected ? 14 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildCityVisual(city),
                                      const SizedBox(height: 12),
                                      Text(
                                        city,
                                        textAlign: TextAlign.center,
                                        style: TheyDiTextStyles.labelMedium
                                            .copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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