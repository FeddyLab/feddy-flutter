import 'package:flutter/foundation.dart';

/// Smart Review pre-prompt sheet state. Mirrors
/// `feddy-react-native/src/smart-review/ui-state.ts`.
class SmartReviewUiState extends ChangeNotifier {
  bool _visible = false;
  String? _trigger;
  String? _boardKey;
  VoidCallback? _onLiked;
  VoidCallback? _onDisliked;
  VoidCallback? _onStoreConfirmed;
  VoidCallback? _onStoreDismissed;
  VoidCallback? _onSheetDismissedBeforeChoice;

  bool get visible => _visible;
  String? get trigger => _trigger;
  String? get boardKey => _boardKey;

  void open({
    String? trigger,
    String? boardKey,
    required VoidCallback onLiked,
    required VoidCallback onDisliked,
    required VoidCallback onStoreConfirmed,
    required VoidCallback onStoreDismissed,
    required VoidCallback onSheetDismissedBeforeChoice,
  }) {
    _visible = true;
    _trigger = trigger;
    _boardKey = boardKey;
    _onLiked = onLiked;
    _onDisliked = onDisliked;
    _onStoreConfirmed = onStoreConfirmed;
    _onStoreDismissed = onStoreDismissed;
    _onSheetDismissedBeforeChoice = onSheetDismissedBeforeChoice;
    notifyListeners();
  }

  void close() {
    _visible = false;
    _trigger = null;
    _boardKey = null;
    _onLiked = null;
    _onDisliked = null;
    _onStoreConfirmed = null;
    _onStoreDismissed = null;
    _onSheetDismissedBeforeChoice = null;
    notifyListeners();
  }

  /// Non-terminal — user picked "like" in step 1. The sheet stays on
  /// screen and transitions internally to step 2.
  void emitLiked() => _onLiked?.call();

  /// Terminal — user picked "not really" in step 1.
  void emitDisliked() => _onDisliked?.call();

  /// Terminal — user confirmed in step 2; trigger native review prompt.
  void emitStoreConfirmed() => _onStoreConfirmed?.call();

  /// Terminal — user reached step 2 but declined to rate now.
  void emitStoreDismissed() => _onStoreDismissed?.call();

  /// Terminal — user dragged the sheet away in step 1 without choosing.
  void emitSheetDismissedBeforeChoice() =>
      _onSheetDismissedBeforeChoice?.call();
}

final SmartReviewUiState smartReviewUiState = SmartReviewUiState();
