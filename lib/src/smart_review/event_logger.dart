import '../client.dart';
import '../identity.dart';

enum ReviewPromptStage { shown, rated, routedStore, routedFeedback }

extension ReviewPromptStageWire on ReviewPromptStage {
  String get wireValue {
    switch (this) {
      case ReviewPromptStage.shown:
        return 'shown';
      case ReviewPromptStage.rated:
        return 'rated';
      case ReviewPromptStage.routedStore:
        return 'routed_store';
      case ReviewPromptStage.routedFeedback:
        return 'routed_feedback';
    }
  }
}

/// Funnel telemetry for Smart Review. Fire-and-forget — failures
/// are logged and dropped. Telemetry must never affect the user's
/// prompt experience.
void logReviewEvent(
  FeddyClient client, {
  required ReviewPromptStage stage,
  int? rating,
  String? trigger,
}) {
  Future<void>(() async {
    try {
      final externalUserId = await getLastExternalUserId();
      final anonymousToken =
          externalUserId == null ? await getAnonymousToken() : null;
      await client.post('/v1/review-prompt-events', {
        if (externalUserId != null) 'external_user_id': externalUserId,
        if (anonymousToken != null) 'anonymous_token': anonymousToken,
        'stage': stage.wireValue,
        if (rating != null) 'rating': rating,
        if (trigger != null) 'trigger': trigger,
      });
    } catch (e) {
      // ignore: avoid_print
      print(
        "[Feddy] SmartReview event '${stage.wireValue}' upload failed — $e",
      );
    }
  });
}
