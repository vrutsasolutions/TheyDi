import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/support_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@theydi.app',
      query: 'subject=TheyDi Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
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
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Help & Support',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Contact options
                    Text(
                      'CONTACT US',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate(delay: 100.ms).fade(duration: 300.ms),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            subtitle: 'support@theydi.app',
                            onTap: _launchEmail,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ContactCard(
                            icon: Icons.chat_outlined,
                            label: 'Live Chat',
                            subtitle: 'Chat with Darla AI Support',
                            onTap: () {
                              GoRouter.of(rootNavigatorKey.currentContext!)
                                  .push(AppRoutes.darlaChat);
                            },
                          ),
                        ),
                      ],
                    ).animate(delay: 150.ms).fade(duration: 400.ms),

                    const SizedBox(height: 28),

                    // FAQ section
                    Text(
                      'FREQUENTLY ASKED QUESTIONS',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate(delay: 200.ms).fade(duration: 300.ms),
                    const SizedBox(height: 10),

                    ...List.generate(SupportConstants.faqs.length, (index) {
                      final faq = SupportConstants.faqs[index];
                      final isExpanded = _expandedIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isExpanded
                                  ? TheyDiColors.primary.withValues(alpha: 0.4)
                                  : TheyDiColors.divider,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      faq['q']!,
                                      style:
                                          TheyDiTextStyles.labelMedium.copyWith(
                                        fontWeight: isExpanded
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 250),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: TheyDiColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 10),
                                Container(
                                  height: 1,
                                  color: TheyDiColors.divider,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  faq['a']!,
                                  style: TheyDiTextStyles.bodySmall.copyWith(
                                    color: TheyDiColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                          .animate(
                            delay: Duration(milliseconds: 250 + 40 * index),
                          )
                          .fade(duration: 300.ms);
                    }),

                    const SizedBox(height: 28),

                    // App info
                    Text(
                      'APP INFO',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate(delay: 600.ms).fade(duration: 300.ms),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TheyDiColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Column(
                        children: [
                          _infoRow('App version', '1.0.0'),
                          const SizedBox(height: 8),
                          _infoRow('Build', 'MVP'),
                          const SizedBox(height: 8),
                          _infoRow('Platform', 'Flutter + Firebase'),
                        ],
                      ),
                    ).animate(delay: 650.ms).fade(duration: 300.ms),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary)),
        Text(value, style: TheyDiTextStyles.labelMedium),
      ],
    );
  }
}

// ── Contact Card ──
class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TheyDiColors.divider),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TheyDiColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: TheyDiColors.primary, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label, style: TheyDiTextStyles.labelMedium),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TheyDiTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
