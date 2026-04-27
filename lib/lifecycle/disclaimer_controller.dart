import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:websight/config/feature_configs.dart';

/// Tracks whether the user has accepted the unofficial-app disclaimer for
/// the current text. Acceptance is keyed on a hash of the body text so
/// editing the disclaimer in YAML re-prompts users on next launch — no
/// manual version bumping.
///
/// Stored in `SharedPreferences` under
/// `websight.disclaimer.accepted.<bodyDigest>`.
class DisclaimerController extends ChangeNotifier {
  DisclaimerController({required this.feature});

  final UnofficialDisclaimerFeature feature;

  static const String _prefix = 'websight.disclaimer.accepted.';

  bool _accepted = false;
  bool _loaded = false;

  /// True when the current disclaimer text has been accepted on this
  /// device. Always true when the feature is disabled — the gate then
  /// passes through transparently.
  bool get accepted => _accepted;

  /// True after [load] has finished. Until this is true, the gate shows
  /// a brief themed splash to avoid flashing the WebView under the
  /// dialog.
  bool get loaded => _loaded;

  Future<void> load() async {
    if (!feature.enabled) {
      _accepted = true;
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _accepted = prefs.getBool('$_prefix${feature.bodyDigest}') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('DisclaimerController.load: $e');
      _accepted = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> markAccepted() async {
    _accepted = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix${feature.bodyDigest}', true);
    } catch (e) {
      if (kDebugMode) debugPrint('DisclaimerController.markAccepted: $e');
    }
  }

  /// Reset acceptance — exposed for QA / settings-page "show again"
  /// affordances. Not currently called from UI.
  Future<void> reset() async {
    _accepted = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix${feature.bodyDigest}');
    } catch (e) {
      if (kDebugMode) debugPrint('DisclaimerController.reset: $e');
    }
  }
}
