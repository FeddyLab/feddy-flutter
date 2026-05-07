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

/// Imperative entry point for `Feddy.requestReviewIfAppropriate(...)`.
/// Mirrors RN's `requestReviewIfAppropriate` 1:1 — same gates, same
/// telemetry stages, same rate-routing logic.
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
    onRated: (stars) {
      smartReviewUiState.close();
      logReviewEvent(
        client,
        stage: ReviewPromptStage.rated,
        rating: stars,
        trigger: trigger,
      );
      if (stars >= 4) {
        logReviewEvent(
          client,
          stage: ReviewPromptStage.routedStore,
          rating: stars,
          trigger: trigger,
        );
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
      } else {
        logReviewEvent(
          client,
          stage: ReviewPromptStage.routedFeedback,
          rating: stars,
          trigger: trigger,
        );
        composeUiState.open(boardKey: opts.boardKey);
      }
    },
    onCancel: () {
      smartReviewUiState.close();
      // No event logged — sheet was dismissed without a rating.
    },
  );
}

Future<void> resetSmartReviewState() async {
  await store.clearAll();
  await clearConfigCache();
}
