import 'store.dart';

/// Threshold bundle the rule engine evaluates against. Defaults
/// match the server's hard-coded baseline — overridden by the
/// config fetcher when the workspace has a custom rule.
class SmartReviewRules {
  final int minDaysSinceInstall;
  final int minSessions;
  final int cooldownDays;
  final int yearlyCap;

  const SmartReviewRules({
    required this.minDaysSinceInstall,
    required this.minSessions,
    required this.cooldownDays,
    required this.yearlyCap,
  });

  static const SmartReviewRules defaults = SmartReviewRules(
    minDaysSinceInstall: 7,
    minSessions: 5,
    cooldownDays: 90,
    yearlyCap: 3,
  );
}

sealed class SmartReviewDecision {
  const SmartReviewDecision();
  String get kind;
}

class ShowDecision extends SmartReviewDecision {
  const ShowDecision();
  @override
  String get kind => 'show';
}

class SkipBelowInstallAge extends SmartReviewDecision {
  final int observed;
  final int required;
  const SkipBelowInstallAge({required this.observed, required this.required});
  @override
  String get kind => 'skip_below_install_age';
}

class SkipBelowSessions extends SmartReviewDecision {
  final int observed;
  final int required;
  const SkipBelowSessions({required this.observed, required this.required});
  @override
  String get kind => 'skip_below_sessions';
}

class SkipInCooldown extends SmartReviewDecision {
  final int observedDays;
  final int requiredDays;
  const SkipInCooldown({
    required this.observedDays,
    required this.requiredDays,
  });
  @override
  String get kind => 'skip_in_cooldown';
}

class SkipYearlyCap extends SmartReviewDecision {
  final int observed;
  final int cap;
  const SkipYearlyCap({required this.observed, required this.cap});
  @override
  String get kind => 'skip_yearly_cap';
}

const int _msPerDay = 86400000;

int _wholeDays(int startMs, int endMs) {
  if (endMs <= startMs) return 0;
  return (endMs - startMs) ~/ _msPerDay;
}

/// Pure decision: given a clock value, the persisted state, and a
/// rules bundle, decide whether to show the Smart Review prompt.
/// No side effects, trivially unit-testable.
SmartReviewDecision evaluate(
  int now,
  SmartReviewState state,
  SmartReviewRules rules,
) {
  final daysSinceInstall =
      state.installDate != null ? _wholeDays(state.installDate!, now) : 0;
  if (daysSinceInstall < rules.minDaysSinceInstall) {
    return SkipBelowInstallAge(
      observed: daysSinceInstall,
      required: rules.minDaysSinceInstall,
    );
  }
  if (state.sessionCount < rules.minSessions) {
    return SkipBelowSessions(
      observed: state.sessionCount,
      required: rules.minSessions,
    );
  }
  if (state.lastShownAt != null) {
    final daysSinceLast = _wholeDays(state.lastShownAt!, now);
    if (daysSinceLast < rules.cooldownDays) {
      return SkipInCooldown(
        observedDays: daysSinceLast,
        requiredDays: rules.cooldownDays,
      );
    }
  }
  if (state.yearlyWindowStart != null &&
      now - state.yearlyWindowStart! < kYearlyWindowMs &&
      state.yearlyCount >= rules.yearlyCap) {
    return SkipYearlyCap(
      observed: state.yearlyCount,
      cap: rules.yearlyCap,
    );
  }
  return const ShowDecision();
}
