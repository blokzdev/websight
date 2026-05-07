import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/lifecycle/system_chrome_controller.dart';

/// These tests verify the controller wires the right `SystemChrome` calls
/// for each YAML mode, without depending on a running engine. We capture
/// the platform messages on the `SystemChrome` channel.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> apply(SystemUiFeature feature, Brightness brightness) async {
    final controller = SystemChromeController(feature: feature);
    await controller.applyForBrightness(brightness);
  }

  // Flutter's `SystemChrome.setEnabledSystemUIMode` decomposes into different
  // platform-channel calls depending on the mode: non-manual modes invoke
  // `SystemChrome.setEnabledSystemUIMode` with the mode name as a *String*
  // payload, while `manual` skips that and instead invokes
  // `SystemChrome.setEnabledSystemUIOverlays` with the overlays list. Tests
  // below assert the right call shape for each mode.

  test('edge_to_edge calls SystemChrome.setEnabledSystemUIMode edgeToEdge',
      () async {
    final feature = SystemUiFeature.fromMap(null); // default = edge_to_edge
    await apply(feature, Brightness.dark);

    final modeCall = calls.firstWhere(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
      orElse: () => const MethodCall(''),
    );
    expect(modeCall.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(modeCall.arguments, 'SystemUiMode.edgeToEdge');
  });

  test('immersive_sticky maps to SystemUiMode.immersiveSticky', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{'mode': 'immersive_sticky'}),
      Brightness.dark,
    );
    final modeCall = calls.firstWhere(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
    );
    expect(modeCall.arguments, 'SystemUiMode.immersiveSticky');
  });

  test('default mode maps to SystemUiMode.manual with both overlays', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{'mode': 'default'}),
      Brightness.light,
    );
    final overlaysCall = calls.firstWhere(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays',
    );
    final overlays = (overlaysCall.arguments as List).cast<String>();
    expect(
      overlays,
      containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']),
    );
  });

  test('hiding the status bar drops it from the manual overlays', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{
        'mode': 'default',
        'status_bar': {'visible': false},
      }),
      Brightness.dark,
    );
    final overlaysCall = calls.firstWhere(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays',
    );
    final overlays = (overlaysCall.arguments as List).cast<String>();
    expect(overlays.contains('SystemUiOverlay.top'), isFalse);
    expect(overlays.contains('SystemUiOverlay.bottom'), isTrue);
  });

  test('auto icon_brightness flips with the active theme brightness', () {
    expect(
      SystemChromeController.iconBrightnessForTest('auto',
          themeBrightness: Brightness.dark),
      Brightness.light,
    );
    expect(
      SystemChromeController.iconBrightnessForTest('auto',
          themeBrightness: Brightness.light),
      Brightness.dark,
    );
  });

  test('explicit light/dark icon_brightness ignore the theme', () {
    expect(
      SystemChromeController.iconBrightnessForTest('light',
          themeBrightness: Brightness.light),
      Brightness.light,
    );
    expect(
      SystemChromeController.iconBrightnessForTest('dark',
          themeBrightness: Brightness.dark),
      Brightness.dark,
    );
  });
}
