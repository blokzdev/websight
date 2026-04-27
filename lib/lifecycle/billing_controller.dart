import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:websight/config/feature_configs.dart';

/// Thin wrapper around `in_app_purchase` for the YAML-declared product list.
///
/// v1 ships client-side only; integrators are responsible for receipt
/// validation against their backend or Play Developer API. The controller
/// surfaces purchase events so the JS bridge / shell can react.
class BillingController extends ChangeNotifier {
  BillingController({required this.feature});

  final BillingFeature feature;
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _available = false;
  List<ProductDetails> _products = const <ProductDetails>[];
  final List<PurchaseDetails> _purchases = <PurchaseDetails>[];

  /// The most recent error reported by the IAP layer, if any. Cleared on
  /// successful operations. Surfaces to UI so integrators can show a
  /// "We couldn't reach the Play Store" banner without polling.
  Object? _lastError;
  Object? get lastError => _lastError;

  bool get available => _available;
  List<ProductDetails> get products => List<ProductDetails>.unmodifiable(_products);
  List<PurchaseDetails> get purchases => List<PurchaseDetails>.unmodifiable(_purchases);

  Future<void> initialize() async {
    if (!feature.enabled) return;
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        notifyListeners();
        return;
      }

      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchasesUpdated,
        onDone: () => _purchaseSub?.cancel(),
        onError: (Object e, StackTrace st) => _recordError('purchaseStream', e, st),
      );

      await refreshProducts();
    } catch (e, st) {
      _recordError('initialize', e, st);
    }
  }

  /// Stores the error for UI consumption AND ships it to Crashlytics so
  /// release-build failures aren't silent in production. Crashlytics
  /// rejection itself never throws (it no-ops if Firebase isn't wired);
  /// any failure inside that path is swallowed to keep billing surface
  /// independent of analytics availability.
  void _recordError(String where, Object e, StackTrace st) {
    _lastError = e;
    notifyListeners();
    if (kDebugMode) debugPrint('BillingController.$where: $e\n$st');
    try {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'BillingController.$where',
        fatal: false,
      );
    } catch (_) {
      // ignore: Crashlytics not configured / Firebase not initialized
    }
  }

  Future<void> refreshProducts() async {
    if (feature.productIds.isEmpty) return;
    try {
      final response =
          await _iap.queryProductDetails(feature.productIds.toSet());
      _products = response.productDetails;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _recordError('refreshProducts', e, st);
    }
  }

  Future<bool> buy(String productId, {bool consumable = false}) async {
    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw StateError('Unknown product: $productId'),
      );
      final params = PurchaseParam(productDetails: product);
      _lastError = null;
      notifyListeners();
      return consumable
          ? _iap.buyConsumable(purchaseParam: params)
          : _iap.buyNonConsumable(purchaseParam: params);
    } catch (e, st) {
      _recordError('buy($productId)', e, st);
      rethrow;
    }
  }

  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _recordError('restore', e, st);
      rethrow;
    }
  }

  void _onPurchasesUpdated(List<PurchaseDetails> updates) {
    for (final p in updates) {
      if (p.status == PurchaseStatus.pending) continue;
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
      _purchases.add(p);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
