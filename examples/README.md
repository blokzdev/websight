# Example configs

Drop-in `webview_config.yaml` starters for common shapes of WebSight
fork. Copy the one you want over `assets/webview_config.yaml` and then
run the standard fork workflow (see [`docs/WHITELABEL.md`](../docs/WHITELABEL.md)).

| File                     | Shape                                                                                         |
|--------------------------|-----------------------------------------------------------------------------------------------|
| `blockchair.yaml`        | Third-party crypto explorer (blockchair.com), unofficial wrapper, ads off, disclaimer on. A reference for any "I don't own this site" deployment. |

## Using an example

```bash
cp examples/blockchair.yaml assets/webview_config.yaml

# Edit app.application_id (and optionally app.admob_app_id) to your own values:
$EDITOR assets/webview_config.yaml

# Propagate identity into Gradle / manifest / strings / pubspec:
dart run tool/configure.dart

# Continue with flutterfire configure / icons / signing / build per
# docs/WHITELABEL.md.
```

## Adding your own example

PRs welcome. Keep examples:

- **Self-contained** — readable and runnable without any other docs.
- **Honest about constraints** — comment any third-party or trademark
  caveats at the top of the file.
- **Conservative on permissions** — file uploads / ads / billing /
  FCM should default off unless the example specifically demonstrates
  them.
- **Disclaimer-on by default** when wrapping a site you don't own.
