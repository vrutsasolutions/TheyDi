import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class AdminReferralScreen extends StatefulWidget {
  const AdminReferralScreen({super.key});

  @override
  State<AdminReferralScreen> createState() => _AdminReferralScreenState();
}

class _AdminReferralScreenState extends State<AdminReferralScreen> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('getReferralAdmin')
          .call({'limit': 200});
      final data = Map<String, dynamic>.from(result.data as Map);
      final records = (data['records'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final summary = data['summary'] != null
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      if (mounted) setState(() {
        _records = records;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(dynamic ms) {
    if (ms == null) return '—';
    return DateFormat('d MMM yy').format(
        DateTime.fromMillisecondsSinceEpoch(ms as int));
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'eligible': return TheyDiColors.primary;
      case 'attributed': return Colors.orange;
      default: return TheyDiColors.textMuted;
    }
  }

  Color _rewardColor(String? status) {
    switch (status) {
      case 'rewarded': return Colors.green;
      case 'pending': return Colors.orange;
      default: return TheyDiColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Admin'),
        backgroundColor: TheyDiColors.surface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _records.isEmpty
                  ? const Center(child: Text('No referrals yet.'))
                  : Column(
                      children: [
                        // Summary bar
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            color: TheyDiColors.card,
                            child: Row(
                              children: [
                                _Stat(label: 'Total',
                                    value: '${_summary['total'] ?? _records.length}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Eligible',
                                    value: '${_summary['eligible'] ?? 0}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Pending',
                                    value: '${_summary['pending'] ?? 0}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Women',
                                    value: '${_summary['women'] ?? 0}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Rewarded',
                                    value: '${_summary['rewarded'] ?? 0}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Credit Issued',
                                    value: '₹${(_summary['totalCreditIssued'] ?? 0).toStringAsFixed(2)}'),
                                const SizedBox(width: 24),
                                _Stat(label: 'Credit Used',
                                    value: '₹${(_summary['totalCreditUsed'] ?? 0).toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _records.length,
                            itemBuilder: (ctx, i) {
                              final r = _records[i];
                              return _RecordCard(r: r, fmt: _fmt,
                                  statusColor: _statusColor,
                                  rewardColor: _rewardColor);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: TheyDiTextStyles.displaySmall
              .copyWith(fontWeight: FontWeight.w800)),
      Text(label,
          style: TheyDiTextStyles.caption
              .copyWith(color: TheyDiColors.textSecondary)),
    ],
  );
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final String Function(dynamic) fmt;
  final Color Function(String?) statusColor;
  final Color Function(String?) rewardColor;

  const _RecordCard({
    required this.r,
    required this.fmt,
    required this.statusColor,
    required this.rewardColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWomen = r['gender'] == 'female';
    final status = r['status'] as String? ?? '';
    final reward = r['rewardStatus'] as String? ?? 'pending';
    final bookingAmt = (r['firstBookingAmount'] as num?)?.toDouble();
    final calcReward = (r['calculatedReward'] as num?)?.toDouble();

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
          // Header row
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['referredName'] ?? 'Unknown',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text('Referred by: ${r['referrerName'] ?? 'Unknown'}',
                      style: TheyDiTextStyles.caption
                          .copyWith(color: TheyDiColors.textSecondary)),
                ],
              ),
            ),
            if (isWomen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: const Color(0xFFE91E8C).withValues(alpha: 0.4)),
                ),
                child: const Text('♀ Female',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFE91E8C),
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 10),
          // Data rows
          _DataRow('Referral Code', r['referralCode'] ?? '—'),
          _DataRow('Registered', fmt(r['registeredAt'])),
          _DataRow('Status', status,
              valueColor: statusColor(status)),
          _DataRow('Eligible At', fmt(r['eligibleAt'])),
          if (bookingAmt != null)
            _DataRow('Booking Amount', '₹${bookingAmt.toStringAsFixed(2)}'),
          _DataRow('Milestone', r['milestoneKey'] ?? 'Not in milestone'),
          _DataRow('Reward Status', reward,
              valueColor: rewardColor(reward)),
          if (calcReward != null)
            _DataRow('Calculated Reward', '₹${calcReward.toStringAsFixed(2)}',
                valueColor: Colors.green),
          _DataRow('Rewarded At', fmt(r['rewardedAt'])),
          _DataRow('Booking ID',
              r['firstBookingId'] != null
                  ? (r['firstBookingId'] as String).substring(0, 8) + '...'
                  : '—'),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DataRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TheyDiTextStyles.caption
                  .copyWith(color: TheyDiColors.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: TheyDiTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? TheyDiColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}