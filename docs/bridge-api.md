# `WebSightBridge` JavaScript API

Injected into every WebView page on `pageFinished` when the JS bridge is
enabled and the current origin is in `security.restrict_to_hosts`. The
global name is configurable via `js_bridge.name` (default
`WebSightBridge`).

## Call shape

Every method returns a `Promise`. On success the promise resolves with
the value listed below. On failure it rejects with an object of the form:

```js
{ code: 'E_INTERNAL', message: 'human-readable description' }
```

### Stable error codes

| Code            | Meaning |
| --------------- | -------------------------------------------------------------------- |
| `E_PERMISSION`  | The user denied a runtime permission required for the call. |
| `E_CANCELED`    | The user dismissed a system UI (file picker, scanner, etc.). |
| `E_ARGS`        | The caller supplied bad / missing arguments. |
| `E_INTERNAL`    | Anything thrown internally — see `message` for details. |
| `E_ORIGIN`      | The page's origin is not in `security.restrict_to_hosts`. |
| `E_UNSUPPORTED` | The method is unknown, or the platform cannot fulfill the request. |

## Methods

### `scanBarcode()` → `string`

Launches the native scanner activity (CameraX + ML Kit). Resolves with
the decoded barcode value. Rejects with `E_CANCELED` if the user backs
out.

```js
const code = await WebSightBridge.scanBarcode();
console.log('Scanned:', code);
```

### `share(text)` → `true`

Opens the system share sheet with `text` pre-populated.

```js
await WebSightBridge.share('Check this out: https://example.com');
```

### `getDeviceInfo()` → `{ os, release, sdkInt, manufacturer, model, isPhysical, fingerprint }`

```js
const info = await WebSightBridge.getDeviceInfo();
// { os: 'Android', release: '14', sdkInt: 34, manufacturer: 'Google', model: 'Pixel 8', ... }
```

### `downloadBlob(blobUrl, filename?, mimeType?)` → `string`

Fetches `blobUrl` (typically a `blob:` URL but `http(s):` works too),
base64-encodes it in the page, hands the payload to native code which
writes it to `MediaStore.Downloads` on API 29+ or to the legacy
`Downloads/` directory on older devices. Resolves with the resulting
`content://` or `file://` URI.

```js
const csv = new Blob([data], { type: 'text/csv' });
const url = URL.createObjectURL(csv);
await WebSightBridge.downloadBlob(url, 'export.csv', 'text/csv');
```

### `openExternal(url)` → `true`

Opens `url` in Chrome Custom Tabs / the system browser. Use for off-host
links you don't want to navigate inside the WebView.

### `registerHttpDownload(url, opts?)` → `{ id, filename }`

Hands a fully-qualified `http(s):` URL to Android's `DownloadManager`.
Resolves with the system download id and the filename DownloadManager
chose. `opts` is `{ userAgent?, contentDisposition?, mimeType? }` — all
optional; sensible defaults (`navigator.userAgent`, MIME guessed from
extension) are filled in automatically.

```js
await WebSightBridge.registerHttpDownload(
  'https://example.com/report.pdf',
  { contentDisposition: 'attachment; filename="quarterly.pdf"' },
);
```

You usually don't need to call this directly — see auto-detect below.

## Safe-area handling (transparent system bars)

When `flutter_ui.system_ui.mode` is `edge_to_edge` (the default), the
WebView paints under the transparent status / navigation bars. To stop
the wrapped site's content from sliding under those bars, WebSight
injects two CSS layers on every `pageFinished`:

1. **CSS variable shim** (always on when `inject_safe_area_css: true`).
   Adds `viewport-fit=cover` to the page's viewport meta and defines
   `--websight-safe-top` / `--websight-safe-bottom` /
   `--websight-safe-left` / `--websight-safe-right` on `:root`. Sites
   that want surgical control can read these directly:

   ```css
   .my-fixed-header {
     padding-top: var(--websight-safe-top);
   }
   ```

2. **Defensive `<body>` padding** (default on; controlled by
   `auto_pad_body` + `auto_pad_edges`). Sites that don't read
   `env(safe-area-inset-*)` natively get auto-padded so their normal-
   flow content (logos, sticky-in-flow headers, footers) doesn't
   overlap the transparent bars.

   ```yaml
   flutter_ui:
     system_ui:
       auto_pad_body: true
       auto_pad_edges: ["top", "bottom"]
   ```

   Disable when the wrapped site already respects insets (Tailwind
   apps, mobile-first frameworks, anything tested on iOS notched
   devices) — otherwise the body pad stacks on top of the site's own
   pad, leaving a visible blank strip.

Sites with `position: fixed` headers may still need a custom CSS
injection (the body pad only affects normal-flow content). Use the
existing `webview_settings.custom_user_scripts.inject_css` mechanism
with rules that target the fixed elements directly.

## In-page WebView permissions

