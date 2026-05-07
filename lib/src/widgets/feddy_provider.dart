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
    await showModalBottomSheet<void>(
      context: navigator.context,
      isScrollControlled: true,
      builder: (_) => SmartReviewSheet(
        onRated: (stars) {
          smartReviewUiState.emitRated(stars);
        },
        onCancel: () {
          Navigator.of(navigator.context).pop();
          smartReviewUiState.emitCancelled();
        },
      ),
    );
    if (smartReviewUiState.visible) {
      // Sheet dismissed via swipe / scrim tap rather than the
      // "Not now" button — surface that as a cancel.
      smartReviewUiState.emitCancelled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
