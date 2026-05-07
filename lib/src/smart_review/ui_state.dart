import 'package:flutter/foundation.dart';

/// Smart Review pre-prompt sheet state. Mirrors
/// `feddy-react-native/src/smart-review/ui-state.ts`.
class SmartReviewUiState extends ChangeNotifier {
  bool _visible = false;
  String? _trigger;
  String? _boardKey;
  void Function(int stars)? _onRated;
  VoidCallback? _onCancel;

  bool get visible => _visible;
  String? get trigger => _trigger;
  String? get boardKey => _boardKey;

  void open({
    String? trigger,
    String? boardKey,
    required void Function(int stars) onRated,
    required VoidCallback onCancel,
  }) {
    _visible = true;
    _trigger = trigger;
    _boardKey = boardKey;
    _onRated = onRated;
    _onCancel = onCancel;
    notifyListeners();
  }

  void close() {
    _visible = false;
    _trigger = null;
    _boardKey = null;
    _onRated = null;
    _onCancel = null;
    notifyListeners();
  }

  /// Triggered by the sheet when the user picks a star rating.
  void emitRated(int stars) {
    _onRated?.call(stars);
  }

  /// Triggered by the sheet when the user dismisses without rating.
  void emitCancelled() {
    _onCancel?.call();
  }
}

final SmartReviewUiState smartReviewUiState = SmartReviewUiState();
