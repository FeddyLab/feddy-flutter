import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'client.dart';
import 'feddy_error.dart';
import 'types.dart';

const String _kCacheKey = 'app.feddy.capabilities.cache';
const Duration _kTtl = Duration(hours: 24);

class _CacheEntry {
  final DateTime fetchedAt;

  /// `null` is meaningful: a Pro/Team workspace's branding is `null`,
  /// distinct from "no cache yet" → fall back to `Branding.fallback`.
  final Branding? branding;

  const _CacheEntry({required this.fetchedAt, required this.branding});

  bool get isFresh => DateTime.now().difference(fetchedAt) < _kTtl;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'branding': branding?.toJson(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    final brandingJson = json['branding'];
    return _CacheEntry(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      branding: brandingJson is Map<String, dynamic>
          ? Branding.fromJson(brandingJson)
          : null,
    );
  }
}

Future<_CacheEntry?> _read() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.isEmpty) return null;
    return _CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<void> _write(_CacheEntry entry) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(entry.toJson()));
  } catch (_) {
    // Best-effort cache write; failure is fine.
  }
}

/// What `PoweredByBadge` should render right now. Reads the cache;
/// returns the bundled fallback on cache miss. Callers must still
/// kick off `refreshCapabilitiesInBackground` so the next call
/// converges on the workspace's actual plan.
Future<Branding?> currentBranding() async {
  final cached = await _read();
  if (cached != null) return cached.branding;
  return Branding.fallback;
}

/// Fire-and-forget refresh. Skips the round-trip when the cache is
/// still fresh — the badge can be re-rendered many times in a
/// session and each render kicks one of these.
void refreshCapabilitiesInBackground(FeddyClient client) {
  Future<void>(() async {
    final cached = await _read();
    if (cached != null && cached.isFresh) return;
    try {
      final response = await client.get('/v1/capabilities');
      final brandingJson = response?['branding'];
      final branding = brandingJson is Map<String, dynamic>
          ? Branding.fromJson(brandingJson)
          : null;
      await _write(_CacheEntry(fetchedAt: DateTime.now(), branding: branding));
    } on FeddyError catch (e) {
      // ignore: avoid_print
      print('[Feddy] capabilities refresh failed — ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print('[Feddy] capabilities refresh failed — $e');
    }
  });
}

/// Wipe the cache. Hooked into `Feddy.reset()` so a logged-out
/// integrator picking up a different workspace doesn't see the
/// previous workspace's branding decision.
Future<void> clearCapabilitiesCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kCacheKey);
}
