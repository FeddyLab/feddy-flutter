import 'package:feddy_flutter/src/smart_review/engine.dart';
import 'package:feddy_flutter/src/smart_review/store.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 24 * 60 * 60 * 1000;
const _now = 1700000000000;

SmartReviewState _state({
  int? installDate,
  int sessionCount = 0,
  int? lastShownAt,
  int yearlyCount = 0,
  int? yearlyWindowStart,
}) =>
    SmartReviewState(
      installDate: installDate,
      sessionCount: sessionCount,
      lastShownAt: lastShownAt,
      yearlyCount: yearlyCount,
      yearlyWindowStart: yearlyWindowStart,
    );

void main() {
  const rules = SmartReviewRules.defaults;

  group('evaluate', () {
    test('skip_below_install_age when no installDate', () {
      final decision = evaluate(_now, _state(), rules);
      expect(decision, isA<SkipBelowInstallAge>());
    });

    test('skip_below_install_age when too recent', () {
      final decision = evaluate(
        _now,
        _state(installDate: _now - 3 * _day, sessionCount: 10),
        rules,
      );
      expect(decision, isA<SkipBelowInstallAge>());
    });

    test('skip_below_sessions when sessionCount low', () {
      final decision = evaluate(
        _now,
        _state(installDate: _now - 30 * _day, sessionCount: 2),
        rules,
      );
      expect(decision, isA<SkipBelowSessions>());
    });

    test('skip_in_cooldown when within 90d of last shown', () {
      final decision = evaluate(
        _now,
        _state(
          installDate: _now - 365 * _day,
          sessionCount: 100,
          lastShownAt: _now - 30 * _day,
        ),
        rules,
      );
      expect(decision, isA<SkipInCooldown>());
    });

    test('skip_yearly_cap when 3 prompts in last 365 days', () {
      final decision = evaluate(
        _now,
        _state(
          installDate: _now - 730 * _day,
          sessionCount: 100,
          lastShownAt: _now - 100 * _day,
          yearlyCount: 3,
          yearlyWindowStart: _now - 200 * _day,
        ),
        rules,
      );
      expect(decision, isA<SkipYearlyCap>());
    });

    test('show when all gates pass', () {
      final decision = evaluate(
        _now,
        _state(
          installDate: _now - 365 * _day,
          sessionCount: 50,
          lastShownAt: _now - 200 * _day,
          yearlyCount: 1,
          yearlyWindowStart: _now - 200 * _day,
        ),
        rules,
      );
      expect(decision, isA<ShowDecision>());
    });
  });
}
