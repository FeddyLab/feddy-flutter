import 'package:feddy_flutter/src/submit_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('persistence', () {
    test('returns [] when nothing stored', () async {
      expect(await loadQueue(), isEmpty);
    });

    test('round-trip queue via SharedPreferences', () async {
      await enqueueSubmit({'title': 'a'});
      final queue = await loadQueue();
      expect(queue.length, 1);
      expect(queue[0].body['title'], 'a');
      expect(queue[0].attempts, 0);
    });

    test('FIFO drops oldest at cap', () async {
      // pre-fill at cap
      final initial = List.generate(
        kMaxQueue,
        (i) => QueuedSubmit(
          body: {'idx': i},
          attempts: 0,
          enqueuedAt: i,
        ),
      );
      await saveQueue(initial);
      await enqueueSubmit({'idx': 'newest'});
      final queue = await loadQueue();
      expect(queue.length, kMaxQueue);
      expect(queue.first.body['idx'], 1);
      expect(queue.last.body['idx'], 'newest');
    });

    test('clearQueue wipes', () async {
      await enqueueSubmit({'title': 'x'});
      await clearQueue();
      expect(await loadQueue(), isEmpty);
    });
  });
}
