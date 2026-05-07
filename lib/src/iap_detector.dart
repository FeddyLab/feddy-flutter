import 'dart:io' show Platform;

import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'types.dart';

/// Numeric priority used to pick the "most engaged" entitlement when
/// the host app has multiple active subscriptions stacked. Mirrors the
/// iOS `StoreKitDetector.priority` and RN `priorityOf` reduce so the
/// dashboard receives the same payload regardless of platform.
int priorityOf(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.active:
      return 3;
    case SubscriptionStatus.trial:
      return 2;
    case SubscriptionStatus.expired:
      return 1;
    case SubscriptionStatus.none:
      return 0;
  }
}

/// Reduce a list of candidate `Subscription`s to the highest-priority
/// entry. Returns null on empty input. Exported for unit tests — most
/// callers should use [detectActiveSubscription] / the Android stream
/// listener which feed into this internally.
Subscription? pickHighestPriority(List<Subscription> candidates) {
  Subscription? best;
  for (final candidate in candidates) {
    if (best == null ||
        priorityOf(candidate.status) > priorityOf(best.status)) {
      best = candidate;
    }
  }
  return best;
}

/// Derive a `Subscription` snapshot from a single SK2 transaction.
/// Returns null when the transaction is not a subscription (consumables
/// have no `expirationDate`) or when the expiration string fails to
/// parse.
///
/// Pure function — exported for unit tests. Production callers should
/// use [detectActiveSubscription] which fetches + derives + reduces in
/// one shot.
///
/// Trial / introductory offer detection is **not** performed: the
/// `SK2Transaction` wrapper does not expose `offerType` and parsing the
/// JWS `jsonRepresentation` for a single signal would balloon the SDK
/// dependency surface. Hosts that need trial-vs-active differentiation
/// should push via `Feddy.setSubscription(...)`.
Subscription? deriveSubscriptionFromSK2(
  SK2Transaction transaction, {
  DateTime? now,
}) {
  final expirationStr = transaction.expirationDate;
  if (expirationStr == null) {
    // Consumable / non-renewable without expiration → not a
    // subscription; skip rather than misreport as active.
    return null;
  }
  final expiresAt = DateTime.tryParse(expirationStr);
  if (expiresAt == null) return null;

  final reference = now ?? DateTime.now().toUtc();
  final isActive = expiresAt.toUtc().isAfter(reference);
  final status =
      isActive ? SubscriptionStatus.active : SubscriptionStatus.expired;

  return Subscription(
    isPaid: isActive,
    status: status,
    productId: transaction.productId,
    expiresAt: expirationStr,
  );
}

/// Read the host app's currently-active subscription via the platform's
/// official read-only API and reduce it to a single `Subscription`
/// snapshot.
///
/// - **iOS**: queries `SK2Transaction.transactions()` (StoreKit 2). No
///   productIds required — Apple returns the full set of current
///   entitlements with productId / expirationDate.
/// - **Android / other**: returns `null`. The Android path runs through
///   the purchase-stream listener (see `iap_stream_listener.dart`)
///   because Play Billing's read API is event-driven.
///
/// Failures (plugin not initialised, sandbox refused, platform not
/// supported) all fall through to `null` — the caller should treat
/// `null` as "no signal" and leave the auto slot untouched.
Future<Subscription?> detectActiveSubscription() async {
  if (!Platform.isIOS) return null;
  try {
    final transactions = await SK2Transaction.transactions();
    final candidates = <Subscription>[];
    for (final tx in transactions) {
      final derived = deriveSubscriptionFromSK2(tx);
      if (derived != null) candidates.add(derived);
    }
    return pickHighestPriority(candidates);
  } catch (_) {
    return null;
  }
}
