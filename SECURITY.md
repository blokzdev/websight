# Security Policy

## Reporting a vulnerability

**Please do not file public GitHub issues for security problems.**

If you've found a vulnerability in WebSight — the JS bridge, FCM
handling, in-app purchase flow, manifest configuration, or any other
attack-relevant surface — open a [private security advisory] on
GitHub. We aim to acknowledge within 5 business days and ship a fix
or workaround within 30 days for confirmed issues.

[private security advisory]: https://github.com/blokzdev/websight/security/advisories/new

When you report, please include:

- A clear description of the issue and its impact
- Steps to reproduce (a minimal `webview_config.yaml` and the
  triggering URL or JS payload, when applicable)
- Affected version (commit SHA or release tag)
- Your environment: Flutter version, Android API level, device/emulator
- Proposed fix, if you have one (optional)

## Scope

In scope:

- The Flutter shell and JS bridge in `lib/`
- The native Kotlin code in `android/app/src/main/kotlin/`
- The setup tooling in `tool/` (configure, init, doctor)
- The default configuration values shipped in `assets/`

Out of scope:

- Vulnerabilities in third-party dependencies (report upstream;
  Dependabot will pick up patched versions)
- Issues in user forks that stem from misconfiguration (placeholder
  AdMob IDs, missing `restrict_to_hosts`, disabled UMP). Run
  `dart run tool/doctor.dart` to surface those.
- The websites you wrap. WebSight is a shell — site-level XSS, CSRF,
  or auth bugs are the site owner's responsibility.

## Disclosure

Once a fix is released, the advisory is published with a CVE if
warranted. Reporters are credited unless they request otherwise.
