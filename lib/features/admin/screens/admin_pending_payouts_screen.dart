import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'admin_payout_details_screen.dart';

String _hostName(Map<String, dynamic> data, String uid) {
  for (final key in ['displayName', 'name', 'email']) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return uid;
}

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

  // "Host Bank Details" tab — every host who has saved bank/UPI details,
  // even if no payout exists for them yet.
  bool _hostsLoading = true;
  String? _hostsError;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _hosts = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    setState(() {
      _hostsLoading = true;
      _hostsError = null;
    });
    try {
      // payoutSetupCompleted is set to true by the savePayoutDetails
      // Cloud Function once a host's details are saved.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('payoutSetupCompleted', isEqualTo: true)
          .get();
      final docs = snap.docs.toList()
        ..sort((a, b) => _hostName(a.data(), a.id)
            .toLowerCase()
            .compareTo(_hostName(b.data(), b.id).toLowerCase()));
      if (!mounted) return;
      setState(() {
        _hosts = docs;
        _hostsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hostsError = e.toString();
        _hostsLoading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // One query for both statuses the admin needs to act on.
      // NOTE: the old version ran two `where(status) + orderBy(createdAt)`
      // queries, which need a composite index (status + createdAt). If that
      // index isn't deployed the whole screen dies with a failed-precondition
      // error. We sort client-side below anyway, so no orderBy = no index.
      final snap = await FirebaseFirestore.instance
          .collection('payouts')
          .where('status', whereIn: ['pending', 'blocked_no_details'])
          .get();

      // Newest first
      final allDocs = snap.docs.toList();
      allDocs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        _payouts = allDocs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Payouts'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _load();
                _loadHosts();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Payouts'),
              Tab(text: 'Host Bank Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildPayoutsTab(), _buildHostsTab()],
        ),
      ),
    );
  }

  Widget _buildHostsTab() {
    if (_hostsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hostsError != null) {
      return Center(child: Text('Error: $_hostsError'));
    }
    if (_hosts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No host has added bank/UPI details yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _hosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = _hosts[index];
        final data = doc.data();
        final name = _hostName(data, doc.id);
        final email = (data['email'] as String?) ?? '';
        final mode = (data['payoutMode'] as String?)?.toUpperCase() ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TheyDiColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TheyDiColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TheyDiTextStyles.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty && email != name) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TheyDiTextStyles.bodySmall
                            .copyWith(color: TheyDiColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      mode.isEmpty ? 'Host: ${doc.id}' : 'Method: $mode',
                      style: TheyDiTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminPayoutDetailsScreen(
                      hostUid: doc.id,
                      hostName: name,
                    ),
                  ),
                ),
                child: const Text('View'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayoutsTab() {
    return _loading
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
                                  final messenger =
                                      ScaffoldMessenger.of(context);
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
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Payout marked as completed.'),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('View'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
  }
}