import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const String _kAnonToken = 'app.feddy.anonymousToken';
const String _kLastUserId = 'app.feddy.lastExternalUserId';
const String _kAttachmentsEnabled = 'app.feddy.attachmentsEnabled';

final Random _rng = Random.secure();

String _generateAnonymousToken() {
  // RFC 4122 v4-ish UUID using crypto-secure RNG. Sufficient for an
  // opaque per-install token (not a security boundary).
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant
  String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

Future<String> getAnonymousToken() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_kAnonToken);
  if (existing != null && existing.isNotEmpty) return existing;
  final fresh = _generateAnonymousToken();
  await prefs.setString(_kAnonToken, fresh);
  return fresh;
}

Future<String?> getLastExternalUserId() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_kLastUserId);
  return value == null || value.isEmpty ? null : value;
}

Future<void> setLastExternalUserId(String? value) async {
  final prefs = await SharedPreferences.getInstance();
  if (value == null || value.isEmpty) {
    await prefs.remove(_kLastUserId);
  } else {
    await prefs.setString(_kLastUserId, value);
  }
}

/// Cached server flag from the last successful `/v1/identify` call.
/// `false` until identify confirms otherwise — the SDK hides the
/// attachment UI rather than showing it speculatively and having
/// uploads rejected.
Future<bool> getAttachmentsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kAttachmentsEnabled) ?? false;
}

Future<void> setAttachmentsEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kAttachmentsEnabled, value);
}
