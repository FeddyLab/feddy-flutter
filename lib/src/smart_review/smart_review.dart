import 'package:in_app_review/in_app_review.dart';

import '../runtime.dart';
import '../ui_state.dart';
import 'config_fetcher.dart';
import 'engine.dart';
import 'event_logger.dart';
import 'store.dart' as store;
import 'ui_state.dart';

class RequestReviewOptions {
  final String? boardKey;
  final String? trigger;
  final bool bypassGates;

  const RequestReviewOptions({
    this.boardKey,
    this.trigger,
    this.bypassGates = false,
  });
}

String? _normalizeTrigger(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
}

void _invokeInAppReview() {
  Future<void>(() async {
    try {
      final reviewer = InAppReview.instance;
      if (await reviewer.isAvailable()) {
        await reviewer.requestReview();
      } else {
        // ignore: avoid_print
        print('[Feddy] in_app_review not available on this device');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Feddy] in_app_review failed — $e');
    }
  });
}

/// Imperative entry point for `Feddy.requestReviewIfAppropriate(...)`.
/// Mirrors the iOS / RN SDKs 1:1 — same gates, same telemetry stages,
/// same two-step like / dislike UI.
Future<void> requestReviewIfAppropriate(RequestReviewOptions opts) async {
  final client = getCurrentClient();
  if (client == null) {
    // ignore: avoid_print
    print(
      '[Feddy] requestReviewIfAppropriate called before configure — ignoring',
    );
    return;
  }

  final trigger = _normalizeTrigger(opts.trigger);
  refreshConfigInBackground(client);

  if (!opts.bypassGates) {
    final state = await store.snapshot();
    final rules = await currentRules();
    final decision = evaluate(
      DateTime.now().millisecondsSinceEpoch,
      state,
      rules,
    );
    if (decision is! ShowDecision) {
      // ignore: avoid_print
      print('[Feddy] SmartReview skipped — ${decision.kind}');
      return;
    }
  }

  await store.markShown();
  logReviewEvent(client, stage: ReviewPromptStage.shown, trigger: trigger);

  smartReviewUiState.open(
    trigger: trigger,
    boardKey: opts.boardKey,
    onLiked: () {
      // Non-terminal: sheet stays open and transitions to step 2.
      logReviewEvent(
        client,
        stage: ReviewPromptStage.liked,
        trigger: trigger,
      );
    },
    onDisliked: () {
      smartReviewUiState.close();
      logReviewEvent(
        client,
        stage: ReviewPromptStage.disliked,
        trigger: trigger,
      );
      logReviewEvent(
        client,
        stage: ReviewPromptStage.routedFeedback,
        trigger: trigger,
      );
      composeUiState.open(boardKey: opts.boardKey);
    },
    onStoreConfirmed: () {
      smartReviewUiState.close();
      logReviewEvent(
        client,
        stage: ReviewPromptStage.routedStore,
        trigger: trigger,
      );
      _invokeInAppReview();
    },
    onStoreDismissed: () {
      smartReviewUiState.close();
      logReviewEvent(
        client,
        stage: ReviewPromptStage.dismissedStoreConfirm,
        trigger: trigger,
      );
    },
    onSheetDismissedBeforeChoice: () {
      smartReviewUiState.close();
      logReviewEvent(
        client,
        stage: ReviewPromptStage.dismissed,
        trigger: trigger,
      );
    },
  );
}

Future<void> resetSmartReviewState() async {
  await store.clearAll();
  await clearConfigCache();
}
