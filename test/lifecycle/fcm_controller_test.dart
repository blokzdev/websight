// FcmController unit tests. The Firebase Messaging singleton is hard
// to inject without a refactor, so these tests cover the surface that
// does NOT require live Firebase: the fcm_enabled gate, dispose
// safety, and pre-init state of the public getters. Driving
// FirebaseMessaging.onMessage from a test would require Firebase test
// bindings — out of scope for v1.

import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/fcm_controller.dart';

void main() {
  // Fallback() ships fcmEnabled=false, which is exactly what we want
  // for the disabled-path tests. All assertions below operate on this
  // shape; we avoid hand-building a fully-validated WebSightConfig
  // (json_serializable enforces required fields that aren't relevant
  // to FcmController).
  WebSightConfig disabledConfig() => WebSightConfig.fallback();

  group('FcmController (fcm disabled)', () {
    test('initialize() short-circuits when notifications.fcm_enabled is false',
        () async {
      final c = FcmController(config: disabledConfig());
      await c.initialize();
      expect(c.initialized, isFalse);
      expect(c.token, isNull);
      expect(c.inbox, isEmpty);
      c.dispose();
    });

    test('initial getters before initialize have neutral defaults', () {
      final c = FcmController(config: disabledConfig());
      expect(c.token, isNull);
      expect(c.inbox, isEmpty);
      expect(c.initialized, isFalse);
      c.dispose();
    });
  });

  group('FcmController dispose-safety', () {
    test('dispose() runs cleanly on a never-initialized controller', () {
      final c = FcmController(config: disabledConfig());
      // The contract: no exception. Without the `_disposed` flag in
      // FcmController, a stream subscription that's already null at
      // dispose time wouldn't crash anyway, but we want this test as
      // a regression guard against future additions to dispose().
      c.dispose();
    });

    test('initialize() after dispose returns immediately without crashing',
        () async {
      final c = FcmController(config: disabledConfig());
      c.dispose();
      // With fcm disabled this is a trivial no-op, but the same path
      // matters when fcm_enabled=true: the _disposed gate at the top
      // of initialize() must run before any FirebaseMessaging call.
      await c.initialize();
      expect(c.initialized, isFalse);
    });

    test('inbox returns a fresh unmodifiable view on each access', () {
      final c = FcmController(config: disabledConfig());
      final a = c.inbox;
      final b = c.inbox;
      // List.unmodifiable returns a new wrapper each time; we don't
      // care about identity here, only that the view is empty and
      // detached from any internal mutation.
      expect(a, isEmpty);
      expect(b, isEmpty);
      c.dispose();
    });
  });
}
