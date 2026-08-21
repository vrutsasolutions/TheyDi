import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../../../core/services/razorpay_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/payment_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/app_error_utils.dart';
import '../models/booking_model.dart';
import '../models/event_model.dart';

import '../../../core/services/face_verification_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final EventModel event;
  final bool fromApproval;

  const PaymentScreen({
    super.key,
    required this.event,
    this.fromApproval = false,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late RazorpayService _razorpay;

  bool _isProcessing = false;
  bool _paymentFailed = false;
  String _selectedMethod = 'UPI';

  double get _eventPrice => widget.event.price;
  double get _platformFee => BookingModel.calculatePlatformFee(_eventPrice);
  double get _totalAmount => BookingModel.calculateTotal(_eventPrice);

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Razorpay key (loaded once and cached for the life of this screen) ──────
  late final String _keyId = () {
    var k = const String.fromEnvironment('RAZORPAY_KEY_ID');
    if (k.isEmpty) k = dotenv.env['RAZORPAY_KEY_ID'] ?? '';
    return k;
  }();

  bool get _isLiveMode => _keyId.startsWith('rzp_live_');

  // ── Guard: prevent duplicate payment ────────────────────────────────────────
  Future<bool> _alreadyPaid() async {
    if (_myUid.isEmpty) return false;
    final payDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event.id)
        .collection('attendeePayments')
        .doc(_myUid)
        .get(const GetOptions(source: Source.server));
    if (!payDoc.exists) return false;
    return (payDoc.data()?['status'] as String?) == 'paid';
  }

  @override
  void initState() {
    super.initState();
    _razorpay = RazorpayService();
    _razorpay.init(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
      AppErrorUtils.showErrorSnackBar(
          context, response.message ?? 'Payment was cancelled or failed.');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Keep button in loading state during verifyPayment server call
    if (mounted) setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String userName = user.displayName ?? user.email!.split('@').first;
      final verifyPaymentCallable =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('verifyPayment');
      await verifyPaymentCallable.call({
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
        'eventId': widget.event.id,
        'eventTitle': widget.event.title,
        'hostUid': widget.event.creatorUid,
        'amount': _eventPrice,
        'platformFee': _platformFee,
        'totalAmount': _totalAmount,
        'paymentMethod': _selectedMethod,
        'fromApproval': widget.fromApproval,
      });

      final txnId =
          response.paymentId ?? 'TXN${DateTime.now().millisecondsSinceEpoch}';

      // ── Notify host (in-app) ──
      await NotificationService.notifyHostNewAttendeeEmail(
        hostUid: widget.event.creatorUid,
        attendeeName: userName,
        eventTitle: widget.event.title,
        amount: _totalAmount.toStringAsFixed(0),
        eventId: widget.event.id,
      );

      // ── Notify attendee (in-app + email receipt) ──
      await NotificationService.notifyPaymentReceivedEmail(
        userUid: user.uid,
        eventTitle: widget.event.title,
        eventDate:
            DateFormat('EEE, MMM d · h:mm a').format(widget.event.dateTime),
        eventVenue: widget.event.venue,
        amount: _totalAmount.toStringAsFixed(0),
        transactionId: txnId,
        eventId: widget.event.id,
      );

      if (!mounted) return;

      context.pushReplacement(
        AppRoutes.paymentsuccess,
        extra: {
          'eventTitle': widget.event.title,
          'amount': _totalAmount,
          'transactionId': txnId,
          'dateTime': widget.event.dateTime,
          'venue': widget.event.venue,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentFailed = true;
        });
        AppErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _handlePayButton() async {
    // 1. Check if user is face-verified
    final verified = await FaceVerificationService.isUserVerified(_myUid);

    if (!verified) {
      // Show dialog explaining why verification needed
      final goVerify = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: TheyDiColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: TheyDiColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: TheyDiColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verification Required',
                style: TheyDiTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Only verified users can make payments.\nVerify your face now — it takes less than a minute.',
                style: TheyDiTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: TheyDiColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TheyDiColors.warning,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verify Now',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (goVerify != true || !mounted) return;

      // Open face verification
      await context.push(
        AppRoutes.faceVerification,
        extra: {'userId': _myUid},
      );
// Check if verified after returning
      if (!mounted) return;
      final nowVerified = await FaceVerificationService.isUserVerified(_myUid);
      if (nowVerified && mounted) _processPayment();
      return;
    }

    // Already verified — go straight to payment
    _processPayment();
  }

  // ── Process payment ──────────────────────────────────────────────────────────
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _paymentFailed = false;
    });

    try {
      // Duplicate payment guard
      if (await _alreadyPaid()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You have already paid for this event.'),
            backgroundColor: Colors.orange,
          ));
        }
        setState(() => _isProcessing = false);
        return;
      }

      print('--- Starting payment process ---');
      print(
          'Razorpay Key ID loaded: ${_keyId.isNotEmpty} (live: $_isLiveMode)');

      if (_keyId.isEmpty) {
        throw Exception(
            'Razorpay Key ID not found (neither in environment nor in .env)');
      }

      final amountInPaise = (_totalAmount * 100).toInt();
      final user = FirebaseAuth.instance.currentUser!;
      print(
          'Calling createOrder for amount: $amountInPaise, user: ${user.uid}');

      // ── Create Order securely via Backend ──
      final createOrderCallable =
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('createOrder');
      print('Calling function in asia-south1...');
      final response = await createOrderCallable.call({
        'amount': amountInPaise,
        'currency': 'INR',
        'receipt': 'rcptid_${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'eventId': widget.event.id,
          'eventTitle': widget.event.title,
          'userId': user.uid,
          'hostUid': widget.event.creatorUid,
          'platformFee': _platformFee.toString(),
          'totalAmount': _totalAmount.toString(),
          'fromApproval': widget.fromApproval.toString(),
        }
      });
      print('Order created successfully. Response: ${response.data}');

      final orderId = response.data['orderId'];

      var options = {
        'key': _keyId,
        'amount': amountInPaise,
        'order_id': orderId,
        'name': 'TheyDi',
        'description': widget.event.title,
        'image':
            'https://theydi-cefdf.web.app/assets/assets/images/theydi_logo.png',
        'prefill': {'contact': '', 'email': user.email ?? ''},
      };

      print('Opening Razorpay UI...');
      // context is passed through so this also works if Windows/Linux/macOS
      // targets are ever added (razorpay_web requires it there); it's ignored
      // on Android/iOS/Web.
      _razorpay.open(options, context: context);
      // _isProcessing stays true — button remains loading while Razorpay modal is active.
      // Callbacks (_handlePaymentSuccess / _handlePaymentError) manage state from here.
    } catch (e, stackTrace) {
      print('--- PAYMENT LAUNCH ERROR ---');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentFailed = true;
        });
        AppErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(event.dateTime);

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
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: TheyDiColors.textPrimary),
                      onPressed: _isProcessing ? null : () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Checkout', style: TheyDiTextStyles.displayMedium),
                  ],
                ),
              ).animate().fade(duration: 300.ms),

              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Approval context banner ──
                    if (widget.fromApproval) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.verified_user_outlined,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your request was approved! Complete payment to confirm your spot.',
                              style: TheyDiTextStyles.bodySmall.copyWith(
                                  color: TheyDiColors.textSecondary,
                                  height: 1.4),
                            ),
                          ),
                        ]),
                      ).animate().fade(duration: 300.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Event summary card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TheyDiColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: TheyDiColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                event.category.isNotEmpty
                                    ? event.category[0]
                                    : 'E',
                                style: TheyDiTextStyles.displayMedium
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title,
                                    style: TheyDiTextStyles.labelLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(dateStr, style: TheyDiTextStyles.caption),
                                const SizedBox(height: 2),
                                Text(event.venue,
                                    style: TheyDiTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fade(duration: 400.ms),

                    const SizedBox(height: 24),

                    // ── Payment method ──
                    Text('Payment method', style: TheyDiTextStyles.labelLarge)
                        .animate(delay: 150.ms)
                        .fade(duration: 300.ms),
                    const SizedBox(height: 12),

                    ...List.generate(PaymentConstants.paymentMethods.length,
                        (index) {
                      final method = PaymentConstants.paymentMethods[index];
                      final isSelected = method['name'] == _selectedMethod;
                      return GestureDetector(
                        onTap: _isProcessing
                            ? null
                            : () => setState(
                                () => _selectedMethod = method['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: TheyDiColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? TheyDiColors.primary
                                  : TheyDiColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(method['icon'] as IconData,
                                  color: isSelected
                                      ? TheyDiColors.primary
                                      : TheyDiColors.textMuted,
                                  size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(method['name'] as String,
                                        style: TheyDiTextStyles.labelMedium),
                                    Text(method['desc'] as String,
                                        style: TheyDiTextStyles.caption),
                                  ],
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? TheyDiColors.primary
                                        : TheyDiColors.textMuted,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: TheyDiColors.primary,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate(
                              delay: Duration(milliseconds: 200 + 50 * index))
                          .fade(duration: 300.ms);
                    }),

                    const SizedBox(height: 24),

                    // ── Price breakdown ──
                    Text('Price breakdown', style: TheyDiTextStyles.labelLarge)
                        .animate(delay: 350.ms)
                        .fade(duration: 300.ms),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TheyDiColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Column(
                        children: [
                          _priceRow('Event ticket',
                              '₹${_eventPrice.toStringAsFixed(0)}'),
                          const SizedBox(height: 10),
                          _priceRow('Platform fee (10%)',
                              '₹${_platformFee.toStringAsFixed(0)}'),
                          const SizedBox(height: 12),
                          Container(height: 1, color: TheyDiColors.divider),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: TheyDiTextStyles.labelLarge),
                              Text('₹${_totalAmount.toStringAsFixed(0)}',
                                  style: TheyDiTextStyles.displayMedium
                                      .copyWith(color: TheyDiColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ).animate(delay: 400.ms).fade(duration: 300.ms),

                    const SizedBox(height: 12),

                    // ── Payment failure retry banner ──
                    if (_paymentFailed)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Payment failed. Please try again or choose a different method.',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: Colors.red),
                            ),
                          ),
                        ]),
                      ),

                    // ── Live/Sandbox notice ──
                    if (!_paymentFailed)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isLiveMode ? Colors.green : Colors.amber)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: (_isLiveMode ? Colors.green : Colors.amber)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Icon(
                            _isLiveMode
                                ? Icons.lock_outline
                                : Icons.info_outline,
                            color: _isLiveMode ? Colors.green : Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLiveMode
                                  ? 'Live mode — real payments will be charged'
                                  : 'Sandbox mode — no real money will be charged',
                              style: TheyDiTextStyles.caption.copyWith(
                                  color: _isLiveMode
                                      ? Colors.green
                                      : Colors.amber),
                            ),
                          ),
                        ]),
                      ).animate(delay: 450.ms).fade(duration: 300.ms),

                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // ── Pay button ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: TheyDiColors.dark,
                  border: Border(top: BorderSide(color: TheyDiColors.divider)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient:
                          _isProcessing ? null : TheyDiColors.gradientPrimary,
                      color: _isProcessing ? Colors.grey[800] : null,
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePayButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                ),
                                const SizedBox(width: 12),
                                Text('Processing payment...',
                                    style: TheyDiTextStyles.labelLarge
                                        .copyWith(color: Colors.white)),
                              ],
                            )
                          : Text(
                              _paymentFailed
                                  ? 'Retry Payment ₹${_totalAmount.toStringAsFixed(0)}'
                                  : 'Pay ₹${_totalAmount.toStringAsFixed(0)}',
                              style: TheyDiTextStyles.labelLarge
                                  .copyWith(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TheyDiTextStyles.bodySmall
                .copyWith(color: TheyDiColors.textSecondary)),
        Text(amount, style: TheyDiTextStyles.labelMedium),
      ],
    );
  }
}
