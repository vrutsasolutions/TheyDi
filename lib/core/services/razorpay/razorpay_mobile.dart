/// Mobile implementation — wraps razorpay_flutter (Android/iOS).
import 'package:razorpay_flutter/razorpay_flutter.dart';

export 'package:razorpay_flutter/razorpay_flutter.dart'
    show PaymentSuccessResponse, PaymentFailureResponse, ExternalWalletResponse;

typedef PaymentSuccessHandler = void Function(PaymentSuccessResponse response);
typedef PaymentFailureHandler = void Function(PaymentFailureResponse response);
typedef ExternalWalletHandler = void Function(ExternalWalletResponse response);

class RazorpayService {
  final Razorpay _razorpay = Razorpay();

  void init({
    required PaymentSuccessHandler onSuccess,
    required PaymentFailureHandler onError,
    required ExternalWalletHandler onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  void open(Map<String, dynamic> options) {
    _razorpay.open(options);
  }

  void clear() {
    _razorpay.clear();
  }
}
