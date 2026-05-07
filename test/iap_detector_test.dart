import 'package:feddy_flutter/src/iap_detector.dart';
import 'package:feddy_flutter/src/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

SK2Transaction _tx({
  String productId = 'com.test.monthly',
  String? expirationDate,
  String purchaseDate = '2026-01-01T00:00:00Z',
}) =>
    SK2Transaction(
      id: 'tx-1',
      originalId: 'tx-1',
      productId: productId,
      purchaseDate: purchaseDate,
      expirationDate: expirationDate,
      appAccountToken: null,
    );

void main() {
  group('priorityOf', () {
    test('orders active > trial > expired > none', () {
      expect(priorityOf(SubscriptionStatus.active), 3);
      expect(priorityOf(SubscriptionStatus.trial), 2);
      expect(priorityOf(SubscriptionStatus.expired), 1);
      expect(priorityOf(SubscriptionStatus.none), 0);
    });
  });

  group('pickHighestPriority', () {
    Subscription mk(SubscriptionStatus status, [String pid = 'p']) =>
        Subscription(
          isPaid: status == SubscriptionStatus.active ||
              status == SubscriptionStatus.trial,
          status: status,
          productId: pid,
        );

    test('returns null for empty input', () {
      expect(pickHighestPriority(<Subscription>[]), isNull);
    });

    test('returns single candidate as-is', () {
      final result = pickHighestPriority([mk(SubscriptionStatus.active, 'a')]);
      expect(result?.productId, 'a');
      expect(result?.status, SubscriptionStatus.active);
    });

    test('reduces stacked entitlements to active over expired', () {
      final result = pickHighestPriority([
        mk(SubscriptionStatus.expired, 'lapsed'),
        mk(SubscriptionStatus.active, 'fresh'),
      ]);
      expect(result?.productId, 'fresh');
      expect(result?.status, SubscriptionStatus.active);
    });

    test('reduces stacked entitlements to active over trial', () {
      final result = pickHighestPriority([
        mk(SubscriptionStatus.trial, 'trial'),
        mk(SubscriptionStatus.active, 'paid'),
      ]);
      expect(result?.productId, 'paid');
    });

    test('keeps first when priorities tie', () {
      final result = pickHighestPriority([
        mk(SubscriptionStatus.active, 'first'),
        mk(SubscriptionStatus.active, 'second'),
      ]);
      expect(result?.productId, 'first');
    });
  });

  group('deriveSubscriptionFromSK2', () {
    final reference = DateTime.utc(2026, 5, 7, 12);

    test('returns null for transaction without expirationDate (consumable)',
        () {
      final result = deriveSubscriptionFromSK2(_tx(), now: reference);
      expect(result, isNull);
    });

    test('returns null for unparseable expirationDate', () {
      final result = deriveSubscriptionFromSK2(
        _tx(expirationDate: 'not-a-date'),
        now: reference,
      );
      expect(result, isNull);
    });

    test('marks active when expirationDate is in the future', () {
      final future = reference.add(const Duration(days: 30));
      final result = deriveSubscriptionFromSK2(
        _tx(
          productId: 'com.foo.yearly',
          expirationDate: future.toIso8601String(),
        ),
        now: reference,
      );
      expect(result?.isPaid, true);
      expect(result?.status, SubscriptionStatus.active);
      expect(result?.productId, 'com.foo.yearly');
      expect(result?.expiresAt, future.toIso8601String());
    });

    test('marks expired when expirationDate is in the past', () {
      final past = reference.subtract(const Duration(days: 1));
      final result = deriveSubscriptionFromSK2(
        _tx(
          productId: 'com.foo.lapsed',
          expirationDate: past.toIso8601String(),
        ),
        now: reference,
      );
      expect(result?.isPaid, false);
      expect(result?.status, SubscriptionStatus.expired);
      expect(result?.productId, 'com.foo.lapsed');
      expect(result?.expiresAt, past.toIso8601String());
    });

    test('treats expiration exactly equal to now as expired', () {
      final result = deriveSubscriptionFromSK2(
        _tx(expirationDate: reference.toIso8601String()),
        now: reference,
      );
      expect(result?.status, SubscriptionStatus.expired);
    });
  });
}
