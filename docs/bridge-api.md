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

## Inbound events (native → JS)

Configure these in `js_bridge.inbound_events` and the host posts them
back to `window` as `MessageEvent`-style invocations on the bridge.

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

The `{key}` placeholders are substituted from the params the page passes
when invoking the event:

```js
WebSightBridge._postMessage('toast', { message: 'Saved!' });
```

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
