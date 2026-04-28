import 'package:flutter/material.dart' hide ActionDispatcher;
import 'package:flutter_test/flutter_test.dart';
import 'package:websight/shell/action_dispatcher.dart';

void main() {
  group('ActionDispatcher', () {
    testWidgets('webview.reload calls onWebviewReload', (tester) async {
      var calls = 0;
      final dispatcher = ActionDispatcher(onWebviewReload: () => calls++);
      await _runWithContext(tester, (ctx) {
        dispatcher.dispatch(ctx, 'webview.reload');
      });
      expect(calls, 1);
    });

    testWidgets('webview.back calls onWebviewBack', (tester) async {
      var calls = 0;
      final dispatcher = ActionDispatcher(onWebviewBack: () => calls++);
      await _runWithContext(tester, (ctx) {
        dispatcher.dispatch(ctx, 'webview.back');
      });
      expect(calls, 1);
    });

    testWidgets('bridge.<method>(args) extracts method name', (tester) async {
      String? capturedMethod;
      final dispatcher = ActionDispatcher(
        onBridgeCall: (m, _) => capturedMethod = m,
      );
      await _runWithContext(tester, (ctx) {
        dispatcher.dispatch(ctx, 'bridge.scanBarcode(callback)');
      });
      expect(capturedMethod, 'scanBarcode');
    });

    testWidgets('null / empty / noop are no-ops', (tester) async {
      var calls = 0;
      final dispatcher = ActionDispatcher(
        onWebviewReload: () => calls++,
        onWebviewBack: () => calls++,
        onBridgeCall: (_, __) => calls++,
      );
      await _runWithContext(tester, (ctx) {
        dispatcher.dispatch(ctx, null);
        dispatcher.dispatch(ctx, '');
        dispatcher.dispatch(ctx, 'noop');
      });
      expect(calls, 0);
    });
  });
}

Future<void> _runWithContext(
  WidgetTester tester,
  void Function(BuildContext context) body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          body(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}
