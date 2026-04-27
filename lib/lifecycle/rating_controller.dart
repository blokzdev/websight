import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:websight/config/feature_configs.dart';

/// Tracks app launches and triggers the in-app review prompt once the
/// configured threshold is reached. The Play in-app review API is rate-limited
/// by the OS, so [maybePromptOnLaunch] is safe to call on every cold start.
class RatingController {
  RatingController({required this.feature});

  final RatingPromptFeature feature;
  static const String _prefsKey = 'websight.launch_count';
  static const String _promptedKey = 'websight.review_prompted';

  Future<void> maybePromptOnLaunch() async {
    if (!feature.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    final launches = (prefs.getInt(_prefsKey) ?? 0) + 1;
    await prefs.setInt(_prefsKey, launches);

    final alreadyPrompted = prefs.getBool(_promptedKey) ?? false;
    if (alreadyPrompted) return;
    if (launches < feature.afterLaunches) return;

    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await prefs.setBool(_promptedKey, true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('RatingController: $e');
    }
  }
}
