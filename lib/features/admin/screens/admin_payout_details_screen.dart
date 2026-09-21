import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminPayoutDetailsScreen extends StatefulWidget {
  final String hostUid;
  // payoutId / eventTitle / totalAmount are null when an admin is just
  // viewing a host's saved bank details (no payout involved) — in that case
  // the Event/Amount lines and the "Mark as Paid" button are hidden.
  final String? payoutId;
  final String? eventTitle;
  final double? totalAmount;
  final String? hostName;

  const AdminPayoutDetailsScreen({
    super.key,
    required this.hostUid,
    this.payoutId,
    this.eventTitle,
    this.totalAmount,
    this.hostName,
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

  bool get _viewOnly => widget.payoutId == null;

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
      if (!mounted) return;
      setState(() {
        _details = Map<String, dynamic>.from(result.data as Map);
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // The Cloud Function deliberately throws "not-found" (with its own
      // message) when the host hasn't set up payout details — that's an empty
      // state, not an error.
      //
      // BUT Firebase also returns code "not-found" with the bare message
      // "NOT_FOUND" when the callable itself doesn't exist (not deployed, wrong
      // name, or deployed to a different region than asia-south1). Treating
      // that as "no details on file" hides a real setup problem, so surface it.
      final functionMissing =
          e.code == 'not-found' && (e.message ?? '').trim() == 'NOT_FOUND';
      setState(() {
        if (e.code == 'not-found' && !functionMissing) {
          _details = null;
        } else if (functionMissing) {
          _error = 'getPayoutDetailsForAdmin was not found in asia-south1. '
              'Check that it is deployed to that region.';
        } else {
          _error = '${e.code}: ${e.message ?? e}';
        }
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

  Future<void> _markPaid() async {
    final payoutId = widget.payoutId;
    if (payoutId == null) return;
    // The dialog owns its own controller and returns the reference, so the
    // Confirm button can't close it while the UTR is empty (previously it
    // closed and _markPaid silently returned — it looked like nothing happened).
    final reference = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmPayoutDialog(
        summary:
            '₹${(widget.totalAmount ?? 0).toStringAsFixed(0)} for "${widget.eventTitle ?? ''}"',
      ),
    );
    if (reference == null || reference.isEmpty) return;

    setState(() => _marking = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('markPayoutCompleted');
      await callable.call({
        'payoutId': payoutId,
        'paymentReference': reference,
      });

      // Pop back to the list screen FIRST, before touching this screen's
      // ScaffoldMessenger. Showing a SnackBar here and popping in the same
      // frame yanks this Scaffold (and its still-animating SnackBar) out
      // of the tree mid-transition — that's what was causing the stray
      // white line and the follow-up "deactivated widget" error even
      // though the backend had already completed successfully. The
      // success message is now shown by the list screen instead, once
      // this route has actually finished popping.
      if (mounted) {
        Navigator.pop(context, true); // tell list screen to refresh
      }
    } catch (e) {
      if (mounted) {
        final message = e is FirebaseFunctionsException
            ? '${e.code}: ${e.message ?? 'unknown error'}'
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $message')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_viewOnly ? 'Host Bank Details' : 'Host Payout Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _details == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No payout details on file for this host.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.hostName != null)
                            Text('Host: ${widget.hostName}'),
                          if (!_viewOnly) ...[
                            Text('Event: ${widget.eventTitle}'),
                            Text(
                                'Amount: ₹${(widget.totalAmount ?? 0).toStringAsFixed(0)}'),
                          ],
                          const Divider(height: 32),
                          Text('Method: ${_details!['payoutMethod']}'),
                          const SizedBox(height: 8),
                          Text('Name: ${_details!['name'] ?? '-'}'),
                          if (_details!['bankName'] != null)
                            Text('Bank: ${_details!['bankName']}'),
                          if (_details!['payoutMethod'] == 'bank') ...[
                            const SizedBox(height: 8),
                            // Wrapped so a long account number can't cause
                            // a RenderFlex overflow on narrow web widths.
                            SizedBox(
                              width: double.infinity,
                              child: SelectableText(
                                'Account: ${_details!['accountNumber']}',
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: SelectableText(
                                'IFSC: ${_details!['ifsc']}',
                              ),
                            ),
                          ] else
                            SizedBox(
                              width: double.infinity,
                              child: SelectableText(
                                'UPI: ${_details!['upiId']}',
                              ),
                            ),
                          if (!_viewOnly) ...[
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _marking ? null : _markPaid,
                                child: _marking
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Mark as Paid'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _ConfirmPayoutDialog extends StatefulWidget {
  final String summary;
  const _ConfirmPayoutDialog({required this.summary});

  @override
  State<_ConfirmPayoutDialog> createState() => _ConfirmPayoutDialogState();
}

class _ConfirmPayoutDialogState extends State<_ConfirmPayoutDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final ref = _controller.text.trim();
    if (ref.isEmpty) {
      setState(() => _error = 'Enter the UTR / transaction reference');
      return;
    }
    Navigator.pop(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Payout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.summary),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'UTR / Transaction Reference',
              hintText: 'Required',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}