Some pages call browser APIs that need an OS permission — `getUserMedia`
for camera / mic, `navigator.geolocation` for location. WebSight wires
the WebView's permission-request callbacks to `permission_handler` so
the user sees a single Android prompt instead of a separate WebView
dialog.

Configured under `permissions.webview` in `webview_config.yaml`:

```yaml
permissions:
  webview:
    allow_camera: true
    allow_microphone: true
    allow_geolocation: true
    allow_protected_media: false
    retain_geolocation: false   # remember per-origin grant
```

Set any flag to `false` to deny that resource at the WebSight layer
without ever prompting the OS. The page's `getUserMedia` Promise (or
`navigator.geolocation` callback) rejects in that case, the same way
the browser would reject if the user clicked "block".

The native scanner bridge (`scanBarcode()` above) still works
independently — it's a separate flow that takes the user to a
purpose-built ML Kit scanner.

## Multi-window popups (OAuth)

Pages that call `window.open(url)` (the standard pattern for "Sign in
with Google / Microsoft / Twitter / Facebook") get their popup routed
into a Flutter modal `WebView` route. WebSight's interceptor watches
for navigation back to a host in `security.restrict_to_hosts` and
auto-closes the popup when the OAuth provider redirects home.

Configure under `webview_settings.multi_window`:

```yaml
webview_settings:
  multi_window:
    enabled: true
    close_on_parent_host: true
    reload_parent_on_close: true
```

Pages don't need to do anything different — the existing
`window.open(authorizeUrl)` call routes through the bridge transparently.

The internal bridge method `openPopup` is reserved for this flow and
does not need to appear in `js_bridge.methods`.

## HTML5 fullscreen video

Tapping the fullscreen icon on a `<video>` element calls the page's
fullscreen handler, which goes through `WebChromeClient.onShowCustomView`.
WebSight hosts the platform widget in a black-backed fullscreen overlay,
locks orientation if configured, and restores everything on
`document.exitFullscreen()` or system back.

```yaml
webview_settings:
  fullscreen_video:
    enabled: true
    lock_landscape: false
```

## Auto-detect

When `downloads.enabled` and `downloads.use_android_download_manager` are
both true, the host calls `WebSightBridge._installDownloadInterceptor()`
once per page load. After install, any click satisfying ALL of:

- left mouse / primary tap (no Ctrl/Shift/Alt/Meta modifiers)
- on (or inside) an `<a>` whose href is `blob:`, `http:`, or `https:`
- with a `download` attribute OR an href ending in a downloadable
  extension (`.pdf`, `.zip`, `.csv`, `.mp4`, `.apk`, `.epub`, etc.)

…is intercepted: HTTP/S targets route to `registerHttpDownload`
(DownloadManager — system tray notification, lands in `/Downloads`),
blob targets route to `downloadBlob` (MediaStore.Downloads). Everything
else navigates as normal.

Opt out by setting `downloads.enabled: false` or
`downloads.use_android_download_manager: false`.

## Inbound events (page → host)

Configured in `js_bridge.inbound_events`. The host maps each event name
to an `action:` template; the page invokes them via the public
`dispatch(name, params)` method.

```yaml
js_bridge:
  inbound_events:
    - event: "openNative"
      args: ["route"]
      action: "navigate:{route}"
    - event: "toast"
      args: ["message"]
      action: "ui.toast:{message}"
```

`{key}` placeholders in `action:` are substituted from the params the
page passes:

```js
await WebSightBridge.dispatch('toast', { message: 'Saved!' });
await WebSightBridge.dispatch('openNative', { route: '/native/settings' });
```

### Built-in action grammars

| Action prefix    | Effect on the host                                                                 |
|------------------|-------------------------------------------------------------------------------------|
| `navigate:`      | `context.go(<route>)`. The substituted route is allow-listed against `flutter_ui.routes` — pages cannot push the host into surfaces the integrator never declared. |
| `ui.toast:`      | `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(<message>)))`. |

Action strings the host doesn't recognize are dropped with a debug log.
The action grammar is intentionally narrow; if you need a richer
inbound API, add a method (the `_dispatch` switch in `js_bridge.dart`),
add it to `js_bridge.methods`, and document it above.

## Push notifications (FCM)

When `notifications.fcm_enabled` is true, the host listens to
`onMessage` / `onMessageOpenedApp` and forwards the payload to JS via
the inbound `onPush` event (planned for v1.x — see ROADMAP).

## Implementation notes

- All `runJavaScript` calls from the native side encode arguments via
  `jsonEncode`, so callback IDs and arbitrary string payloads cannot
  break out of their interpolation context.
- Each call is gated by `js_bridge.methods` — methods missing from the
  allowlist are dropped silently with a debug log.
- If the WebView navigates between calling `_postMessage` and the
  callback resolution, the runtime origin check rejects the resolution
  with `E_ORIGIN` to prevent cross-host data leaks.
