import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/signup_progress_bar.dart';
import '../models/signup_data.dart';

const _kCities = [
  'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
  'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow',
  'Kochi', 'Goa', 'Surat', 'Chandigarh', 'Indore',
  'Bhopal', 'Nagpur', 'Visakhapatnam', 'Coimbatore', 'Vadodara',
];

class SignupStep2Screen extends StatefulWidget {
  final SignupData signupData;
  const SignupStep2Screen({super.key, required this.signupData});

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final _searchController = TextEditingController();
  String _selectedCity = '';
  List<String> _filtered = _kCities;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _kCities
          : _kCities
              .where((c) => c.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void _onCityTap(String city) {
    setState(() => _selectedCity = city);
    widget.signupData.city = city;
    context.push(AppRoutes.signupStep3, extra: widget.signupData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TheyDiColors.cardLight, TheyDiColors.surface],
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

                    TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      style: TheyDiTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search city...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: TheyDiColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: TheyDiColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: TheyDiColors.primary, width: 1.5),
                        ),
                      ),
                    ).animate(delay: 150.ms).fade(duration: 300.ms),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No cities found',
                            style: TheyDiTextStyles.bodySmall),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.6,
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
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_city_outlined,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : TheyDiColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(city,
                                        style: TheyDiTextStyles.labelMedium
                                            .copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : TheyDiColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          )
                              .animate(
                                  delay: Duration(milliseconds: 20 * index))
                              .fade(duration: 250.ms)
                              .scale(
                                  begin: const Offset(0.9, 0.9),
                                  end: const Offset(1, 1));
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
