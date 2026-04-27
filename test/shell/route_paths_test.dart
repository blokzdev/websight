import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/shell/route_paths.dart';

RouteConfig _route(String path, {String kind = 'webview', String? url}) {
  return RouteConfig(
    path: path,
    kind: kind,
    title: 't',
    url: url,
    pullToRefresh: false,
    appbarVisible: true,
  );
}

void main() {
  group('yamlPathToGoRouter', () {
    test('passes static paths through', () {
      expect(yamlPathToGoRouter('/web/home'), '/web/home');
    });
    test('rewrites a single brace param', () {
      expect(yamlPathToGoRouter('/web/item/{id}'), '/web/item/:id');
    });
    test('rewrites multiple brace params', () {
      expect(
        yamlPathToGoRouter('/web/{section}/item/{id}'),
        '/web/:section/item/:id',
      );
    });
    test('leaves underscored param names intact', () {
      expect(yamlPathToGoRouter('/x/{user_id}'), '/x/:user_id');
    });
  });

  group('stripParameterizedTail', () {
    test('passes static paths through', () {
      expect(stripParameterizedTail('/web/home'), '/web/home');
    });
    test('strips trailing parameter segments', () {
      expect(stripParameterizedTail('/web/item/:id'), '/web/item');
    });
    test('handles nested params at any depth', () {
      expect(stripParameterizedTail('/a/:b/c'), '/a');
    });
    test('returns the original when path begins with a param', () {
      expect(stripParameterizedTail('/:id'), '/:id');
    });
  });

  group('routeMatchesPattern', () {
    test('exact match', () {
      expect(routeMatchesPattern('/web/home', '/web/home'), isTrue);
    });
    test('parameter slot matches a non-slash run', () {
      expect(routeMatchesPattern('/web/item/:id', '/web/item/123'), isTrue);
      expect(routeMatchesPattern('/web/item/:id', '/web/item/abc-def'), isTrue);
    });
    test('parameter slot does not match across slashes', () {
      expect(
        routeMatchesPattern('/web/item/:id', '/web/item/123/extra'),
        isFalse,
      );
    });
    test('different prefix is rejected', () {
      expect(routeMatchesPattern('/web/item/:id', '/native/item/1'), isFalse);
    });
    test('returns false for non-pattern mismatch', () {
      expect(routeMatchesPattern('/a', '/b'), isFalse);
    });
  });

  group('substituteUrlParams', () {
    test('replaces a single token', () {
      expect(
        substituteUrlParams('https://x/#/i/{id}', const {'id': '7'}),
        'https://x/#/i/7',
      );
    });
    test('replaces multiple tokens', () {
      expect(
        substituteUrlParams('/a/{x}/b/{y}', const {'x': '1', 'y': '2'}),
        '/a/1/b/2',
      );
    });
    test('missing keys collapse to empty string (no leaked literal)', () {
      expect(substituteUrlParams('/a/{id}', const {}), '/a/');
    });
    test('templates without tokens pass through', () {
      expect(substituteUrlParams('/a/b', const {}), '/a/b');
    });
  });

  group('isAllowedNavigationTarget', () {
    final routes = [
      _route('/web/home'),
      _route('/web/item/:id'),
      _route('/native/settings', kind: 'native'),
    ];

    test('allows literal route paths', () {
      expect(isAllowedNavigationTarget('/web/home', routes), isTrue);
      expect(isAllowedNavigationTarget('/native/settings', routes), isTrue);
    });

    test('allows parameterized matches', () {
      expect(isAllowedNavigationTarget('/web/item/abc', routes), isTrue);
      expect(isAllowedNavigationTarget('/web/item/42', routes), isTrue);
    });

    test('rejects targets outside the route table', () {
      expect(isAllowedNavigationTarget('/native/admin', routes), isFalse);
      expect(isAllowedNavigationTarget('/web/home/extra', routes), isFalse);
    });

    test('rejects empty / non-absolute paths', () {
      expect(isAllowedNavigationTarget('', routes), isFalse);
      expect(isAllowedNavigationTarget('relative/path', routes), isFalse);
    });

    test('rejects when route table is empty', () {
      expect(
        isAllowedNavigationTarget('/web/home', const <RouteConfig>[]),
        isFalse,
      );
    });
  });
}
