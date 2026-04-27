import 'dart:async';

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
        onError: (Object e) {
          if (kDebugMode) debugPrint('BillingController stream error: $e');
        },
      );

      await refreshProducts();
    } catch (e, st) {
      if (kDebugMode) debugPrint('BillingController init failed: $e\n$st');
    }
  }

  Future<void> refreshProducts() async {
    if (feature.productIds.isEmpty) return;
    final response = await _iap.queryProductDetails(feature.productIds.toSet());
    _products = response.productDetails;
    notifyListeners();
  }

  Future<bool> buy(String productId, {bool consumable = false}) async {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw StateError('Unknown product: $productId'),
    );
    final params = PurchaseParam(productDetails: product);
    return consumable
        ? _iap.buyConsumable(purchaseParam: params)
        : _iap.buyNonConsumable(purchaseParam: params);
  }

  Future<void> restore() => _iap.restorePurchases();

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
