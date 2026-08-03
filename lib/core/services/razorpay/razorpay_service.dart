/// Platform-aware entry point for Razorpay.
/// On Web:    uses razorpay_web_impl.dart  (razorpay_web package)
/// On Mobile: uses razorpay_mobile.dart    (razorpay_flutter package)
/// Fallback:  uses razorpay_stub.dart      (throws UnsupportedError)
export 'razorpay_stub.dart'
    if (dart.library.html) 'razorpay_web_impl.dart'
    if (dart.library.io) 'razorpay_mobile.dart';
