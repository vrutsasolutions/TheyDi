// core/services/razorpay/razorpay_service.dart
import 'package:flutter/widgets.dart';
import 'package:razorpay_web/razorpay_web.dart';

export 'package:razorpay_web/razorpay_web.dart'
    show PaymentSuccessResponse, PaymentFailureResponse, ExternalWalletResponse;

class RazorpayService {
  late Razorpay _razorpay;

  void init({
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
    required void Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void open(Map<String, dynamic> options, {BuildContext? context}) {
    _razorpay.open(options, context: context);
  }

  void clear() {
    _razorpay.clear();
  }
}