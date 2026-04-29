// BillingController unit tests. The IAP plugin is a singleton that's
// hard to inject without a refactor, so we test the surface that does
// not require platform calls: the feature.enabled gate, the dispose
// path, and the lastError lifecycle.
//
// Deeper coverage (mocking InAppPurchasePlatform to drive the purchase
// stream) is a v1.x follow-up; the immediate goal here is to lock in
// the `_disposed` guard so post-dispose stream events don't crash the
// app.

import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/lifecycle/billing_controller.dart';

void main() {
  group('BillingController (feature disabled)', () {
    test('initialize() short-circuits without touching IAP', () async {
      final c = BillingController(
        feature: const BillingFeature(enabled: false, productIds: []),
      );
      // Should complete without throwing. With feature.enabled=false,
      // initialize never asks InAppPurchase for anything.
      await c.initialize();
      expect(c.available, isFalse);
      expect(c.lastError, isNull);
      expect(c.products, isEmpty);
      expect(c.purchases, isEmpty);
      c.dispose();
    });

    test('refreshProducts() with empty productIds is a no-op', () async {
      final c = BillingController(
        feature: const BillingFeature(enabled: false, productIds: []),
      );
      await c.refreshProducts();
      expect(c.lastError, isNull);
      expect(c.products, isEmpty);
      c.dispose();
    });
  });

  group('BillingController dispose-safety', () {
    test('dispose() can be called immediately without crashing', () {
      final c = BillingController(
        feature: const BillingFeature(enabled: false, productIds: []),
      );
      c.dispose();
      // Calling dispose a second time would throw if super.dispose
      // tracking didn't work; we just want to confirm the first call
      // is clean.
    });

    test('post-dispose buy() returns false instead of touching disposed state',
        () async {
      final c = BillingController(
        feature: const BillingFeature(enabled: true, productIds: ['p1']),
      );
      c.dispose();
      // Without the `_disposed` guard this would call notifyListeners
      // on a disposed ChangeNotifier and throw "A ChangeNotifier was
      // used after being disposed."
      final result = await c.buy('p1');
      expect(result, isFalse);
    });

    test('post-dispose restore() returns silently', () async {
      final c = BillingController(
        feature: const BillingFeature(enabled: true, productIds: ['p1']),
      );
      c.dispose();
      // Same disposal-safety contract as buy(). Should not throw.
      await c.restore();
    });

    test('post-dispose refreshProducts() returns silently', () async {
      final c = BillingController(
        feature: const BillingFeature(enabled: true, productIds: ['p1']),
      );
      c.dispose();
      await c.refreshProducts();
      // No explicit assertion: the fact that the call completed
      // without an exception is the contract we're testing.
    });
  });
}
