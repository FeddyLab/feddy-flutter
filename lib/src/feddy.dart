import 'client.dart';
import 'feddy_error.dart';
import 'identity.dart';
import 'runtime.dart';
import 'smart_review/smart_review.dart' as smart_review;
import 'smart_review/store.dart' as smart_review_store;
import 'submit_queue.dart';
import 'subscription_store.dart';
import 'system_boards.dart';
import 'types.dart';
import 'ui_state.dart';

/// Public namespace for the Feddy Flutter SDK.
///
/// ```dart
/// // 1. Once at app launch:
/// Feddy.configure(apiKey: 'fed_xxxxxxxxxxxx');
///
/// // 2. After your auth handler runs:
/// Feddy.identify(userId: 'user_42', email: 'a@b.com');
///
/// // 3. Anywhere a "share feedback" CTA fires:
/// Feddy.submitRequest(title: 'Add dark mode', boardKey: 'features');
/// ```
///
/// All fire-and-forget methods (`configure` / `identify` /
/// `submitRequest` / `setSubscription` / `refreshSubscription` /
/// `reset` / `openFeedback`) are synchronous from the call site —
/// failures are logged via `print` and the caller never has to
/// `await` or `try`.
abstract final class Feddy {
  Feddy._();

  /// Configure the SDK once at app launch with your **Project ID**
  /// (`fed_xxxxxxxxxxxx`, copied from your Feddy dashboard).
  ///
  /// Invalid IDs (wrong prefix, empty, or a server `fed_sk_*` key)
  /// are rejected with a console log; subsequent calls to
  /// `identify` / `submitRequest` will silently no-op.
  ///
  /// - [autoDetectSubscription] is reserved for a future v0.2 release
  ///   where host apps can pass `iapProductIds` to opt into automatic
  ///   StoreKit / Play Billing detection. In v0.1 the SDK does **not**
  ///   auto-detect — host apps push state via [setSubscription].
  /// - [boardTranslations] supplies per-locale display names for
  ///   custom (non `features` / `bugs`) board keys. System keys are
  ///   always pulled from the SDK's bundled catalog.
  static void configure({
    required String apiKey,
    String? baseUrl,
    bool autoDetectSubscription = true,
    BoardTranslations? boardTranslations,
  }) {
    try {
      final client = FeddyClient.create(
        apiKey: apiKey,
        baseUrl: baseUrl,
        autoDetectSubscription: autoDetectSubscription,
      );
      setCurrentClient(client);
      setBoardTranslations(boardTranslations);
      // Bump the Smart Review session counter once per configure —
      // single source of truth, no foreground-notification dance.
      Future<void>(() async {
        try {
          await smart_review_store.bumpSession();
        } catch (err) {
          _logError('configure.bumpSession', err);
        }
      });
      // Drain any submits that failed to reach the server during a
      // previous launch (kill while offline, server outage, etc).
      Future<void>(() async {
        try {
          await replayQueue(client);
        } catch (err) {
          _logError('configure.replayQueue', err);
        }
      });
    } catch (err) {
      _logError('configure', err);
    }
  }

