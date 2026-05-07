import 'dart:async';

import 'package:feddy_flutter/src/iap_stream_listener.dart';
import 'package:feddy_flutter/src/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

PurchaseDetails _purchase({
  String productID = 'com.test.monthly',
  PurchaseStatus status = PurchaseStatus.purchased,
}) =>
    PurchaseDetails(
      productID: productID,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: '0',
      status: status,
    );

void main() {
  group('isLikelySubscriptionJson', () {
    test('returns true on null / empty (unknown → accept)', () {
      expect(isLikelySubscriptionJson(null), true);
      expect(isLikelySubscriptionJson(''), true);
    });

    test('returns true when JSON has autoRenewing key (subscription)', () {
      expect(
        isLikelySubscriptionJson('{"productId":"x","autoRenewing":true}'),
        true,
      );
      expect(
        isLikelySubscriptionJson('{"autoRenewing":false}'),
        true,
      );
    });

    test('returns false when JSON omits autoRenewing (likely consumable)', () {
      expect(
        isLikelySubscriptionJson(
          '{"productId":"x","purchaseToken":"t","acknowledged":true}',
        ),
        false,
      );
    });

    test('returns true on parse failure (false-positive over false-negative)',
        () {
      expect(isLikelySubscriptionJson('not json'), true);
      expect(isLikelySubscriptionJson('{broken'), true);
    });
  });

  group('deriveSubscriptionFromPurchaseDetails', () {
    test('returns null for pending status', () {
      final result = deriveSubscriptionFromPurchaseDetails(
        _purchase(status: PurchaseStatus.pending),
      );
      expect(result, isNull);
    });

    test('returns null for canceled status', () {
      final result = deriveSubscriptionFromPurchaseDetails(
        _purchase(status: PurchaseStatus.canceled),
      );
      expect(result, isNull);
    });

    test('returns null for error status', () {
      final result = deriveSubscriptionFromPurchaseDetails(
        _purchase(status: PurchaseStatus.error),
      );
      expect(result, isNull);
    });

    test('marks paid for purchased status', () {
      final result = deriveSubscriptionFromPurchaseDetails(
        _purchase(productID: 'com.foo.monthly'),
      );
      expect(result?.isPaid, true);
      expect(result?.status, SubscriptionStatus.active);
      expect(result?.productId, 'com.foo.monthly');
      expect(result?.expiresAt, isNull);
    });

    test('marks paid for restored status', () {
      final result = deriveSubscriptionFromPurchaseDetails(
        _purchase(
          productID: 'com.foo.yearly',
          status: PurchaseStatus.restored,
        ),
      );
      expect(result?.isPaid, true);
      expect(result?.status, SubscriptionStatus.active);
      expect(result?.productId, 'com.foo.yearly');
    });
  });

  group('IapStreamListener integration', () {
    late StreamController<List<PurchaseDetails>> controller;
    late int restoreCalls;
    late List<Subscription?> resolved;
    late IapStreamListener listener;

    setUp(() {
      controller = StreamController<List<PurchaseDetails>>.broadcast();
      restoreCalls = 0;
      resolved = <Subscription?>[];
      listener = IapStreamListener(
        onResolved: (sub) async {
          resolved.add(sub);
        },
        streamProvider: () => controller.stream,
        restoreTrigger: () async {
          restoreCalls++;
        },
        debounceWindow: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await listener.stop();
      await controller.close();
    });

    test('start() triggers restorePurchases once', () async {
      await listener.start();
      expect(restoreCalls, 1);
    });

    test('start() is idempotent', () async {
      await listener.start();
      await listener.start();
      expect(restoreCalls, 1);
    });

    test('refresh() re-triggers restorePurchases', () async {
      await listener.start();
      await listener.refresh();
      await listener.refresh();
      expect(restoreCalls, 3);
    });

    test('refresh() is a no-op when listener was never started', () async {
      await listener.refresh();
      expect(restoreCalls, 0);
    });

    test('debounces a single batch of events to one onResolved call', () async {
      await listener.start();
      controller.add([
        _purchase(
          productID: 'com.foo.monthly',
          status: PurchaseStatus.restored,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resolved.length, 1);
      expect(resolved.single?.productId, 'com.foo.monthly');
      expect(resolved.single?.status, SubscriptionStatus.active);
    });

    test('coalesces multiple events within the debounce window', () async {
      await listener.start();
      controller.add([_purchase(productID: 'com.foo.monthly')]);
      controller.add([
        _purchase(
          productID: 'com.foo.yearly',
          status: PurchaseStatus.restored,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resolved.length, 1);
      // Both events have status=active priority; reducer keeps first.
      expect(resolved.single?.productId, 'com.foo.monthly');
    });

    test('ignores pending / canceled events', () async {
      await listener.start();
      controller.add([
        _purchase(status: PurchaseStatus.pending),
        _purchase(status: PurchaseStatus.canceled),
        _purchase(status: PurchaseStatus.error),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resolved, isEmpty);
    });

    test('stop() cancels the stream subscription', () async {
      await listener.start();
      await listener.stop();
      controller.add([_purchase()]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resolved, isEmpty);
    });

    test('stop() flushes pending debounce timer without firing', () async {
      await listener.start();
      controller.add([_purchase()]);
      await listener.stop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resolved, isEmpty);
    });
  });
}
