import 'dart:async';
import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'iap_detector.dart' show pickHighestPriority;
import 'types.dart';

/// `originalJson` from Play Billing carries `autoRenewing` only on
/// subscription purchases. One-time / consumable purchases lack the
/// field. We use this as a best-effort subscription filter — when
/// the JSON parses cleanly and `autoRenewing` is absent, skip.
///
/// On any parse failure or when `originalJson` is unavailable we
/// **accept** the purchase as a candidate. The contract is "false
/// positive over false negative": legitimate paying users should never
/// be missed; a host whose mixed catalog risks over-marking should
/// override via `Feddy.setSubscription(...)`.
bool isLikelySubscriptionJson(String? originalJson) {
  if (originalJson == null || originalJson.isEmpty) return true;
  try {
    final parsed = jsonDecode(originalJson);
    if (parsed is Map<String, dynamic>) {
      return parsed.containsKey('autoRenewing');
    }
  } catch (_) {
    // Fall through.
  }
  return true;
}

/// Derive a `Subscription` from a Play Billing `PurchaseDetails`.
/// Returns null when the event isn't a `purchased` / `restored`
/// outcome, or when the originalJson confidently looks like a
/// non-subscription (consumable / one-time).
///
/// `expiresAt` is always null — Play Billing's client-side surface
/// does not expose subscription expiration. Hosts that need expiration
/// should push via `Feddy.setSubscription(...)`.
///
/// Pure function — exported for unit tests.
Subscription? deriveSubscriptionFromPurchaseDetails(PurchaseDetails details) {
  if (details.status != PurchaseStatus.purchased &&
      details.status != PurchaseStatus.restored) {
    return null;
  }

  String? originalJson;
  if (details is GooglePlayPurchaseDetails) {
    try {
      originalJson = details.billingClientPurchase.originalJson;
    } catch (_) {
      originalJson = null;
    }
  }

  if (!isLikelySubscriptionJson(originalJson)) return null;

  return Subscription(
    isPaid: true,
    status: SubscriptionStatus.active,
    productId: details.productID,
    expiresAt: null,
  );
}

/// Listens to Play Billing's `purchaseStream`, calls `restorePurchases`
/// to replay current entitlements, debounces a window of incoming
/// events, and writes the highest-priority result to the auto slot.
///
/// Lifecycle: created by `Feddy.configure(...)` when
/// `autoDetectSubscription` is true and the platform is Android,
/// cancelled by `Feddy.reset()` or when a new client supersedes the
/// previous one.
///
/// iOS uses [detectActiveSubscription] in `iap_detector.dart` directly
/// and does **not** instantiate this listener — `purchaseStream` is a
/// broadcast and we don't want SDK side-effects piggy-backing on the
/// host's own listener on iOS where SK2Transaction is sufficient.
class IapStreamListener {
  final Duration debounceWindow;

  /// Sink for the reduced `Subscription`. Pulled out as an injection
  /// point so tests can assert what the listener resolves to without
  /// touching `shared_preferences`.
  final Future<void> Function(Subscription?) onResolved;

  /// Source of purchase events. Defaults to
  /// `InAppPurchase.instance.purchaseStream`; tests inject a
  /// `StreamController` they fully control.
  final Stream<List<PurchaseDetails>> Function() streamProvider;

  /// Trigger for `restorePurchases()`. Defaults to
  /// `InAppPurchase.instance.restorePurchases`; tests inject a no-op or
  /// a controlled fake.
  final Future<void> Function() restoreTrigger;

  StreamSubscription<List<PurchaseDetails>>? _streamSub;
  Timer? _debounceTimer;
  final List<Subscription> _buffer = <Subscription>[];

  IapStreamListener({
    required this.onResolved,
    Stream<List<PurchaseDetails>> Function()? streamProvider,
    Future<void> Function()? restoreTrigger,
    this.debounceWindow = const Duration(milliseconds: 1500),
  })  : streamProvider =
            streamProvider ?? (() => InAppPurchase.instance.purchaseStream),
        restoreTrigger =
            restoreTrigger ?? (() => InAppPurchase.instance.restorePurchases());

  /// Subscribe to the purchase stream + trigger a restore. Idempotent
  /// — calling twice is a no-op for the second call.
  ///
  /// Platform gating is the caller's responsibility: `Feddy.configure`
  /// only constructs an `IapStreamListener` on Android. The default
  /// `streamProvider` reaches into `InAppPurchase.instance` which
  /// throws on iOS — caught here for safety.
  Future<void> start() async {
    if (_streamSub != null) return;
    try {
      _streamSub = streamProvider().listen(
        _onEvent,
        onError: (Object _) {
          // Host's listener handles errors; we only consume snapshots
          // when they cleanly arrive.
        },
      );
    } catch (_) {
      return;
    }
    try {
      await restoreTrigger();
    } catch (_) {
      // restorePurchases failed (Play Billing unavailable, signed-out
      // user, etc) — leave the auto slot untouched.
    }
  }

  /// Re-trigger `restorePurchases()` (e.g. from
  /// `Feddy.refreshSubscription()` after a purchase). The stream
  /// subscription stays live across calls.
  Future<void> refresh() async {
    if (_streamSub == null) return;
    try {
      await restoreTrigger();
    } catch (_) {
      // No-op on failure.
    }
  }

  /// Cancel the stream subscription + flush the debounce timer.
  /// Called from `Feddy.reset()`.
  Future<void> stop() async {
    await _streamSub?.cancel();
    _streamSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _buffer.clear();
  }

  void _onEvent(List<PurchaseDetails> details) {
    for (final d in details) {
      final derived = deriveSubscriptionFromPurchaseDetails(d);
      if (derived != null) _buffer.add(derived);
    }
    if (_buffer.isEmpty) return;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceWindow, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final winner = pickHighestPriority(_buffer);
    _buffer.clear();
    if (winner == null) return;
    await onResolved(winner);
  }
}
