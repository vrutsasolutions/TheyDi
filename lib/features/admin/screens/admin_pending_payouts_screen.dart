import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'admin_payout_details_screen.dart';

class AdminPendingPayoutsScreen extends StatefulWidget {
  const AdminPendingPayoutsScreen({super.key});

  @override
  State<AdminPendingPayoutsScreen> createState() =>
      _AdminPendingPayoutsScreenState();
}

class _AdminPendingPayoutsScreenState
    extends State<AdminPendingPayoutsScreen> {
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch both "pending" and "blocked_no_details" payouts so the
      // admin sees everything that needs attention.
      final pendingSnap = await FirebaseFirestore.instance
          .collection('payouts')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      final blockedSnap = await FirebaseFirestore.instance
          .collection('payouts')
          .where('status', isEqualTo: 'blocked_no_details')
          .orderBy('createdAt', descending: true)
          .get();

      // Merge and sort by createdAt descending
      final allDocs = [...blockedSnap.docs, ...pendingSnap.docs];
      allDocs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _payouts = allDocs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payouts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _payouts.isEmpty
                  ? const Center(child: Text('No pending payouts 🎉'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = _payouts[index];
                        final data = doc.data();
                        final hostUid = data['hostUid'] as String? ?? '';
                        final eventTitle =
                            data['eventTitle'] as String? ?? 'Unknown Event';
                        final totalAmount =
                            (data['totalAmount'] as num?)?.toDouble() ?? 0;
                        final bookingCount =
                            (data['bookingIds'] as List?)?.length ?? 0;
                        final isBlocked =
                            data['status'] == 'blocked_no_details';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isBlocked
                                  ? Colors.orange.shade300
                                  : TheyDiColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eventTitle,
                                      style: TheyDiTextStyles.labelMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$bookingCount booking(s) · ₹${totalAmount.toStringAsFixed(0)} pending',
                                      style: TheyDiTextStyles.bodySmall
                                          .copyWith(
                                              color: TheyDiColors
                                                  .textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Host: $hostUid',
                                      style: TheyDiTextStyles.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isBlocked) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '⚠ No bank/UPI details',
                                          style: TheyDiTextStyles.caption
                                              .copyWith(
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminPayoutDetailsScreen(
                                        hostUid: hostUid,
                                        payoutId: doc.id,
                                        eventTitle: eventTitle,
                                        totalAmount: totalAmount,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _load();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Payout marked as completed.'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: const Text('View'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}