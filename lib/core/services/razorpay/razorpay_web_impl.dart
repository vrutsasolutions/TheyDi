/// Web implementation — wraps razorpay_web (Chrome/Safari/Firefox).
import 'package:razorpay_web/razorpay_web.dart';

export 'package:razorpay_web/razorpay_web.dart'
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
