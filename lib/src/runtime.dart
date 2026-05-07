import 'client.dart';

FeddyClient? _currentClient;

/// Module-level singleton for the live `FeddyClient`. Set by
/// `Feddy.configure(...)`, cleared by `Feddy.reset()`. Mirrors
/// `feddy-react-native/src/runtime.ts`.
FeddyClient? getCurrentClient() => _currentClient;

void setCurrentClient(FeddyClient? client) {
  _currentClient = client;
}
