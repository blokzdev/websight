import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:websight/config/webview_config.dart';

/// Manages the lifecycle of ads, including consent gathering, loading, and displaying ads.
class AdsController extends ChangeNotifier {
  final WebSightConfig config;
  final MethodChannel _platformChannel =
      const MethodChannel('websight/method_channel');

  bool _isMobileAdsSDKInitialized = false;
  bool get isMobileAdsSDKInitialized => _isMobileAdsSDKInitialized;

  final ValueNotifier<BannerAd?> currentBannerAd = ValueNotifier(null);
  AdPlacementConfig? _currentAdConfig;

  AdsController({required this.config});

  Future<void> initialize() async {
    if (!config.ads.enabled) {
      debugPrint('AdsController: Ads are disabled in the configuration.');
      return;
    }

    if (config.ads.consentGateWithUmp) {
      try {
        await _platformChannel.invokeMethod('gatherConsent');
        debugPrint('AdsController: Consent flow completed.');
      } on PlatformException catch (e) {
        debugPrint(
            'AdsController: Failed to gather consent: ${e.message}. Halting ads initialization.');
        return;
      }
    }

    await MobileAds.instance.initialize();
    _isMobileAdsSDKInitialized = true;
    notifyListeners();
    debugPrint('AdsController: Google Mobile Ads SDK initialized.');
  }

  Future<void> loadAdForRoute(String routePath,
      {required BuildContext context}) async {
    if (!_isMobileAdsSDKInitialized) {
      return;
    }

    final placement = _findPlacementForRoute(routePath);
    _currentAdConfig = placement;

    if (placement == null) {
      _disposeCurrentBanner();
      return;
    }

    _disposeCurrentBanner();

    final adRequest = AdRequest(
      extras: placement.format == 'banner_collapsible'
          ? {'collapsible': placement.position}
          : {},
    );

    final adSize = await _getAdSize(placement, context);
    if (adSize == null) return;

    final newBannerAd = BannerAd(
      adUnitId: placement.adUnitId,
      size: adSize,
      request: adRequest,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('AdsController: Banner ad loaded for ${ad.adUnitId}.');
          currentBannerAd.value = ad as BannerAd;
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('AdsController: Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
    await newBannerAd.load();
  }

  Future<AdSize?> _getAdSize(
      AdPlacementConfig placement, BuildContext context) async {
    // Both adaptive and collapsible banners use AnchoredAdaptiveBannerAdSize.
    // The collapsible behavior is triggered by the 'extras' in the AdRequest.
    if (placement.format == 'banner_adaptive' ||
        placement.format == 'banner_collapsible') {
      final width = MediaQuery.of(context).size.width.truncate();
      return AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait, // This can be made dynamic if needed
        width,
      );
    }
    // Fallback for any other format or as a default.
    return AdSize.banner;
  }

  AdPlacementConfig? _findPlacementForRoute(String routePath) {
    for (var entry in config.ads.placements.routePlacements.entries) {
      if (entry.value.route == routePath) {
        return entry.value;
      }
    }
    return config.ads.placements.globalBanner;
  }

  String get currentAdPosition => _currentAdConfig?.position ?? 'bottom';

  void _disposeCurrentBanner() {
    currentBannerAd.value?.dispose();
    currentBannerAd.value = null;
  }

  @override
  void dispose() {
    _disposeCurrentBanner();
    super.dispose();
  }
}
