import 'package:in_app_review/in_app_review.dart';

import '../runtime.dart';
import 'event_logger.dart';

class RequestSystemReviewDirectOptions {
  /// Caller-defined label that identifies where in your app this
  /// prompt fired from — e.g. `"paywall_purchase_success"`.
  /// Surfaces in the dashboard funnel. Trimmed and capped at 100
  /// characters; empty / whitespace → null.
  final String? trigger;

  const RequestSystemReviewDirectOptions({this.trigger});
}

String? _normalizeTrigger(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
}

/// Imperative entry point for
/// `Feddy.requestSystemReviewDirect(trigger: ...)`. Bypasses the
/// Smart Review like / dislike pre-prompt and invokes
/// `in_app_review.requestReview()` immediately. Use only for
/// moments where the host has already established positive
/// sentiment (e.g. immediately after a paywall purchase succeeds).
///
/// Deliberately does NOT consult or update SmartReview state — the
/// install-age / session / cooldown / yearly-cap gates belong to
/// the shield flow only. Apple / Google opaque per-app yearly caps
/// still apply; that judgement is on the host.
Future<void> requestSystemReviewDirect(
  RequestSystemReviewDirectOptions opts,
) async {
  final client = getCurrentClient();
  if (client == null) {
    // ignore: avoid_print
    print(
      '[Feddy] requestSystemReviewDirect called before configure — ignoring',
    );
    return;
  }

  final trigger = _normalizeTrigger(opts.trigger);

  try {
    final reviewer = InAppReview.instance;
    if (!await reviewer.isAvailable()) {
      // ignore: avoid_print
      print('[Feddy] in_app_review not available on this device');
      return;
    }
    await reviewer.requestReview();
    logReviewEvent(
      client,
      stage: ReviewPromptStage.systemDirect,
      trigger: trigger,
    );
  } catch (e) {
    // ignore: avoid_print
    print('[Feddy] in_app_review failed — $e');
  }
}
