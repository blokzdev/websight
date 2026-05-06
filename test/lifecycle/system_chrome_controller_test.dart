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
    TestDefaultBinaryMessengerBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> apply(SystemUiFeature feature, Brightness brightness) async {
    final controller = SystemChromeController(feature: feature);
    await controller.applyForBrightness(brightness);
  }

  test('edge_to_edge calls SystemChrome.setEnabledSystemUIMode edgeToEdge',
      () async {
    final feature = SystemUiFeature.fromMap(null); // default = edge_to_edge
    await apply(feature, Brightness.dark);

    final modeCall = calls.firstWhere(
      (c) => c.method == 'SystemChrome.setEnabledSystemUIMode',
      orElse: () => const MethodCall(''),
    );
    expect(modeCall.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(
      (modeCall.arguments as Map)['mode'],
      'SystemUiMode.edgeToEdge',
    );
  });

  test('immersive_sticky maps to SystemUiMode.immersiveSticky', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{'mode': 'immersive_sticky'}),
      Brightness.dark,
    );
    final modeCall =
        calls.firstWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
    expect(
      (modeCall.arguments as Map)['mode'],
      'SystemUiMode.immersiveSticky',
    );
  });

  test('default mode maps to SystemUiMode.manual with both overlays', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{'mode': 'default'}),
      Brightness.light,
    );
    final modeCall =
        calls.firstWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
    final args = modeCall.arguments as Map;
    expect(args['mode'], 'SystemUiMode.manual');
    final overlays = (args['overlays'] as List).cast<String>();
    expect(overlays, containsAll(<String>['SystemUiOverlay.top', 'SystemUiOverlay.bottom']));
  });

  test('hiding the status bar drops it from the manual overlays', () async {
    await apply(
      SystemUiFeature.fromMap(<String, dynamic>{
        'mode': 'default',
        'status_bar': {'visible': false},
      }),
      Brightness.dark,
    );
    final modeCall =
        calls.firstWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode');
    final args = modeCall.arguments as Map;
    final overlays = (args['overlays'] as List).cast<String>();
    expect(overlays.contains('SystemUiOverlay.top'), isFalse);
    expect(overlays.contains('SystemUiOverlay.bottom'), isTrue);
  });

  test('auto icon_brightness flips with the active theme brightness', () {
    expect(
      SystemChromeController.iconBrightnessForTest(
          'auto', themeBrightness: Brightness.dark),
      Brightness.light,
    );
    expect(
      SystemChromeController.iconBrightnessForTest(
          'auto', themeBrightness: Brightness.light),
      Brightness.dark,
    );
  });

  test('explicit light/dark icon_brightness ignore the theme', () {
    expect(
      SystemChromeController.iconBrightnessForTest(
          'light', themeBrightness: Brightness.light),
      Brightness.light,
    );
    expect(
      SystemChromeController.iconBrightnessForTest(
          'dark', themeBrightness: Brightness.dark),
      Brightness.dark,
    );
  });
}
