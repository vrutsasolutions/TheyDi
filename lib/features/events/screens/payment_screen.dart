import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_web/razorpay_web.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/event_circle_service.dart';
import '../models/booking_model.dart';
import '../models/event_model.dart';

// ══════════════════════════════════════════════════════════════════════════
// PaymentScreen — the actual checkout screen for AppRoutes.payment.
//
// This class did not exist anywhere in the codebase: app_router.dart calls
// `PaymentScreen(event: ..., fromApproval: ...)` at two GoRoutes, but this
// file only contained a duplicate of PaymentSuccessScreen (see
// DuplicatePaymentSuccessScreen below, kept rather than deleted). That
// mismatch is what showed up as "The function 'PaymentScreen' isn't
// defined" in your Problems panel — a pre-existing gap, not something the
// earlier fixes touched.
//
// Flow modeled directly off event_detail_screen.dart's _joinEvent /
// _handleAction, which already distinguishes the two ways a user lands
// here:
//   • fromApproval == false → "Paid + First Come": straight to payment,
//     confirming adds the uid directly to attendeeUids.
//   • fromApproval == true  → "Paid + Host Approval": host already moved
//     the uid from pendingUids to approvedPendingPaymentUids; confirming
//     here moves it from approvedPendingPaymentUids to attendeeUids.
// Pricing mirrors BookingModel's existing 10% platform-fee calculation
// (same numbers payment_history_screen.dart already displays), and on
// success this pushes to AppRoutes.paymentsuccess with the same
// eventTitle/amount/transactionId/dateTime/venue map app_router.dart's
// GoRoute already expects.
// ══════════════════════════════════════════════════════════════════════════

class PaymentScreen extends StatefulWidget {
  final EventModel event;
  final bool fromApproval;

  const PaymentScreen({
    super.key,
    required this.event,
    required this.fromApproval,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Razorpay _razorpay;
  bool _isProcessing = false;
  String? _error;

  double get _platformFee =>
      BookingModel.calculatePlatformFee(widget.event.price);
  double get _total => BookingModel.calculateTotal(widget.event.price);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _confirmAndPay() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final event = widget.event;
      final createOrder = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('createOrder');
      final result = await createOrder.call({
        'amount': (_total * 100).round(),
        'currency': 'INR',
        'receipt': 'event_${event.id}_${uid.substring(0, 8)}',
        'notes': {
          'eventId': event.id,
          'eventTitle': event.title,
          'userId': uid,
          'hostUid': event.creatorUid,
          'platformFee': _platformFee.toString(),
          'totalAmount': _total.toString(),
          'fromApproval': widget.fromApproval.toString(),
        },
      });
      final order = Map<String, dynamic>.from(result.data as Map);
      final keyId = dotenv.env['RAZORPAY_KEY_ID']?.trim();
      if (keyId == null || keyId.isEmpty) {
        throw StateError('Razorpay key is not configured for this build.');
      }
      if (!mounted) return;

      _razorpay.open({
        'key': keyId,
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'name': 'TheyDi',
        'description': event.title,
        'order_id': order['orderId'],
        'prefill': {
          'name': FirebaseAuth.instance.currentUser?.displayName ?? '',
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
        },
      }, context: context);
    } catch (e) {
      _showPaymentError('Unable to start payment: $e');
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final event = widget.event;
    try {
      final verifyPayment =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('verifyPayment');
      await verifyPayment.call({
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
        'eventId': event.id,
        'eventTitle': event.title,
        'hostUid': event.creatorUid,
        'amount': event.price,
        'platformFee': _platformFee,
        'totalAmount': _total,
        'paymentMethod': 'razorpay',
        'fromApproval': widget.fromApproval,
      });

      // Booking is confirmed at this point (verifyPayment adds the uid to
      // attendeeUids server-side). A circle may already exist for this
      // event — if so, add this attendee and let them know, since they'd
      // otherwise never find out it's there.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Someone';
        final existingCircle =
            await EventCircleService.getExistingEventCircle(event.id);
        if (existingCircle != null) {
          await FirebaseFirestore.instance
              .collection('circles')
              .doc(existingCircle.id)
              .update({
            'memberUids': FieldValue.arrayUnion([uid]),
            'memberNames': FieldValue.arrayUnion([userName]),
          });
          await NotificationService.send(
            toUid: uid,
            title: 'Join the circle 👥',
            body:
                'There\'s already a circle for "${event.title}" — jump in and say hi!',
            type: 'social',
            eventId: event.id,
          );
        }
      }

      if (mounted) {
        context.push(AppRoutes.paymentsuccess, extra: {
          'eventTitle': event.title,
          'amount': _total,
          'transactionId': response.paymentId,
          'dateTime': event.dateTime,
          'venue': event.venue,
        });
      }
    } catch (e) {
      _showPaymentError('Payment was received but confirmation failed: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showPaymentError('Payment failed: ${response.message ?? 'Please try again.'}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showPaymentError('External wallet selected: ${response.walletName}');
  }

  void _showPaymentError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateStr =
        DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);

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
              // ── App bar ──
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
                    Text('Confirm & Pay',
                        style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Experience summary card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: TheyDiColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TheyDiColors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title,
                                style: TheyDiTextStyles.headlineMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 14),
                            _detailRow(
                                Icons.calendar_today_outlined, dateStr),
                            const SizedBox(height: 10),
                            _detailRow(Icons.location_on_outlined,
                                '${event.venue}, ${event.city}'),
                          ],
                        ),
                      ).animate(delay: 100.ms).fade(duration: 300.ms).slideY(
                          begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      Text('Price details',
                              style: TheyDiTextStyles.labelLarge)
                          .animate(delay: 180.ms)
                          .fade(duration: 300.ms),
                      const SizedBox(height: 10),

                      // ── Price breakdown card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TheyDiColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TheyDiColors.divider),
                        ),
                        child: Column(
                          children: [
                            _priceRow('Experience price',
                                '₹${event.price.toStringAsFixed(0)}'),
                            const SizedBox(height: 8),
                            _priceRow('Platform fee (10%)',
                                '₹${_platformFee.toStringAsFixed(0)}'),
                            const SizedBox(height: 12),
                            Container(
                                height: 1, color: TheyDiColors.divider),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total',
                                    style: TheyDiTextStyles.labelLarge),
                                Text('₹${_total.toStringAsFixed(0)}',
                                    style: TheyDiTextStyles.displayMedium
                                        .copyWith(
                                            color: TheyDiColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ).animate(delay: 240.ms).fade(duration: 300.ms),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: TheyDiTextStyles.caption
                                .copyWith(color: TheyDiColors.error)),
                      ],

                      const SizedBox(height: 32),

                      // ── Pay button ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _isProcessing
                                ? null
                                : TheyDiColors.gradientPrimary,
                            color: _isProcessing
                                ? Colors.grey[800]
                                : null,
                            boxShadow: _isProcessing
                                ? null
                                : [
                                    BoxShadow(
                                      color: TheyDiColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _confirmAndPay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5),
                                  )
                                : Text(
                                    'Pay ₹${_total.toStringAsFixed(0)}',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(
                                            color: Colors.white,
                                            fontSize: 16)),
                          ),
                        ),
                      ).animate(delay: 300.ms).fade(duration: 300.ms),
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

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TheyDiColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TheyDiTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary)),
        Text(value, style: TheyDiTextStyles.bodySmall),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// DuplicatePaymentSuccessScreen — the content that was previously living
