import 'package:flutter/foundation.dart';

/// State container for the bundled compose modal. Mirrors
/// `feddy-react-native/src/ui-state.ts`. The host's `FeddyProvider`
/// listens and renders / dismisses `FeedbackComposeView` accordingly.
class ComposeUiState extends ChangeNotifier {
  bool _visible = false;
  String? _boardKey;

  bool get visible => _visible;
  String? get boardKey => _boardKey;

  void open({String? boardKey}) {
    _visible = true;
    _boardKey = boardKey;
    notifyListeners();
  }

  void close() {
    _visible = false;
    _boardKey = null;
    notifyListeners();
  }
}

/// Module-level singleton — `Feddy.openFeedback(...)` triggers it,
/// `FeddyProvider` listens.
final ComposeUiState composeUiState = ComposeUiState();
