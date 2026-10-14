import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared image URLs — Unsplash (free, public, reliable)
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingImages {
  // Social / party gathering
  static const String socialEvent =
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=600&h=400&fit=crop&q=80';
  // Networking / conference
  static const String networking =
      'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=600&h=400&fit=crop&q=80';
  // Community / group of friends
  static const String community =
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=600&h=400&fit=crop&q=80';
  // Professional / business meetup
  static const String professional =
      'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=600&h=400&fit=crop&q=80';
  // Coffee / creative meetup
  static const String coffeeMeetup =
      'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=300&h=200&fit=crop&q=80';
  // Workshop / speaker event
  static const String workshop =
      'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?w=300&h=200&fit=crop&q=80';
  // Party / celebration
  static const String partyEvent =
      'https://images.unsplash.com/photo-1496024840928-4c417adf211d?w=300&h=200&fit=crop&q=80';
  // Teamwork / collaboration
  static const String teamwork =
      'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=300&h=200&fit=crop&q=80';
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Discover Experiences Near You
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8FFF3), Color(0xFFF0FDF7), Colors.white],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 700;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, isCompact ? 12 : 20, 24, 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    'Discover',
                    style: GoogleFonts.inter(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: TheyDiColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        TheyDiColors.gradientPrimary.createShader(bounds),
                    child: Text(
                      'Experiences',
                      style: GoogleFonts.inter(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    'Near You',
                    style: GoogleFonts.inter(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: TheyDiColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore events, meet people,\nand be part of something amazing.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: TheyDiColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Hero image card (like Figma reference) ──
                  _HeroEventCard(
                    imageUrl: _OnboardingImages.socialEvent,
                    badgeText: 'Happening near you',
                    title: 'Sunset Social',
                    subtitle: 'Riverside Park · 1.2 km',
                    gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                  ),

                  const SizedBox(height: 14),

                  // Two smaller side-by-side event cards with images
                  Row(
                    children: [
                      Expanded(
                        child: _SmallEventCard(
                          imageUrl: _OnboardingImages.coffeeMeetup,
                          label: 'Creative',
                          title: 'Clay & Coffee',
                          time: 'Sat, 4:30 PM',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallEventCard(
                          imageUrl: _OnboardingImages.workshop,
                          label: 'Professional',
                          title: 'Founders Mixer',
                          time: 'The Atrium',
                          hasBookButton: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bottom categories row
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryChip(
                          icon: Icons.people_alt_rounded,
                          iconColor: TheyDiColors.primary,
                          label: 'Social',
                          desc: 'Parties, meetups,\nhobbies and more.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryChip(
                          icon: Icons.work_outline_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: 'Professional',
                          desc: 'Workshops, hackathons,\nnetworking and more.',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Good vibes · Real people · New connections',
                      style: GoogleFonts.caveat(
                        fontSize: 16,
                        color: TheyDiColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — More Experiences. Less Scrolling.
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDF7), Color(0xFFFAFDFC), Colors.white],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Title
              Text(
                'More',
                style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: TheyDiColors.textPrimary,
                  height: 1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) =>
                    TheyDiColors.gradientPrimary.createShader(bounds),
                child: Text(
                  'Experiences.',
                  style: GoogleFonts.inter(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              Text(
                'Less Scrolling.',
                style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: TheyDiColors.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Discover and join events — from fun\nget-togethers to professional gatherings,\nall in one place.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: TheyDiColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Map-like illustration mockup
              _MapMockup(),

              const SizedBox(height: 28),

              // Event Types section with images
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TheyDiColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Event Types',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: TheyDiColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.auto_awesome,
                            size: 18, color: TheyDiColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From casual meetups to industry events,\nthere\'s something for everyone.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: TheyDiColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _EventTypeItem(
                            imageUrl: _OnboardingImages.partyEvent,
                            color: const Color(0xFFFF6B8A),
                            label: 'Social\nEvents',
                            desc: 'Parties, hangouts,\nfun & more.',
                          ),
                        ),
                        Expanded(
                          child: _EventTypeItem(
                            imageUrl: _OnboardingImages.community,
                            color: TheyDiColors.primary,
                            label: 'Community\nEvents',
                            desc: 'Meet like-minded\npeople, join groups.',
                          ),
                        ),
                        Expanded(
                          child: _EventTypeItem(
                            imageUrl: _OnboardingImages.professional,
                            color: const Color(0xFF8B5CF6),
                            label: 'Professional\nEvents',
                            desc: 'Workshops, seminars,\ncareer & startup.',
                          ),
                        ),
                        Expanded(
                          child: _EventTypeItem(
                            imageUrl: _OnboardingImages.workshop,
                            color: const Color(0xFFF59E0B),
                            label: 'Special\nExperiences',
                            desc: 'Hackathons, retreats,\nexclusive events.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Find Your Next Experience ✨',
                  style: GoogleFonts.caveat(
                    fontSize: 18,
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────────────────────────────────────
// Page 3 — Meet People. Build Your Community.
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEEF2FF), Color(0xFFF5F7FF), Colors.white],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Title
              Text(
                'Meet People.',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: TheyDiColors.textPrimary,
                  height: 1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ).createShader(bounds),
                child: Text(
                  'Build Your\nCommunity.',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Join groups, be part of circles,\nchat with like-minded people,\nand grow your network.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: TheyDiColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // ── Community hero image ──
              _HeroEventCard(
                imageUrl: _OnboardingImages.community,
                badgeText: 'Your Community',
                title: 'Weekend Meetup',
                subtitle: 'Join 24 others · Central Park',
                gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),

              const SizedBox(height: 20),

              // For Friends & Fun badge
              _PaintBrushBadge(
                label: 'For Friends & Fun',
                color: TheyDiColors.primary,
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(height: 10),

              // Circle cards with images
              _CircleCard(
                imageUrl: _OnboardingImages.partyEvent,
                name: 'Circle',
                subtitle: 'Weekend Movie Lovers',
                members: '12 members',
                time: 'Just now',
                badgeLabel: 'New',
                badgeColor: TheyDiColors.primary,
                iconColor: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 10),
              _CircleCard(
                imageUrl: _OnboardingImages.coffeeMeetup,
                name: 'Foodies United',
                subtitle: 'Food & Art Festival',
                members: '24 members',
                time: '2h ago',
                iconColor: TheyDiColors.primary,
              ),

              const SizedBox(height: 18),

              // For Growth & Career badge
              _PaintBrushBadge(
                label: 'For Growth & Career',
                color: const Color(0xFF6366F1),
                icon: Icons.work_outline_rounded,
              ),
              const SizedBox(height: 10),

              _CircleCard(
                imageUrl: _OnboardingImages.networking,
                name: 'Networking Meetup',
                subtitle: 'Central Cafe',
                members: '21 members',
                time: '1d ago',
                iconColor: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 10),
              _CircleCard(
                imageUrl: _OnboardingImages.teamwork,
                name: 'Career Growth',
                subtitle: 'Product Design Circle',
                members: '28 members',
                time: 'Active now',
                iconColor: const Color(0xFF6366F1),
              ),

              const SizedBox(height: 24),

              // Bottom features — Community / Circle / Connection
              Row(
                children: [
                  Expanded(
                    child: _FeatureBox(
                      icon: Icons.people_alt_rounded,
                      iconColor: TheyDiColors.primary,
                      label: 'Community',
                      desc: 'Create or join groups\naround your interests.',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureBox(
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label: 'Circle',
                      desc: 'Host experiences,\nnotify your circle.',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureBox(
                      icon: Icons.chat_bubble_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Connection',
                      desc: 'Chat one-on-one or\nwith friends.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Good Vibes · Together is better',
                  style: GoogleFonts.caveat(
                    fontSize: 16,
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────────────────────────────────────
// Page 4 — More Connections. Greater Experiences.
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingPage4 extends StatelessWidget {
  const OnboardingPage4({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8FFF3), Color(0xFFF7FDFA), Colors.white],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Title
              Text(
                'More\nConnections.',
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: TheyDiColors.textPrimary,
                  height: 1.1,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) =>
                    TheyDiColors.gradientPrimary.createShader(bounds),
                child: Text(
                  'Greater\nExperiences.',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Low platform fee callout
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FFF3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: TheyDiColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.currency_rupee_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero Platform Fee',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: TheyDiColors.textPrimary,
                          ),
                        ),
                        Text(
                          'More value for your experiences.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: TheyDiColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Meet like-minded people, attend\namazing events, and grow —\nall in one place.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: TheyDiColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Social + Professional cards WITH images
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ExperienceTypeCard(
                      imageUrl: _OnboardingImages.socialEvent,
                      icon: Icons.people_alt_rounded,
                      iconColor: TheyDiColors.primary,
                      label: 'SOCIAL',
                      accentColor: TheyDiColors.primary,
                      description:
                          'Join casual meetups, hobby groups, and community events near you.',
                      chips: ['Picnics', 'Creative Groups', 'Meetups'],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ExperienceTypeCard(
                      imageUrl: _OnboardingImages.professional,
                      icon: Icons.work_outline_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'PROFESSIONAL',
                      accentColor: const Color(0xFF3B82F6),
                      description:
                          'Attend workshops, hackathons, networking sessions and more.',
                      chips: ['Workshops', 'Hackathons', 'Networking'],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Real People. Real Events.\nReal Connections.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.caveat(
                    fontSize: 18,
                    color: TheyDiColors.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Value props row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TheyDiColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ValueProp(
                        icon: Icons.location_on_rounded,
                        color: TheyDiColors.primary,
                        label: 'Nearby\nExperiences',
                        desc: 'Discover what\'s\nhappening around you.',
                      ),
                    ),
                    Expanded(
                      child: _ValueProp(
                        icon: Icons.verified_rounded,
                        color: TheyDiColors.primary,
                        label: 'Secure\nPayments',
                        desc: 'Pay safely and\nseamlessly.',
                      ),
                    ),
                    Expanded(
                      child: _ValueProp(
                        icon: Icons.people_alt_rounded,
                        color: TheyDiColors.primary,
                        label: 'Vibrant\nCommunity',
                        desc: 'Meet, share and\ncreate together.',
                      ),
                    ),
                    Expanded(
                      child: _ValueProp(
                        icon: Icons.star_rounded,
                        color: TheyDiColors.primary,
                        label: 'More\nValue',
                        desc: 'Lower fees,\nmore experiences.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Shared widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Network image with gradient fallback placeholder
class _NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final List<Color> fallbackGradient;

  const _NetImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackGradient = const [Color(0xFF10B981), Color(0xFF34D399)],
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder();
      },
      errorBuilder: (context, error, stack) => _placeholder(),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fallbackGradient,
        ),
      ),
      child: Icon(
        Icons.photo_camera_rounded,
        color: Colors.white.withValues(alpha: 0.5),
        size: 32,
      ),
    );
  }
}

/// Hero event card with a large image, gradient overlay, and text
class _HeroEventCard extends StatelessWidget {
  final String imageUrl;
  final String badgeText;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _HeroEventCard({
    required this.imageUrl,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            _NetImage(
              url: imageUrl,
              fit: BoxFit.cover,
              fallbackGradient: gradient,
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            // Badge
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 12, color: gradient[0]),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: TheyDiColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom text
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6EE7B7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small event card with image thumbnail (for Page 1 bottom row)
class _SmallEventCard extends StatelessWidget {
  final String imageUrl;
  final String label;
  final String title;
  final String time;
  final bool hasBookButton;

  const _SmallEventCard({
    required this.imageUrl,
    required this.label,
    required this.title,
    required this.time,
    this.hasBookButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: _NetImage(
                url: imageUrl,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: TheyDiColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: TheyDiColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: TheyDiColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: TheyDiColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasBookButton)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TheyDiColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Book',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decorative diagonal lines in top-right corner
class _LeafAccent extends StatelessWidget {
  final Color color;
  const _LeafAccent({this.color = TheyDiColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _LeafPainter(color)),
    );
  }
}

class _LeafPainter extends CustomPainter {
  final Color color;
  _LeafPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.4, 0),
      Offset(size.width, size.height * 0.6),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.6, 0),
      Offset(size.width, size.height * 0.4),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      2.5,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Category chip with icon, label, description
class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String desc;

  const _CategoryChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: TheyDiColors.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: TheyDiColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: TheyDiColors.textMuted),
        ],
      ),
    );
  }
}

/// Stylized map illustration mockup
class _MapMockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8FFF3), Color(0xFFF0FDF7), Color(0xFFDFF5EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Stack(
        children: [
          // Grid lines
          CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _GridPainter(),
          ),
          // Location pins
          Positioned(
            top: 40,
            left: 60,
            child: _MapPin(
                icon: Icons.music_note, color: const Color(0xFFFF6B8A)),
          ),
          Positioned(
            top: 70,
            left: 140,
            child: _MapPin(
                icon: Icons.people_alt, color: TheyDiColors.primary),
          ),
          Positioned(
            top: 50,
            right: 80,
            child: _MapPin(
                icon: Icons.work, color: const Color(0xFF3B82F6)),
          ),
          Positioned(
            bottom: 50,
            left: 100,
            child: _MapPin(
                icon: Icons.celebration, color: const Color(0xFFF59E0B)),
          ),
          Positioned(
            bottom: 40,
            right: 60,
            child: _MapPin(
                icon: Icons.favorite, color: const Color(0xFFFF6B8A)),
          ),
          // Center pulse
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TheyDiColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: TheyDiColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.my_location,
                  color: TheyDiColors.primary, size: 20),
            ),
          ),
          // Search bar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search,
                      size: 18, color: TheyDiColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Search experiences...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: TheyDiColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.tune, size: 16, color: TheyDiColors.textMuted),
                ],
              ),
            ),
          ),
          // Category chips at bottom
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              children: [
                _MapCategoryChip('All', TheyDiColors.primary, true),
                const SizedBox(width: 6),
                _MapCategoryChip('Social', const Color(0xFFFF6B8A), false),
                const SizedBox(width: 6),
                _MapCategoryChip(
                    'Professional', const Color(0xFF3B82F6), false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TheyDiColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _MapCategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  const _MapCategoryChip(this.label, this.color, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? color : TheyDiColors.divider,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : color,
        ),
      ),
    );
  }
}

/// Event type item with image thumbnail (for Page 2 grid)
class _EventTypeItem extends StatelessWidget {
  final String imageUrl;
  final Color color;
  final String label;
  final String desc;

  const _EventTypeItem({
    required this.imageUrl,
    required this.color,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _NetImage(
              url: imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              fallbackGradient: [color.withValues(alpha: 0.3), color],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TheyDiColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: TheyDiColors.textMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Paint-brush style badge for Page 3
class _PaintBrushBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _PaintBrushBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circle/group card with image thumbnail (for Page 3)
class _CircleCard extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String subtitle;
  final String members;
  final String time;
  final String? badgeLabel;
  final Color? badgeColor;
  final Color iconColor;

  const _CircleCard({
    this.imageUrl,
    required this.name,
    required this.subtitle,
    required this.members,
    required this.time,
    this.badgeLabel,
    this.badgeColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Image avatar instead of icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? _NetImage(
                      url: imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      fallbackGradient: [
                        iconColor.withValues(alpha: 0.3),
                        iconColor,
                      ],
                    )
                  : Container(
                      color: iconColor.withValues(alpha: 0.12),
                      child: Icon(Icons.people_alt_rounded,
                          color: iconColor, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TheyDiColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? TheyDiColors.primary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: badgeColor ?? TheyDiColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: TheyDiColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$members · $time',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: TheyDiColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: TheyDiColors.textMuted),
        ],
      ),
    );
  }
}

/// Feature box for Page 3 bottom row
class _FeatureBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String desc;

  const _FeatureBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TheyDiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: TheyDiColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Experience type card with image header (for Page 4)
class _ExperienceTypeCard extends StatelessWidget {
  final String? imageUrl;
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color accentColor;
  final String description;
  final List<String> chips;

  const _ExperienceTypeCard({
    this.imageUrl,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.accentColor,
    required this.description,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TheyDiColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image header
          if (imageUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: _NetImage(
                  url: imageUrl!,
                  height: 90,
                  fit: BoxFit.cover,
                  fallbackGradient: [
                    accentColor.withValues(alpha: 0.3),
                    accentColor,
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: TheyDiColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: TheyDiColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              c,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: accentColor,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Value proposition item for Page 4 bottom grid
class _ValueProp extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String desc;

  const _ValueProp({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TheyDiColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: TheyDiColors.textMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}