  /// Identify the current end user. Call from your auth handler with
  /// whatever fields you already have. All fields are optional;
  /// when none are passed, the SDK falls back to a per-install
  /// anonymous token so writes still attribute correctly.
  static void identify({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) {
    final client = getCurrentClient();
    if (client == null) {
      // ignore: avoid_print
      print('[Feddy] identify called before configure — ignoring');
      return;
    }
    Future<void>(() async {
      try {
        if (userId != null) {
          await setLastExternalUserId(userId);
        }
        final anonymousToken =
            userId == null ? await getAnonymousToken() : null;
        final subscription = await getEffectiveSubscription();
        final response = await client.post('/v1/identify', {
          if (userId != null) 'external_user_id': userId,
          if (anonymousToken != null) 'anonymous_token': anonymousToken,
          if (email != null) 'email': email,
          if (displayName != null) 'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (subscription != null) 'subscription': subscription.toJson(),
        });
        await setAttachmentsEnabled(
          response?['attachments_enabled'] as bool? ?? false,
        );
      } catch (err) {
        _logError('identify', err);
      }
    });
  }

  /// Submit a feedback / feature request / bug report on behalf of
  /// the current end user. Fire-and-forget: errors are logged.
  static void submitRequest({
    required String title,
    String? description,
    String? boardKey,
  }) {
    final client = getCurrentClient();
    if (client == null) {
      // ignore: avoid_print
      print('[Feddy] submitRequest called before configure — ignoring');
      return;
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      // ignore: avoid_print
      print('[Feddy] submitRequest title must not be empty');
      return;
    }
    Future<void>(() async {
      final externalUserId = await getLastExternalUserId();
      final anonymousToken =
          externalUserId == null ? await getAnonymousToken() : null;
      final desc = description?.trim();
      final body = <String, dynamic>{
        if (externalUserId != null) 'external_user_id': externalUserId,
        if (anonymousToken != null) 'anonymous_token': anonymousToken,
        'title': trimmed,
        if (desc != null && desc.isNotEmpty) 'description': desc,
        if (boardKey != null) 'board_key': boardKey,
      };
      try {
        await client.post('/v1/requests', body);
      } on FeddyError catch (err) {
        // Network failure → persist for replay on next configure().
        // HTTP 4xx/5xx (server-validated rejection) is logged but
        // NOT queued — the body is invalid and retries would loop
        // forever.
        if (err.code == FeddyErrorCode.network) {
          try {
            await enqueueSubmit(body);
            // ignore: avoid_print
            print(
              '[Feddy] submitRequest offline — queued for retry on next configure()',
            );
          } catch (qErr) {
            _logError('submitRequest.enqueue', qErr);
          }
          return;
        }
        _logError('submitRequest', err);
      } catch (err) {
        _logError('submitRequest', err);
      }
    });
  }

  /// Override the subscription snapshot the SDK attaches to the
  /// next [identify] call. Use when your app's source-of-truth for
  /// paid state is RevenueCat / Adapty / your own server.
  ///
  /// Pass `null` to clear the override.
  ///
  /// Persists across launches via `shared_preferences`.
  static void setSubscription(Subscription? subscription) {
    Future<void>(() async {
      try {
        await setStoredSubscription(subscription);
      } catch (err) {
        _logError('setSubscription', err);
      }
    });
  }

  /// Re-read the host app's currently-active subscription. Reserved
  /// for v0.2 — in v0.1 this is a no-op since the SDK does not
  /// auto-detect IAP entitlements. The manual override set via
  /// [setSubscription] is unaffected.
  ///
  /// Provided as a stable surface so host code written today
  /// continues to compile when v0.2 lights up auto-detection.
  static void refreshSubscription() {
    // Intentionally empty in v0.1 — see docstring.
  }

  /// Present the built-in feedback compose modal. Requires
  /// `FeddyProvider` mounted at your app root.
  static void openFeedback({String? boardKey}) {
    if (getCurrentClient() == null) {
      // ignore: avoid_print
      print('[Feddy] openFeedback called before configure — ignoring');
      return;
    }
    composeUiState.open(boardKey: boardKey);
  }

  /// Ask the SDK to consider showing a Smart Review prompt right now.
  /// Call from any "user just had a good moment" hook — onboarding
  /// completed, save succeeded, level cleared, etc. Built-in gates
  /// decide whether to actually present anything (≥7 days install,
  /// ≥5 sessions, ≥90d cooldown, ≤3 prompts per 365d window).
  ///
  /// 4-5 stars route to the system review prompt via `in_app_review`;
  /// 1-3 stars route to the built-in compose modal so the feedback
  /// is captured privately instead of as a public 1-3 star review.
  static void requestReviewIfAppropriate({
    String? boardKey,
    String? trigger,
    bool bypassGates = false,
  }) {
    Future<void>(() async {
      try {
        await smart_review.requestReviewIfAppropriate(
          smart_review.RequestReviewOptions(
            boardKey: boardKey,
            trigger: trigger,
            bypassGates: bypassGates,
          ),
        );
      } catch (err) {
        _logError('requestReviewIfAppropriate', err);
      }
    });
  }

  /// **Debug only.** Clears the Smart Review counters
  /// (install date / session count / last-shown / yearly counter).
  /// Calling this in production lets users see the prompt more often
  /// than designed; the App Store / Play Store also throttle
  /// independently.
  static void resetSmartReviewState() {
    Future<void>(() async {
      try {
        await smart_review.resetSmartReviewState();
      } catch (err) {
        _logError('resetSmartReviewState', err);
      }
    });
  }

  /// Drop the current configuration and forget the last identified
  /// user. The anonymous token is intentionally **not** cleared so
  /// subsequent writes from the same install still link to any
  /// pre-existing anonymous history.
  static void reset() {
    setCurrentClient(null);
    clearBoardTranslations();
    Future<void>(() async {
      try {
        await setLastExternalUserId(null);
      } catch (err) {
        _logError('reset.identity', err);
      }
      try {
        await clearStoredSubscription();
        await clearAutoDetectedSubscription();
      } catch (err) {
        _logError('reset.subscription', err);
      }
      try {
        await clearQueue();
      } catch (err) {
        _logError('reset.queue', err);
      }
    });
  }

  static void _logError(String scope, Object err) {
    // ignore: avoid_print
    print('[Feddy] $scope failed — $err');
  }
}

/// Internal accessor exposed to other layers (boards / read API /
/// smart review) that need the live client without going through the
/// public surface. Not part of the public API.
FeddyClient requireClientForInternal(String scope) {
  final client = getCurrentClient();
  if (client == null) {
    throw FeddyError(
      code: FeddyErrorCode.notConfigured,
      message: 'Feddy.$scope called before Feddy.configure(...)',
    );
  }
  return client;
}
