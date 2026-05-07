import 'client.dart';
import 'iap_stream_listener.dart';

FeddyClient? _currentClient;
IapStreamListener? _currentIapListener;

/// Module-level singleton for the live `FeddyClient`. Set by
/// `Feddy.configure(...)`, cleared by `Feddy.reset()`. Mirrors
/// `feddy-react-native/src/runtime.ts`.
FeddyClient? getCurrentClient() => _currentClient;

void setCurrentClient(FeddyClient? client) {
  _currentClient = client;
}

/// Module-level singleton for the Android IAP stream listener. Only
/// non-null on Android when `autoDetectSubscription` is enabled. iOS
/// runs detection on demand without a long-lived listener.
IapStreamListener? getCurrentIapListener() => _currentIapListener;

void setCurrentIapListener(IapStreamListener? listener) {
  _currentIapListener = listener;
}
