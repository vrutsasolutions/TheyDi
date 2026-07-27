import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../events/models/booking_model.dart';
import '../../events/models/event_model.dart';
import 'package:theydi/core/router/app_routes.dart';
import 'package:theydi/core/router/app_router.dart';
// Stream host's events
final _hostEventsProvider = StreamProvider.autoDispose<List<EventModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('events')
      .where('creatorUid', isEqualTo: uid)
      .orderBy('dateTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => EventModel.fromFirestore(d)).toList());
});

// Stream bookings for host's events
final _hostBookingsProvider =
    StreamProvider.autoDispose<List<BookingModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('hostUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
});

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {

  Future<void> _showBankDetailsBottomSheet(BuildContext context) async {
    // ── Load existing bank details from Firestore first ──
    final uid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, dynamic> existingData = {};
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('private')
            .doc('bankDetails')
            .get();
        existingData = doc.data() ?? {};

        // Fallback for older users who have bank details in the root user document
        if (existingData.isEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final uData = userDoc.data() ?? {};
          if (uData['bankAccountName'] != null ||
              uData['bankAccountNumber'] != null) {
            existingData = {
              'payoutMethod': 'bank',
              'bankAccountName': uData['bankAccountName'],
              'bankIfsc': uData['bankIfsc'],
              'bankAccountNumber': uData['bankAccountNumber'],
            };
          }
        }
      } catch (e) {
        debugPrint('Error fetching bank details: $e');
      }
    }

    String payoutMethod = existingData['payoutMethod'] ?? 'bank';
    final existingName = (existingData['bankAccountName'] ?? '').toString();
    final existingIfsc = (existingData['bankIfsc'] ?? '').toString();
    final existingAccount =
        (existingData['bankAccountNumber'] ?? '').toString();
    final existingUpi = (existingData['upiId'] ?? '').toString();

    final hasExisting = payoutMethod == 'bank'
        ? (existingName.isNotEmpty &&
            existingIfsc.isNotEmpty &&
            existingAccount.isNotEmpty)
        : existingUpi.isNotEmpty;

    final nameCtrl = TextEditingController(text: existingName);
    final ifscCtrl = TextEditingController(text: existingIfsc);
    final accCtrl = TextEditingController(text: existingAccount);
    final upiCtrl = TextEditingController(text: existingUpi);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TheyDiColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // isEditing = false means read-only view; true means editable
          bool isEditing = !hasExisting;
          bool isSaving = false;

          return StatefulBuilder(
            builder: (context, setInnerState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasExisting ? 'Bank Details' : 'Setup Host Payouts',
                            style: TheyDiTextStyles.headlineMedium,
                          ),
                        ),
                        if (hasExisting && !isEditing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_outlined,
                                    color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text('Saved',
                                    style: TheyDiTextStyles.caption.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasExisting
                          ? isEditing
                              ? 'Edit your bank details below and save.'
                              : 'Your bank details are saved. Tap "Update Details" to change them.'
                          : 'Add your bank details to receive automatic payouts for your paid events.',
                      style: TheyDiTextStyles.bodySmall
                          .copyWith(color: TheyDiColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // ── Fields ──
                    if (isEditing) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: TheyDiColors.divider.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setInnerState(() => payoutMethod = 'bank'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: payoutMethod == 'bank'
                                        ? TheyDiColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text('Bank Account',
                                        style: TextStyle(
                                          color: payoutMethod == 'bank'
                                              ? Colors.white
                                              : TheyDiColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setInnerState(() => payoutMethod = 'upi'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: payoutMethod == 'upi'
                                        ? TheyDiColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text('UPI',
                                        style: TextStyle(
                                          color: payoutMethod == 'upi'
                                              ? Colors.white
                                              : TheyDiColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                                sizeFactor: animation, child: child));
                      },
                      child: payoutMethod == 'bank'
                          ? Column(
                              key: const ValueKey('bank'),
                              children: [
                                TextFormField(
                                  controller: nameCtrl,
                                  enabled: isEditing,
                                  style: TheyDiTextStyles.bodyMedium,
                                  decoration: InputDecoration(
                                    labelText: 'Account Holder Name',
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                    filled: !isEditing,
                                    fillColor: TheyDiColors.divider
                                        .withValues(alpha: 0.3),
                                    suffixIcon: !isEditing
                                        ? const Icon(Icons.lock_outline,
                                            size: 16,
                                            color: TheyDiColors.textMuted)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: ifscCtrl,
                                  enabled: isEditing,
                                  style: TheyDiTextStyles.bodyMedium,
                                  decoration: InputDecoration(
                                    labelText: 'IFSC Code',
                                    hintText: 'e.g. HDFC0001234',
                                    prefixIcon: const Icon(
                                        Icons.account_balance_outlined),
                                    filled: !isEditing,
                                    fillColor: TheyDiColors.divider
                                        .withValues(alpha: 0.3),
                                    suffixIcon: !isEditing
                                        ? const Icon(Icons.lock_outline,
                                            size: 16,
                                            color: TheyDiColors.textMuted)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: accCtrl,
                                  enabled: isEditing,
                                  style: TheyDiTextStyles.bodyMedium,
                                  keyboardType: TextInputType.number,
                                  obscureText:
                                      !isEditing, // mask account number when locked
                                  decoration: InputDecoration(
                                    labelText: 'Account Number',
                                    prefixIcon:
                                        const Icon(Icons.numbers_outlined),
                                    filled: !isEditing,
                                    fillColor: TheyDiColors.divider
                                        .withValues(alpha: 0.3),
                                    suffixIcon: !isEditing
                                        ? const Icon(Icons.lock_outline,
                                            size: 16,
                                            color: TheyDiColors.textMuted)
                                        : null,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('upi'),
                              children: [
                                TextFormField(
                                  controller: upiCtrl,
                                  enabled: isEditing,
                                  style: TheyDiTextStyles.bodyMedium,
                                  decoration: InputDecoration(
                                    labelText: 'UPI ID (VPA)',
                                    hintText: 'e.g. username@bank',
                                    prefixIcon: const Icon(Icons.payment),
                                    filled: !isEditing,
                                    fillColor: TheyDiColors.divider
                                        .withValues(alpha: 0.3),
                                    suffixIcon: !isEditing
                                        ? const Icon(Icons.lock_outline,
                                            size: 16,
                                            color: TheyDiColors.textMuted)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // ── Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: hasExisting && !isEditing
                          // READ-ONLY: show "Update Details" to unlock
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Update Details'),
                              onPressed: () =>
                                  setInnerState(() => isEditing = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TheyDiColors.primary,
                                side: const BorderSide(
                                    color: TheyDiColors.primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          // EDIT MODE: save button
                          : ElevatedButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (payoutMethod == 'bank') {
                                        if (nameCtrl.text.trim().isEmpty ||
                                            ifscCtrl.text.trim().isEmpty ||
                                            accCtrl.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Please fill all bank fields')));
                                          return;
                                        }
                                      } else {
                                        if (upiCtrl.text.trim().isEmpty) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Please enter your UPI ID')));
                                          return;
                                        }
                                      }

                                      setInnerState(() => isSaving = true);
                                      try {
                                        final callable =
                                            FirebaseFunctions.instanceFor(
                                                    region: 'asia-south1')
                                                .httpsCallable(
                                                    'setupHostCashfreeBeneficiary');
                                        await callable.call({
                                          'payoutMethod': payoutMethod,
                                          'upiId': upiCtrl.text.trim(),
                                          'name': nameCtrl.text.trim(),
                                          'ifsc': ifscCtrl.text.trim(),
                                          'accountNumber': accCtrl.text.trim(),
                                        });
                                        // Also cache the display values locally in Firestore
                                        if (uid != null) {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .collection('private')
                                              .doc('bankDetails')
                                              .set({
                                            'payoutMethod': payoutMethod,
                                            'upiId': upiCtrl.text.trim(),
                                            'bankAccountName':
                                                nameCtrl.text.trim(),
                                            'bankIfsc': ifscCtrl.text.trim(),
                                            'bankAccountNumber':
                                                accCtrl.text.trim(),
                                          }, SetOptions(merge: true));
                                        }
                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(hasExisting
                                                ? 'Payout details updated!'
                                                : 'Payout details saved!'),
                                            backgroundColor: Colors.green,
                                          ));
                                        }
                                      } catch (e) {
                                        setInnerState(() => isSaving = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red));
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TheyDiColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      hasExisting
                                          ? 'Save Updated Details'
                                          : 'Save Details',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPayoutSettingsSheet() {
showDialog(
  context: context,
  builder: (context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TheyDiColors.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: TheyDiColors.divider,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: TheyDiColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: TheyDiColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout Settings',
                        style: TheyDiTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage how you get paid',
                        style: TheyDiTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change Bank Details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.personalDetails);
              },
            ),
          ],
        ),
      ),
    );
  },
);
}

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(_hostEventsProvider);
    final bookingsAsync = ref.watch(_hostBookingsProvider);

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
                    Text('Host Dashboard',
                        style: TheyDiTextStyles.displayMedium),
                    const Spacer(),
InkWell(
  onTap: _showPayoutSettingsSheet,
  borderRadius: BorderRadius.circular(14),
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: TheyDiColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: TheyDiColors.primary.withValues(alpha: 0.25),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: TheyDiColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.account_balance,
            size: 18,
            color: TheyDiColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bank Setup',
              style: TheyDiTextStyles.labelMedium,
            ),
            Text(
              'Change Details',
              style: TheyDiTextStyles.bodySmall.copyWith(
                color: TheyDiColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.chevron_right,
          color: TheyDiColors.primary,
          size: 18,
        ),
      ],
    ),
  ),
),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: eventsAsync.when(
                  loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: TheyDiColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Text('Failed to load: $e',
                        style: TheyDiTextStyles.bodySmall),
                  ),
                  data: (events) {
                    return bookingsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: TheyDiColors.primary),
                      ),
                      error: (e, _) => Center(
                        child: Text('Failed to load: $e',
                            style: TheyDiTextStyles.bodySmall),
                      ),
                      data: (bookings) {
                        if (events.isEmpty) {
                          return _buildEmptyState();
                        }

                        return _DashboardContent(
                          events: events,
                          bookings: bookings,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text('No events created yet', style: TheyDiTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Create your first event to see analytics here',
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final List<EventModel> events;
  final List<BookingModel> bookings;

  const _DashboardContent({
    required this.events,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final totalEvents = events.length;
    final totalAttendees =
        events.fold(0, (sum, e) => sum + e.attendeeUids.length);
    final confirmedBookings = bookings.where((b) => b.isConfirmed).toList();
    final totalRevenue =
        confirmedBookings.fold(0.0, (sum, b) => sum + b.amount);
    final platformFees =
        confirmedBookings.fold(0.0, (sum, b) => sum + b.platformFee);
    final netEarnings = totalRevenue - platformFees;

    // Upcoming vs past events
    final now = DateTime.now();
    final upcomingEvents =
        events.where((e) => e.dateTime.isAfter(now)).toList();
    final pastEvents = events.where((e) => e.dateTime.isBefore(now)).toList();

    // Average fill rate
    final totalCapacity = events.fold(0, (sum, e) => sum + e.maxAttendees);
    final fillRate =
        totalCapacity > 0 ? (totalAttendees / totalCapacity * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Revenue card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: TheyDiColors.gradientPrimary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total earnings',
                  style:
                      TheyDiTextStyles.caption.copyWith(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                '₹${netEarnings.toStringAsFixed(0)}',
                style: TheyDiTextStyles.displayLarge
                    .copyWith(color: Colors.white, fontSize: 36),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat('Revenue', '₹${totalRevenue.toStringAsFixed(0)}'),
                  const SizedBox(width: 20),
                  _miniStat('Platform cut (-5%)',
                      '₹${platformFees.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ).animate(delay: 100.ms).fade(duration: 400.ms),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TheyDiColors.divider, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Host Guidelines & Rules',
                style: TheyDiTextStyles.labelLarge
                    .copyWith(color: TheyDiColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _RuleItem(
                  text:
                      'Payouts will be credited to your linked bank account within 24 hours after your event completes successfully.'),
              const SizedBox(height: 8),
              _RuleItem(
                  text:
                      'Ensure your bank details are correct before event completion. Incorrect details may lead to payment loss.'),
              const SizedBox(height: 8),
              _RuleItem(
                  text:
                      'Events can only be cancelled up to 48 hours prior to the scheduled start time.'),
              const SizedBox(height: 8),
              _RuleItem(
                  text:
                      'A 5% platform convenience fee is deducted from your base ticket revenue.'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Stats grid
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.event,
                label: 'Total events',
                value: totalEvents.toString(),
                iconColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people,
                label: 'Total attendees',
                value: totalAttendees.toString(),
                iconColor: Colors.green,
              ),
            ),
          ],
        ).animate(delay: 150.ms).fade(duration: 400.ms),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.confirmation_num,
                label: 'Bookings',
                value: confirmedBookings.length.toString(),
                iconColor: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.pie_chart_outline,
                label: 'Fill rate',
                value: '${fillRate.toStringAsFixed(0)}%',
                iconColor: Colors.amber,
              ),
            ),
          ],
        ).animate(delay: 200.ms).fade(duration: 400.ms),

        const SizedBox(height: 24),

        // Event performance
        Text('Event performance', style: TheyDiTextStyles.labelLarge)
            .animate(delay: 250.ms)
            .fade(duration: 300.ms),
        const SizedBox(height: 4),
        Text(
          '${upcomingEvents.length} upcoming · ${pastEvents.length} completed',
          style: TheyDiTextStyles.caption
              .copyWith(color: TheyDiColors.textSecondary),
        ).animate(delay: 280.ms).fade(duration: 300.ms),
        const SizedBox(height: 12),

        ...List.generate(events.length, (index) {
          final event = events[index];
          final isPast = event.dateTime.isBefore(now);
          final eventBookings =
              confirmedBookings.where((b) => b.eventId == event.id).toList();
          final eventRevenue =
              eventBookings.fold(0.0, (sum, b) => sum + b.amount);

          return _EventPerformanceCard(
            event: event,
            isPast: isPast,
            bookingCount: eventBookings.length,
            revenue: eventRevenue,
          )
              .animate(delay: Duration(milliseconds: 300 + 50 * index))
              .fade(duration: 300.ms)
              .slideY(begin: 0.1, end: 0);
        }),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TheyDiTextStyles.caption
                .copyWith(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: TheyDiTextStyles.labelMedium.copyWith(color: Colors.white)),
      ],
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: TheyDiTextStyles.displayMedium),
          const SizedBox(height: 2),
          Text(label, style: TheyDiTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Event Performance Card ──
class _EventPerformanceCard extends StatelessWidget {
  final EventModel event;
  final bool isPast;
  final int bookingCount;
  final double revenue;

  const _EventPerformanceCard({
    required this.event,
    required this.isPast,
    required this.bookingCount,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(event.dateTime);
    final fillPercent = event.maxAttendees > 0
        ? (event.attendeeUids.length / event.maxAttendees * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Expanded(
                child: Text(event.title,
                    style: TheyDiTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPast
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPast ? 'Completed' : 'Upcoming',
                  style: TheyDiTextStyles.caption.copyWith(
                    color: isPast ? Colors.grey : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(dateStr, style: TheyDiTextStyles.caption),
          const SizedBox(height: 10),

          // Fill bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillPercent / 100,
                    backgroundColor: TheyDiColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      fillPercent > 80
                          ? Colors.green
                          : fillPercent > 50
                              ? Colors.amber
                              : TheyDiColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${event.attendeeUids.length}/${event.maxAttendees}',
                style: TheyDiTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              Icon(Icons.confirmation_num_outlined,
                  size: 13, color: TheyDiColors.textMuted),
              const SizedBox(width: 4),
              Text('$bookingCount bookings', style: TheyDiTextStyles.caption),
              const SizedBox(width: 16),
              if (revenue > 0) ...[
                Icon(Icons.currency_rupee,
                    size: 13, color: TheyDiColors.textMuted),
                const SizedBox(width: 2),
                Text('₹${revenue.toStringAsFixed(0)}',
                    style:
                        TheyDiTextStyles.caption.copyWith(color: Colors.green)),
              ],
              if (event.isFree)
                Text('Free event',
                    style: TheyDiTextStyles.caption
                        .copyWith(color: TheyDiColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;

  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Icon(Icons.circle, size: 6, color: TheyDiColors.primary),
        ),
        Expanded(
          child: Text(
            text,
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
