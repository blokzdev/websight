<!--
Thanks for the PR. The checklist below mirrors what CI checks; running
it locally first speeds up review.
-->

## Summary

<!-- 1-3 sentences describing what changes and why. Link issues. -->

## Test plan

<!-- How to verify the change. Bullet list of commands/clicks. -->

- [ ]
- [ ]

## Checklist

- [ ] `dart format lib test tool` is clean
- [ ] `flutter analyze --no-fatal-infos` is clean
- [ ] `flutter test` passes
- [ ] `dart run tool/doctor.dart --plain` does not regress
- [ ] CHANGELOG `[Unreleased]` updated if user-visible
- [ ] No real Firebase keys, AdMob IDs, or signing keystores committed
- [ ] If touching a YAML key: `docs/internal/config-reference.yaml`
      and `assets/webview_config.yaml` are in sync
