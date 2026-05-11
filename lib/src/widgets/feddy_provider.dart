import 'package:flutter/material.dart';

import '../smart_review/ui_state.dart';
import '../ui_state.dart';
import 'feedback_compose_view.dart';
import 'smart_review_sheet.dart';

/// Mount once at the root of your app. Listens to the SDK's UI state
/// and renders the bundled compose modal / Smart Review sheet on
/// top of the host's widget tree, so `Feddy.openFeedback()` and
/// `Feddy.requestReviewIfAppropriate()` Just Work.
///
/// ```dart
/// runApp(const FeddyProvider(child: MyApp()));
/// ```
class FeddyProvider extends StatefulWidget {
  final Widget child;
  const FeddyProvider({super.key, required this.child});

  @override
  State<FeddyProvider> createState() => _FeddyProviderState();
}

class _FeddyProviderState extends State<FeddyProvider> {
  bool _composeShown = false;
  bool _smartReviewShown = false;

  @override
  void initState() {
    super.initState();
    composeUiState.addListener(_onComposeChanged);
    smartReviewUiState.addListener(_onSmartReviewChanged);
  }

  @override
  void dispose() {
    composeUiState.removeListener(_onComposeChanged);
    smartReviewUiState.removeListener(_onSmartReviewChanged);
    super.dispose();
  }

  void _onComposeChanged() {
    if (!mounted) return;
    if (composeUiState.visible && !_composeShown) {
      _composeShown = true;
      _presentCompose();
    } else if (!composeUiState.visible) {
      _composeShown = false;
    }
  }

  void _onSmartReviewChanged() {
    if (!mounted) return;
    if (smartReviewUiState.visible && !_smartReviewShown) {
      _smartReviewShown = true;
      _presentSmartReview();
    } else if (!smartReviewUiState.visible) {
      _smartReviewShown = false;
    }
  }

  Future<void> _presentCompose() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FeedbackComposeView(
          boardKey: composeUiState.boardKey,
          onDismiss: composeUiState.close,
        ),
        fullscreenDialog: true,
      ),
    );
    composeUiState.close();
  }

  Future<void> _presentSmartReview() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var terminalFired = false;
    var likedTransitioned = false;
    await showModalBottomSheet<void>(
      context: navigator.context,
      isScrollControlled: true,
      builder: (sheetContext) => SmartReviewSheet(
        onLiked: () {
          // Non-terminal: sheet transitions internally to step 2.
          // Do NOT pop; just notify the consumer.
          likedTransitioned = true;
          smartReviewUiState.emitLiked();
        },
        onDisliked: () {
          terminalFired = true;
          Navigator.of(sheetContext).pop();
          smartReviewUiState.emitDisliked();
        },
        onStoreConfirmed: () {
          // Pop the sheet first so it's already gone by the time the
          // system review prompt animates in.
          terminalFired = true;
          Navigator.of(sheetContext).pop();
          smartReviewUiState.emitStoreConfirmed();
        },
        onStoreDismissed: () {
          terminalFired = true;
          Navigator.of(sheetContext).pop();
          smartReviewUiState.emitStoreDismissed();
        },
      ),
    );
    if (!terminalFired && smartReviewUiState.visible) {
      // Sheet dismissed via swipe / scrim tap rather than a button.
      // Route based on whether the user already crossed into step 2.
      if (likedTransitioned) {
        smartReviewUiState.emitStoreDismissed();
      } else {
        smartReviewUiState.emitSheetDismissedBeforeChoice();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
