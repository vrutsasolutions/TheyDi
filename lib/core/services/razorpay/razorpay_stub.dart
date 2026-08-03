/// Stub implementation — fallback for non-mobile, non-web platforms.
/// This class is never actually instantiated on supported platforms.

/// Shared response types (mirrored from razorpay_flutter / razorpay_web).
class PaymentSuccessResponse {
  final String? paymentId;
  final String? orderId;
  final String? signature;
  const PaymentSuccessResponse(this.paymentId, this.orderId, this.signature);
}

class PaymentFailureResponse {
  final dynamic code;
  final String? message;
  const PaymentFailureResponse(this.code, this.message);
}

class ExternalWalletResponse {
  final String? walletName;
  const ExternalWalletResponse(this.walletName);
}

typedef PaymentSuccessHandler = void Function(PaymentSuccessResponse response);
typedef PaymentFailureHandler = void Function(PaymentFailureResponse response);
typedef ExternalWalletHandler = void Function(ExternalWalletResponse response);

class RazorpayService {
  void init({
    required PaymentSuccessHandler onSuccess,
    required PaymentFailureHandler onError,
    required ExternalWalletHandler onExternalWallet,
  }) {
    throw UnsupportedError('Razorpay is not supported on this platform.');
  }

  void open(Map<String, dynamic> options) {
    throw UnsupportedError('Razorpay is not supported on this platform.');
  }

  void clear() {}
}
