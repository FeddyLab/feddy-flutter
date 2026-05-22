import '../client.dart';
import '../identity.dart';

enum ReviewPromptStage {
  shown,
  liked,
  disliked,
  routedStore,
  routedFeedback,
  dismissedStoreConfirm,
  dismissed,
  systemDirect,
}

extension ReviewPromptStageWire on ReviewPromptStage {
  String get wireValue {
    switch (this) {
      case ReviewPromptStage.shown:
        return 'shown';
      case ReviewPromptStage.liked:
        return 'liked';
      case ReviewPromptStage.disliked:
        return 'disliked';
      case ReviewPromptStage.routedStore:
        return 'routed_store';
      case ReviewPromptStage.routedFeedback:
        return 'routed_feedback';
      case ReviewPromptStage.dismissedStoreConfirm:
        return 'dismissed_store_confirm';
      case ReviewPromptStage.dismissed:
        return 'dismissed';
      case ReviewPromptStage.systemDirect:
        return 'system_direct';
    }
  }
}

/// Funnel telemetry for Smart Review. Fire-and-forget — failures
/// are logged and dropped. Telemetry must never affect the user's
/// prompt experience.
void logReviewEvent(
  FeddyClient client, {
  required ReviewPromptStage stage,
  String? trigger,
}) {
  Future<void>(() async {
    try {
      final externalUserId = await getLastExternalUserId();
      final anonymousToken = externalUserId == null
          ? await getAnonymousToken()
          : null;
      await client.post('/v1/review-prompt-events', {
        if (externalUserId != null) 'external_user_id': externalUserId,
        if (anonymousToken != null) 'anonymous_token': anonymousToken,
        'stage': stage.wireValue,
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
