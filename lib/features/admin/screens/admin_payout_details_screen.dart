import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminPayoutDetailsScreen extends StatefulWidget {
  final String hostUid;
  final String payoutId;
  final String eventTitle;
  final double totalAmount;

  const AdminPayoutDetailsScreen({
    super.key,
    required this.hostUid,
    required this.payoutId,
    required this.eventTitle,
    required this.totalAmount,
  });

  @override
  State<AdminPayoutDetailsScreen> createState() =>
      _AdminPayoutDetailsScreenState();
}

class _AdminPayoutDetailsScreenState extends State<AdminPayoutDetailsScreen> {
  Map<String, dynamic>? _details;
  String? _error;
  bool _loading = true;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('getPayoutDetailsForAdmin');
      final result = await callable.call({'hostUid': widget.hostUid});
      setState(() {
        _details = Map<String, dynamic>.from(result.data as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markPaid() async {
    final refController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${widget.totalAmount.toStringAsFixed(0)} for "${widget.eventTitle}"'),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              decoration: const InputDecoration(
                labelText: 'UTR / Transaction Reference',
                hintText: 'Required',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || refController.text.trim().isEmpty) return;

    setState(() => _marking = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('markPayoutCompleted');
      await callable.call({
        'payoutId': widget.payoutId,
        'paymentReference': refController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout marked as completed.')),
        );
        Navigator.pop(context, true); // tell list screen to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host Payout Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event: ${widget.eventTitle}'),
                      Text('Amount: ₹${widget.totalAmount.toStringAsFixed(0)}'),
                      const Divider(height: 32),
                      Text('Method: ${_details!['payoutMethod']}'),
                      const SizedBox(height: 8),
                      Text('Name: ${_details!['name'] ?? '-'}'),
                      if (_details!['bankName'] != null)
                        Text('Bank: ${_details!['bankName']}'),
                      if (_details!['payoutMethod'] == 'bank') ...[
                        const SizedBox(height: 8),
                        SelectableText('Account: ${_details!['accountNumber']}'),
                        SelectableText('IFSC: ${_details!['ifsc']}'),
                      ] else
                        SelectableText('UPI: ${_details!['upiId']}'),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _marking ? null : _markPaid,
                          child: _marking
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Mark as Paid'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}