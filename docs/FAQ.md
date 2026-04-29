# Frequently asked questions

The pinned [Q&A discussion](https://github.com/blokzdev/websight/discussions/categories/q-a)
is the right place to ask new questions. This file collects the
recurring ones so they are versioned, grep-able, and ranked by search.

---

## Should I "Use this template" or fork?

**Use this template** if you're shipping your own app:

- Click [**Use this template**](https://github.com/blokzdev/websight/generate)
  on GitHub → "Create a new repository".
- You get a fresh repo with no shared git history. You can keep it
  private; you can rewrite history; your commits don't appear in the
  upstream's contributor stats.
- This is the right path for ~99% of users.

**Fork** if you're contributing back upstream:

- Forks preserve the link to the upstream repo, which is what makes
  "open a PR back to `blokzdev/websight`" a one-click flow.
- Forks of public repos must themselves be public.
- If you ever want to send a fix or feature upstream, fork. Otherwise,
  use the template.

---

## How do I pull upstream updates after I used the template?

A repo created from a template has no upstream link, so GitHub can't
show a "sync" button. Add the upstream as a remote and merge
selectively:

```bash
git remote add upstream https://github.com/blokzdev/websight.git
git fetch upstream
git log --oneline main..upstream/main          # what's new upstream
git merge upstream/main                        # take everything, or
git cherry-pick <sha>                          # take specific commits
```

In practice: skim the [CHANGELOG](../CHANGELOG.md) of the version
you're catching up to, decide whether the changes are worth the merge
conflict, and either pull everything or cherry-pick. Most users only
do this when there's a security advisory or a feature they want.

---

## Does WebSight work on iOS?

Not yet. v1 is Android-only by design — the JS bridge, native
screens, FCM service, in-app updates, and the Gradle build all assume
Android tooling. iOS is on the v1.x roadmap; the most likely shape is
a parallel `ios/` Kotlin-Multiplatform-equivalent shell that consumes
the same `webview_config.yaml`.

If iOS is a hard requirement today, the closest commercial
alternatives are [Capacitor](https://capacitorjs.com),
[Median.co](https://median.co), and [PWABuilder](https://pwabuilder.com).

---

## How is this different from Capacitor / PWABuilder / Median?

- **Capacitor** is a hybrid framework: you build a web app *in* the
  Capacitor project, ship it inside a WebView, and call native plugins.
  WebSight wraps an *existing*, externally-hosted website — you don't
  bundle the web code.
- **PWABuilder** generates a Trusted Web Activity (TWA) shell. TWAs
  are extremely thin (Custom Tabs in disguise) and inherit Chrome's
  full chrome — no per-app drawer, FAB, AdMob, IAP, native barcode
  scanning, etc. WebSight's shell adds native UI you can't get in a
  TWA.
- **Median.co** is a paid SaaS that does roughly the same thing as
  WebSight. Different model: you fill a form on their site and they
  generate a binary. WebSight is OSS and config-driven; you own the
  source and the binary.

Pick the one whose constraints match yours.

---

## My CI fails on "Manifest sanity check" — what's wrong?

The check fails when `assets/webview_config.yaml`'s `app.host` doesn't
match the `<data android:host="...">` in
`android/app/src/main/AndroidManifest.xml`. Fix by re-running the
propagator after editing the YAML:

```bash
dart run tool/configure.dart
```

The check skips when `app.host` is still a template default
(`flutter.dev` or `YOUR_PRIMARY_HOST_HERE`), so a fresh clone of the
template won't fail this check.

---

## Where do I put my AdMob app id and unit ids?

Both live in `assets/webview_config.yaml`:

```yaml
app:
  admob_app_id: "ca-app-pub-XXXXXXXXXX~YYYYYYYYYY"   # the App ID (uses ~)

ads:
  enabled: true
  placements:
    global_banner:
      ad_unit_id: "ca-app-pub-XXXXXXXXXX/YYYYYYYYYY"  # a Unit ID (uses /)
```

After editing, run `dart run tool/configure.dart` to push the App ID
into `AndroidManifest.xml` (where it has to live by Android's
requirements). The Unit IDs stay in the YAML and are read at runtime;
the propagator does not touch them.

---

## Can I wrap a website I don't own?

Technically yes; legally it depends on three things:

1. **The site's terms of service.** Most prohibit "creating
   derivative works" or "framing" without permission. Read theirs.
2. **Trademark.** Listing the app under the site's name or logo
   without authorization is impersonation in Play Store eyes.
3. **Play Store category policies.** Wrappers of crypto / fintech /
   medical / news sites get extra scrutiny.

The [WHITELABEL guide §10](./WHITELABEL.md#10-non-technical-checks)
covers this in depth. The `legal:` block in
`assets/webview_config.yaml` adds an opt-in first-launch disclaimer
for the personal / dev / educational use case where you ship a
non-commercial wrapper for yourself.

---

## How do I add a custom JS bridge method?

Three places to touch:

1. **`assets/webview_config.yaml`** — add the method name to
   `js_bridge.methods`.
2. **`lib/bridge/js_bridge.dart`** — add a `case` in the dispatcher
   that handles the method and resolves / rejects the promise via
   `_resolveCallback` / `_rejectCallback` with a stable error code
   from `BridgeErrorCodes`.
3. **`android/app/src/main/kotlin/com/app/websight/MainActivity.kt`** —
   if the method needs platform code (camera, file system, intents,
   etc.), wire a method-channel handler. Otherwise it can be
   pure Dart.

Patterns to copy:

- `share` — pure Dart, uses `share_plus`.
- `getDeviceInfo` — pure Dart, uses `device_info_plus`.
- `scanBarcode` — Dart + native (launches a separate Activity).
- `downloadBlob` — Dart + native (worker thread + MediaStore).

Document the new method's contract in
[`docs/bridge-api.md`](./bridge-api.md) so the JS side has a
reference.

---

## What does the doctor warn vs fail?

`dart run tool/doctor.dart` reports three states per check:

- **OK** — the check passed.
- **WARN** — advisory, doesn't block CI. Examples: still using the
  AdMob test unit, still on the demo `flutter.dev` host. Real forks
  should resolve these before publishing.
- **FAIL** — hard fail; doctor exits 1 and CI fails. Examples: missing
  Flutter, missing Android SDK, broken `webview_config.yaml`.

Each result includes a one-line "fix" hint. Run it before opening a
PR or before a release build.

---

## Can I run multiple environments (dev / staging / prod)?

Not in v1 from a single binary. Two practical paths:

1. **Multiple repos.** Generate one repo per environment from the
   template; each gets its own `webview_config.yaml`. Simple,
   matches the "one app per repo" template model.
2. **Multiple YAMLs in one repo.** Maintain
   `assets/webview_config.dev.yaml` and `.prod.yaml`; copy the active
   one over `webview_config.yaml` before building. Rough, but works
   today. A first-class `--config` flag is on the v1.x roadmap.

Productflavors-per-environment (a single Gradle build with multiple
`applicationId` suffixes) is also viable but requires hand-editing
`android/app/build.gradle.kts` after `tool/configure.dart` runs —
the propagator is intentionally single-flavor today.

---

## What does the Apache 2.0 license actually let me do?

Short version (not legal advice — read the
[license itself](../LICENSE) for the binding text):

- **Use, modify, distribute, sublicense** — yes, including
  commercially. Ship your fork to the Play Store and charge for it.
- **Closed-source** your fork? — yes; Apache 2.0 doesn't require
  derivatives to be open-source.
- **Patent grant** — included; contributors grant you a license to
  any patents that read on their contributions.
- **Attribution** — include the LICENSE file and any NOTICE file in
  your distributed source. The compiled APK has no distribution
  obligation under Apache 2.0 since it's not "source code".
- **Trademark** — Apache 2.0 explicitly does not grant trademark
  rights. "WebSight" is the maintainer's mark; pick your own brand.

---

## How do I report a bug or security issue?

- **Bugs in WebSight itself** — open an
  [Issue](https://github.com/blokzdev/websight/issues) using the bug
  template. Include doctor output and a minimal repro.
- **Security vulnerabilities** — open a [private security
  advisory](https://github.com/blokzdev/websight/security/advisories/new).
  Don't file public issues for security. See
  [SECURITY.md](../SECURITY.md).
- **Open-ended questions** —
  [Discussions](https://github.com/blokzdev/websight/discussions).
  Don't file an Issue if you're not sure it's a bug.
- **Bugs in your fork's specific behavior** — most "bugs" forks hit
  are misconfiguration. Run `dart run tool/doctor.dart` first.

Response time is best-effort; this is a maintained-on-evenings
project.

---

## I think a question belongs here. How do I add it?

Open a PR adding it under the right heading, or post in
[Discussions](https://github.com/blokzdev/websight/discussions) and
ping the maintainer to promote. Questions that come up more than
twice belong here.
