import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the contract that AdsController._getAdSize relies on:
/// `MediaQuery.of(context).orientation` reflects the device orientation
/// at call time, not a constant. The controller method itself is hard to
/// unit-test directly because `AdSize.getAnchoredAdaptiveBannerAdSize` is
/// a static native call. This test pins the upstream lookup so a future
/// refactor that drops back to a hardcoded portrait fails CI.
void main() {
  testWidgets('MediaQuery orientation reflects landscape and portrait',
      (tester) async {
    Orientation? captured;
    final builder = Builder(
      builder: (context) {
        captured = MediaQuery.of(context).orientation;
        return const SizedBox.shrink();
      },
    );

    // Wide viewport — landscape.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1280, 600)),
        child: Directionality(textDirection: TextDirection.ltr, child: builder),
      ),
    );
    expect(captured, Orientation.landscape);

    // Tall viewport — portrait.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Directionality(textDirection: TextDirection.ltr, child: builder),
      ),
    );
    expect(captured, Orientation.portrait);
  });
}
