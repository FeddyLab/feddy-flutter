import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../client.dart';
import '../feddy_error.dart';
import '../system_boards.dart';
import '../types.dart';

const String _kCacheKey = 'app.feddy.boards.cache.v1';
const Duration _kTtl = Duration(hours: 1);

class _CacheEntry {
  final DateTime fetchedAt;
  final List<FeedbackBoard> items;

  const _CacheEntry({required this.fetchedAt, required this.items});

  bool get isFresh => DateTime.now().difference(fetchedAt) < _kTtl;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'items': items.map((b) => b.toJson()).toList(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        items: (json['items'] as List? ?? const [])
            .map((e) => FeedbackBoard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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

Future<void> _writeCache(List<FeedbackBoard> items) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final entry = _CacheEntry(fetchedAt: DateTime.now(), items: items);
    await prefs.setString(_kCacheKey, jsonEncode(entry.toJson()));
  } catch (_) {
    // Best-effort cache write.
  }
}

void _refreshInBackground(FeddyClient client) {
  Future<void>(() async {
    try {
      final response = await client.get('/v1/boards');
      final items = (response?['items'] as List? ?? const [])
          .map((e) => FeedbackBoard.fromJson(e as Map<String, dynamic>))
          .map(localizeBoard)
          .toList();
      if (items.isNotEmpty) {
        await _writeCache(items);
      }
    } on FeddyError catch (e) {
      // ignore: avoid_print
      print('[Feddy] boards refresh failed — ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print('[Feddy] boards refresh failed — $e');
    }
  });
}

/// Fetch the workspace's public, non-archived boards with a 1 h
/// cache. Stale-while-revalidate: returns cached value immediately
/// (even if stale), kicks a background refresh to update for the
/// next call.
///
/// Falls back to the bundled system defaults (`Feature Requests` /
/// `Bug Reports`, localized) on first-launch network failure.
Future<List<FeedbackBoard>> fetchBoards(FeddyClient client) async {
  final cached = await _readCache();
  if (cached != null) {
    if (!cached.isFresh) {
      _refreshInBackground(client);
    }
    return cached.items.isNotEmpty ? cached.items : systemDefaultBoards();
  }
  try {
    final response = await client.get('/v1/boards');
    final items = (response?['items'] as List? ?? const [])
        .map((e) => FeedbackBoard.fromJson(e as Map<String, dynamic>))
        .map(localizeBoard)
        .toList();
    if (items.isNotEmpty) {
      await _writeCache(items);
      return items;
    }
  } on FeddyError catch (e) {
    // ignore: avoid_print
    print('[Feddy] boards fetch failed — using defaults: ${e.message}');
  } catch (e) {
    // ignore: avoid_print
    print('[Feddy] boards fetch failed — using defaults: $e');
  }
  return systemDefaultBoards();
}

Future<void> clearBoardsCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kCacheKey);
}
