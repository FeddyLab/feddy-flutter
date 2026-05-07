import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'types.dart';

const String _kManualKey = 'app.feddy.subscription.manual';
const String _kAutoKey = 'app.feddy.subscription.auto';

/// Subscription snapshots live in two parallel slots:
///
/// - **manual** — set by `Feddy.setSubscription(...)` when the host
///   app's source-of-truth is RevenueCat / Adapty / its own server.
/// - **auto** — populated by a future IAP detector. Reserved for
///   v0.2 when the host can opt in to auto-detect by passing
///   `iapProductIds` to `configure(...)`.
///
/// Precedence: manual > auto > null. Mirrors the iOS / RN
/// `getEffectiveSubscription` semantics so the dashboard receives the
/// same payload regardless of platform.

Future<Subscription?> _readSlot(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return Subscription.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> _writeSlot(String key, Subscription? subscription) async {
  final prefs = await SharedPreferences.getInstance();
  if (subscription == null) {
    await prefs.remove(key);
    return;
  }
  await prefs.setString(key, jsonEncode(subscription.toJson()));
}

Future<Subscription?> getStoredSubscription() => _readSlot(_kManualKey);

Future<void> setStoredSubscription(Subscription? subscription) =>
    _writeSlot(_kManualKey, subscription);

Future<void> clearStoredSubscription() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kManualKey);
}

Future<Subscription?> getAutoDetectedSubscription() => _readSlot(_kAutoKey);

Future<void> setAutoDetectedSubscription(Subscription? subscription) =>
    _writeSlot(_kAutoKey, subscription);

Future<void> clearAutoDetectedSubscription() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kAutoKey);
}

/// Effective `Subscription` snapshot the SDK should attach to the
/// next outbound write. Manual override always wins.
Future<Subscription?> getEffectiveSubscription() async {
  final manual = await getStoredSubscription();
  if (manual != null) return manual;
  return getAutoDetectedSubscription();
}
