import 'package:shared_preferences/shared_preferences.dart';

const String kInstallDateKey = 'app.feddy.smartReview.installDate';
const String kSessionCountKey = 'app.feddy.smartReview.sessionCount';
const String kLastShownAtKey = 'app.feddy.smartReview.lastShownAt';
const String kYearlyCountKey = 'app.feddy.smartReview.yearlyCount';
const String kYearlyWindowStartKey = 'app.feddy.smartReview.yearlyWindowStart';

/// 365 days in milliseconds. Not a calendar year so leap-year drift
/// can't turn a 4th prompt into "365 days minus a few hours" by
/// accident.
const int kYearlyWindowMs = 365 * 24 * 60 * 60 * 1000;

class SmartReviewState {
  /// ms since epoch.
  final int? installDate;
  final int sessionCount;

  /// ms since epoch.
  final int? lastShownAt;
  final int yearlyCount;

  /// ms since epoch.
  final int? yearlyWindowStart;

  const SmartReviewState({
    required this.installDate,
    required this.sessionCount,
    required this.lastShownAt,
    required this.yearlyCount,
    required this.yearlyWindowStart,
  });
}

Future<int> _getInt(SharedPreferences prefs, String key) async {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return 0;
  return int.tryParse(raw) ?? 0;
}

Future<int?> _getMs(SharedPreferences prefs, String key) async {
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return null;
  return int.tryParse(raw);
}

Future<SmartReviewState> snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return SmartReviewState(
    installDate: await _getMs(prefs, kInstallDateKey),
    sessionCount: await _getInt(prefs, kSessionCountKey),
    lastShownAt: await _getMs(prefs, kLastShownAtKey),
    yearlyCount: await _getInt(prefs, kYearlyCountKey),
    yearlyWindowStart: await _getMs(prefs, kYearlyWindowStartKey),
  );
}

/// Record one session. Lazily writes installDate on first call so a
/// fresh integration starts the gating clock from today.
Future<void> bumpSession([int? nowOverride]) async {
  final now = nowOverride ?? DateTime.now().millisecondsSinceEpoch;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(kInstallDateKey) == null) {
    await prefs.setString(kInstallDateKey, '$now');
  }
  final next = (await _getInt(prefs, kSessionCountKey)) + 1;
  await prefs.setString(kSessionCountKey, '$next');
}

/// Record that the prompt was actually shown.
Future<void> markShown([int? nowOverride]) async {
  final now = nowOverride ?? DateTime.now().millisecondsSinceEpoch;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLastShownAtKey, '$now');
  final windowStart = await _getMs(prefs, kYearlyWindowStartKey);
  if (windowStart != null && now - windowStart < kYearlyWindowMs) {
    final next = (await _getInt(prefs, kYearlyCountKey)) + 1;
    await prefs.setString(kYearlyCountKey, '$next');
  } else {
    await prefs.setString(kYearlyWindowStartKey, '$now');
    await prefs.setString(kYearlyCountKey, '1');
  }
}

/// Wipe every key — debug menus only.
Future<void> clearAll() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kInstallDateKey);
  await prefs.remove(kSessionCountKey);
  await prefs.remove(kLastShownAtKey);
  await prefs.remove(kYearlyCountKey);
  await prefs.remove(kYearlyWindowStartKey);
}
