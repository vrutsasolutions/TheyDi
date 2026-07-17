import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _loading = true;

  static const _keyNotifications = 'pref_notifications_enabled';
  static const _keyLocation = 'pref_location_enabled';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
        _locationEnabled = prefs.getBool(_keyLocation) ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _setNotifications(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, val);
    if (mounted) setState(() => _notificationsEnabled = val);
  }

  Future<void> _setLocation(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocation, val);
    if (mounted) setState(() => _locationEnabled = val);
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
            children: [
              // ── App Bar ──
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
                    Text('Settings', style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 8),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Permissions Section ──
                            _SectionLabel(label: 'Permissions')
                                .animate(delay: 60.ms)
                                .fade(duration: 300.ms),
                            const SizedBox(height: 10),

                            _ToggleTile(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              subtitle: 'Receive booking updates & alerts',
                              value: _notificationsEnabled,
                              onChanged: _setNotifications,
                            ).animate(delay: 80.ms).fade(duration: 300.ms),

                            _ToggleTile(
                              icon: Icons.location_on_outlined,
                              label: 'Location',
                              subtitle: 'Used for nearby event suggestions',
                              value: _locationEnabled,
                              onChanged: _setLocation,
                            ).animate(delay: 100.ms).fade(duration: 300.ms),

                            const SizedBox(height: 24),

                            // ── Host Section ──
                            _SectionLabel(label: 'Host')
                                .animate(delay: 115.ms)
                                .fade(duration: 300.ms),
                            const SizedBox(height: 10),

                            _SettingsTile(
                              icon: Icons.analytics_outlined,
                              label: 'Host Dashboard',
                              subtitle: 'Event stats & earnings',
                              onTap: () =>
                                  context.push(AppRoutes.hostDashboard),
                            ).animate(delay: 120.ms).fade(duration: 300.ms),

                            const SizedBox(height: 24),

                            // ── Account Section ──
                            _SectionLabel(label: 'Account')
                                .animate(delay: 130.ms)
                                .fade(duration: 300.ms),
                            const SizedBox(height: 10),

                            _SettingsTile(
                              icon: Icons.shield_outlined,
                              label: 'Privacy & Safety',
                              subtitle: 'Control your visibility & data',
                              onTap: () =>
                                  context.push(AppRoutes.privacySafety),
                            ).animate(delay: 140.ms).fade(duration: 300.ms),

                            _SettingsTile(
                              icon: Icons.receipt_long_outlined,
                              label: 'Payment History',
                              subtitle: 'View your transactions',
                              onTap: () =>
                                  context.push(AppRoutes.paymenthistory),
                            ).animate(delay: 160.ms).fade(duration: 300.ms),

                            const SizedBox(height: 24),

                            // ── Support Section ──
                            _SectionLabel(label: 'Support')
                                .animate(delay: 180.ms)
                                .fade(duration: 300.ms),
                            const SizedBox(height: 10),

                            _SettingsTile(
                              icon: Icons.help_outline,
                              label: 'Help & Support',
                              subtitle: 'FAQs & contact us',
                              onTap: () => context.push(AppRoutes.helpSupport),
                            ).animate(delay: 200.ms).fade(duration: 300.ms),

                            const SizedBox(height: 40),
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

// ── Section Label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: TheyDiTextStyles.caption.copyWith(
          color: TheyDiColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Toggle Tile ────────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: TheyDiColors.textSecondary, size: 20),
        title: Text(label, style: TheyDiTextStyles.bodyMedium),
        subtitle: Text(subtitle, style: TheyDiTextStyles.caption),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: TheyDiColors.primary,
          activeTrackColor: TheyDiColors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: TheyDiColors.textMuted,
          inactiveTrackColor: TheyDiColors.divider,
        ),
      ),
    );
  }
}

// ── Settings Tile ──────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: TheyDiColors.textSecondary, size: 20),
        title: Text(label, style: TheyDiTextStyles.bodyMedium),
        subtitle: Text(subtitle, style: TheyDiTextStyles.caption),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: TheyDiColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
