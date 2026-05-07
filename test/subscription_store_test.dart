import 'package:feddy_flutter/feddy_flutter.dart';
import 'package:feddy_flutter/src/subscription_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const manual = Subscription(
  isPaid: true,
  status: SubscriptionStatus.active,
  productId: 'com.foo.pro_yearly',
  expiresAt: '2027-01-01T00:00:00Z',
);

const auto = Subscription(
  isPaid: true,
  status: SubscriptionStatus.trial,
  productId: 'com.foo.pro_monthly',
  expiresAt: '2026-06-01T00:00:00Z',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('manual slot', () {
    test('returns null when nothing stored', () async {
      expect(await getStoredSubscription(), isNull);
    });

    test('round-trip', () async {
      await setStoredSubscription(manual);
      final loaded = await getStoredSubscription();
      expect(loaded?.isPaid, manual.isPaid);
      expect(loaded?.status, manual.status);
      expect(loaded?.productId, manual.productId);
    });

    test('clear via setStoredSubscription(null)', () async {
      await setStoredSubscription(manual);
      await setStoredSubscription(null);
      expect(await getStoredSubscription(), isNull);
    });

    test('clearStoredSubscription wipes', () async {
      await setStoredSubscription(manual);
      await clearStoredSubscription();
      expect(await getStoredSubscription(), isNull);
    });
  });

  group('auto slot', () {
    test('round-trip', () async {
      await setAutoDetectedSubscription(auto);
      final loaded = await getAutoDetectedSubscription();
      expect(loaded?.status, auto.status);
    });

    test('manual and auto are independent', () async {
      await setStoredSubscription(manual);
      await setAutoDetectedSubscription(auto);
      expect((await getStoredSubscription())?.status, manual.status);
      expect((await getAutoDetectedSubscription())?.status, auto.status);
    });
  });

  group('getEffectiveSubscription precedence', () {
    test('returns null when neither slot set', () async {
      expect(await getEffectiveSubscription(), isNull);
    });

    test('returns manual when only manual set', () async {
      await setStoredSubscription(manual);
      expect((await getEffectiveSubscription())?.status, manual.status);
    });

    test('returns auto when only auto set', () async {
      await setAutoDetectedSubscription(auto);
      expect((await getEffectiveSubscription())?.status, auto.status);
    });

    test('manual wins when both set', () async {
      await setStoredSubscription(manual);
      await setAutoDetectedSubscription(auto);
      expect((await getEffectiveSubscription())?.status, manual.status);
    });

    test('falls back to auto after manual cleared', () async {
      await setStoredSubscription(manual);
      await setAutoDetectedSubscription(auto);
      await setStoredSubscription(null);
      expect((await getEffectiveSubscription())?.status, auto.status);
    });
  });
}
