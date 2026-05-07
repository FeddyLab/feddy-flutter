import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../client.dart';
import '../feddy_error.dart';
import 'engine.dart';

const String _kCacheKey = 'app.feddy.smartReview.config.cache';
const Duration _kTtl = Duration(hours: 24);

class _CacheEntry {
  final DateTime fetchedAt;
  final SmartReviewRules rules;

  const _CacheEntry({required this.fetchedAt, required this.rules});

  bool get isFresh => DateTime.now().difference(fetchedAt) < _kTtl;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'rules': {
          'minDaysSinceInstall': rules.minDaysSinceInstall,
          'minSessions': rules.minSessions,
          'cooldownDays': rules.cooldownDays,
          'yearlyCap': rules.yearlyCap,
        },
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    final rulesJson = json['rules'] as Map<String, dynamic>;
    return _CacheEntry(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      rules: SmartReviewRules(
        minDaysSinceInstall: rulesJson['minDaysSinceInstall'] as int,
        minSessions: rulesJson['minSessions'] as int,
        cooldownDays: rulesJson['cooldownDays'] as int,
        yearlyCap: rulesJson['yearlyCap'] as int,
      ),
    );
  }
}

Future<_CacheEntry?> _readCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.isEmpty) return null;
    return _CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

Future<SmartReviewRules> currentRules() async {
  final cached = await _readCache();
  return cached?.rules ?? SmartReviewRules.defaults;
}

void refreshConfigInBackground(FeddyClient client) {
  Future<void>(() async {
    final cached = await _readCache();
    if (cached != null && cached.isFresh) return;
    try {
      final response =
          await client.get('/v1/config', query: {'kind': 'smart_review'});
      final rule = response?['rule'] as Map<String, dynamic>?;
      if (rule == null) return;
      final rules = SmartReviewRules(
        minDaysSinceInstall: rule['min_days_since_install'] as int,
        minSessions: rule['min_sessions'] as int,
        cooldownDays: rule['cooldown_days'] as int,
        yearlyCap: rule['yearly_cap'] as int,
      );
      final entry = _CacheEntry(fetchedAt: DateTime.now(), rules: rules);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(entry.toJson()));
    } on FeddyError catch (e) {
      // ignore: avoid_print
      print('[Feddy] SmartReview config refresh failed — ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print('[Feddy] SmartReview config refresh failed — $e');
    }
  });
}

Future<void> clearConfigCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kCacheKey);
}
