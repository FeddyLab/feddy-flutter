import 'package:feddy_flutter/src/smart_review/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _day = 24 * 60 * 60 * 1000;
const _now = 1700000000000;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('snapshot zero state on fresh install', () async {
    final s = await snapshot();
    expect(s.installDate, isNull);
    expect(s.sessionCount, 0);
    expect(s.lastShownAt, isNull);
    expect(s.yearlyCount, 0);
    expect(s.yearlyWindowStart, isNull);
  });

  group('bumpSession', () {
    test('records installDate on first call', () async {
      await bumpSession(_now);
      final s = await snapshot();
      expect(s.installDate, _now);
      expect(s.sessionCount, 1);
    });

    test('preserves installDate across calls', () async {
      await bumpSession(_now);
      await bumpSession(_now + _day);
      await bumpSession(_now + 2 * _day);
      final s = await snapshot();
      expect(s.installDate, _now);
      expect(s.sessionCount, 3);
    });
  });

  group('markShown', () {
    test('starts new yearly window on first call', () async {
      await markShown(_now);
      final s = await snapshot();
      expect(s.lastShownAt, _now);
      expect(s.yearlyCount, 1);
      expect(s.yearlyWindowStart, _now);
    });

    test('increments yearlyCount within window', () async {
      await markShown(_now);
      await markShown(_now + 30 * _day);
      await markShown(_now + 60 * _day);
      final s = await snapshot();
      expect(s.yearlyCount, 3);
      expect(s.yearlyWindowStart, _now);
    });

    test('rolls window over after 365 days', () async {
      await markShown(_now);
      await markShown(_now + kYearlyWindowMs + _day);
      final s = await snapshot();
      expect(s.yearlyCount, 1);
      expect(s.yearlyWindowStart, _now + kYearlyWindowMs + _day);
    });
  });

  test('clearAll wipes', () async {
    await bumpSession(_now);
    await markShown(_now);
    await clearAll();
    final s = await snapshot();
    expect(s.installDate, isNull);
    expect(s.sessionCount, 0);
    expect(s.lastShownAt, isNull);
    expect(s.yearlyCount, 0);
    expect(s.yearlyWindowStart, isNull);
  });
}