// in this file under the name `PaymentSuccessScreen`, colliding with the
// canonical copy in payment_success_screen.dart. Renamed rather than
// deleted, per request. It is currently unreferenced by any route or
// import — the canonical PaymentSuccessScreen (with the same UI-polish
// pass applied) is the one wired up at AppRoutes.paymentsuccess.
// ══════════════════════════════════════════════════════════════════════════
class DuplicatePaymentSuccessScreen extends StatelessWidget {
  final String eventTitle;
  final double amount;
  final String transactionId;
  final DateTime dateTime;
  final String venue;

  const DuplicatePaymentSuccessScreen({
    super.key,
    required this.eventTitle,
    required this.amount,
    required this.transactionId,
    required this.dateTime,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(dateTime);

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fade(duration: 300.ms),
                const SizedBox(height: 24),
                Text('Booking confirmed!',
                        style: TheyDiTextStyles.displayMedium)
                    .animate(delay: 200.ms)
                    .fade(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  'You\'re all set for this experience',
                  style: TheyDiTextStyles.bodySmall
                      .copyWith(color: TheyDiColors.textSecondary),
                ).animate(delay: 300.ms).fade(duration: 300.ms),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: TheyDiColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TheyDiColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        eventTitle,
                        style: TheyDiTextStyles.headlineMedium,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      _detailRow(Icons.calendar_today_outlined, dateStr),
                      const SizedBox(height: 10),
                      _detailRow(Icons.location_on_outlined, venue),
                      const SizedBox(height: 10),
                      _detailRow(Icons.receipt_outlined, transactionId),
                      const SizedBox(height: 16),
                      Container(height: 1, color: TheyDiColors.divider),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount paid',
                              style: TheyDiTextStyles.bodySmall
                                  .copyWith(color: TheyDiColors.textSecondary)),
                          Text(
                            '₹${amount.toStringAsFixed(0)}',
                            style: TheyDiTextStyles.displayMedium.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    .animate(delay: 400.ms)
                    .fade(duration: 400.ms)
                    .slideY(begin: 0.15, end: 0),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: TheyDiColors.gradientPrimary,
                      boxShadow: [
                        BoxShadow(
                          color: TheyDiColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.myEvents),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'View My Experiences',
                        style: TheyDiTextStyles.labelLarge
                            .copyWith(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ).animate(delay: 550.ms).fade(duration: 300.ms),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TheyDiColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back to Home',
                      style: TheyDiTextStyles.labelMedium
                          .copyWith(color: TheyDiColors.textSecondary),
                    ),
                  ),
                ).animate(delay: 600.ms).fade(duration: 300.ms),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TheyDiColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TheyDiTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}