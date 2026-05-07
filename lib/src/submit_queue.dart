import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'client.dart';
import 'feddy_error.dart';

const String _kQueueKey = 'app.feddy.submit.queue';

/// Hard cap on stored entries — FIFO drop when full.
const int kMaxQueue = 50;

/// Per-entry attempt budget — drop poisoned entries after this many tries.
const int kMaxAttempts = 5;

class QueuedSubmit {
  final Map<String, dynamic> body;
  final int attempts;

  /// ms since epoch.
  final int enqueuedAt;

  const QueuedSubmit({
    required this.body,
    required this.attempts,
    required this.enqueuedAt,
  });

  Map<String, dynamic> toJson() => {
        'body': body,
        'attempts': attempts,
        'enqueuedAt': enqueuedAt,
      };

  factory QueuedSubmit.fromJson(Map<String, dynamic> json) => QueuedSubmit(
        body: Map<String, dynamic>.from(
          json['body'] as Map? ?? const <String, dynamic>{},
        ),
        attempts: json['attempts'] as int? ?? 0,
        enqueuedAt:
            json['enqueuedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
}

Future<List<QueuedSubmit>> loadQueue() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) return [];
    final parsed = jsonDecode(raw);
    if (parsed is! List) return [];
    return parsed
        .map((e) => QueuedSubmit.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    // Corruption — drop the entire queue.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueueKey);
    return [];
  }
}

Future<void> saveQueue(List<QueuedSubmit> queue) async {
  final prefs = await SharedPreferences.getInstance();
  if (queue.isEmpty) {
    await prefs.remove(_kQueueKey);
    return;
  }
  await prefs.setString(
    _kQueueKey,
    jsonEncode(queue.map((e) => e.toJson()).toList()),
  );
}

Future<void> clearQueue() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kQueueKey);
}

Future<void> enqueueSubmit(Map<String, dynamic> body) async {
  final queue = await loadQueue();
  if (queue.length >= kMaxQueue) {
    queue.removeAt(0);
  }
  queue.add(
    QueuedSubmit(
      body: body,
      attempts: 0,
      enqueuedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  await saveQueue(queue);
}

/// Drain the queue against the configured client. Runs sequentially.
/// First network error short-circuits the rest of the queue back to
/// disk; HTTP 4xx / 5xx bumps `attempts` and drops after [kMaxAttempts].
///
/// Returns the count of entries actually flushed.
Future<int> replayQueue(FeddyClient client) async {
  final initial = await loadQueue();
  if (initial.isEmpty) return 0;

  var flushed = 0;
  final remaining = <QueuedSubmit>[];
  var stopped = false;

  for (var i = 0; i < initial.length; i++) {
    final entry = initial[i];
    if (stopped) {
      remaining.add(entry);
      continue;
    }
    try {
      await client.post('/v1/requests', entry.body);
      flushed++;
    } on FeddyError catch (err) {
      final next = QueuedSubmit(
        body: entry.body,
        attempts: entry.attempts + 1,
        enqueuedAt: entry.enqueuedAt,
      );
      if (err.code == FeddyErrorCode.network) {
        remaining.add(next);
        stopped = true;
        continue;
      }
      if (next.attempts >= kMaxAttempts) {
        // ignore: avoid_print
        print(
          '[Feddy] dropping queued submit after $kMaxAttempts failed attempts — ${err.message}',
        );
        continue;
      }
      remaining.add(next);
    } catch (err) {
      final next = QueuedSubmit(
        body: entry.body,
        attempts: entry.attempts + 1,
        enqueuedAt: entry.enqueuedAt,
      );
      if (next.attempts >= kMaxAttempts) {
        // ignore: avoid_print
        print(
          '[Feddy] dropping queued submit after $kMaxAttempts failed attempts — $err',
        );
        continue;
      }
      remaining.add(next);
    }
  }

  await saveQueue(remaining);
  return flushed;
}
