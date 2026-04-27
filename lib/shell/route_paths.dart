// Route-pattern utilities shared by the router (path → go_router pattern,
// initial-location stripping, URL templating) and the JS bridge
// (navigation-target allowlist for inbound `navigate:{route}` events).
//
// These were duplicated and private across three call-sites; pulling them
// into one file lets us unit-test them without spinning up a router or a
// WebView.

import 'package:websight/config/webview_config.dart';

/// Convert YAML-style `/web/item/{id}` into the go_router-style
/// `/web/item/:id` so it participates in path-parameter matching.
String yamlPathToGoRouter(String path) {
  return path.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => ':${m.group(1)}',
  );
}

/// Best-effort initial-location for a parameterized path. `/web/item/:id`
/// becomes `/web/item`. Paths with no parameters are returned unchanged.
/// Paths that begin with a parameter (no static prefix) are returned
/// unchanged too — there's no useful prefix to land on.
String stripParameterizedTail(String path) {
  final i = path.indexOf(':');
  if (i < 0) return path;
  final base = path.substring(0, i).trimRight();
  if (base.isEmpty) return path;
  return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
}

/// True when [path] matches [pattern], treating `:name` segments as
/// "any non-slash run". Used by both the navigation allowlist and the
/// shell's current-route resolver.
bool routeMatchesPattern(String pattern, String path) {
  if (pattern == path) return true;
  if (!pattern.contains(':')) return false;
  final regex = RegExp(
    '^${pattern.replaceAllMapped(RegExp(r':\w+'), (_) => r'[^/]+')}\$',
  );
  return regex.hasMatch(path);
}

/// Replace `{name}` tokens in [template] with the matching entry from
/// [params]. Missing keys collapse to the empty string so a partial
/// substitution doesn't leak the literal `{id}` into the URL the WebView
/// loads.
String substituteUrlParams(String template, Map<String, String> params) {
  return template.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => params[m.group(1)!] ?? '',
  );
}

/// Returns true when [target] is a path the host is willing to navigate to
/// in response to a JS-bridge `navigate:` action. Matches an explicit route
/// in [routes] either literally or via [routeMatchesPattern]. The check is
/// allow-listy — anything not in the route table is rejected.
bool isAllowedNavigationTarget(
  String target,
  Iterable<RouteConfig> routes,
) {
  if (target.isEmpty || !target.startsWith('/')) return false;
  for (final r in routes) {
    if (r.path == target) return true;
    if (r.path.contains(':') && routeMatchesPattern(r.path, target)) {
      return true;
    }
  }
  return false;
}
