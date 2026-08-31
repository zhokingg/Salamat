# Working agreement

- Do NOT ask clarifying questions or for confirmation. Make reasonable
  assumptions, act, and state the assumptions in your summary.
- Only stop to ask if truly blocked (missing credentials, destructive/irreversible
  action, or genuinely ambiguous intent with no safe default).
- Prefer running long/network tasks in the background and report results when done.
- Keep answers short and direct.

# Flutter version — pinned, and not by accident

**Use `fvm flutter` / `fvm dart`, never a bare `flutter`.** The version is
pinned to **3.41.9** in `.fvmrc`, which is committed.

```bash
fvm flutter analyze
fvm flutter test
fvm flutter test integration_test/<file>.dart -d <simulator-udid>
```

`fvm` itself lives at `~/.pub-cache/bin/fvm` (installed with
`dart pub global activate fvm`); put that directory on `PATH`. The cached SDK
at `~/fvm/versions/3.41.9` is a symlink to the existing checkout in
`~/flutter-sdks/3.41.9/flutter`, so nothing was re-downloaded.

## Why 3.41.9 specifically

The project sits in a narrow window with a hard edge on each side.

**Upper bound — anything ≥ 3.44 breaks the build.** `IconData` became a
`final` class, and both icon packages subclass it:

```
../../.pub-cache/hosted/pub.dev/lucide_icons-0.257.0/lib/src/icon_data.dart:3:30:
Error: The class 'IconData' can't be extended outside of its library because
it's a final class.
  class LucideIconData extends IconData {
```

`phosphor_flutter` fails the same way. Both are used across the whole UI, so
this is not a one-line fix — it is an icon-system migration.

**Lower bound — anything < 3.35 crashes on the iOS simulator.**
`camera_avfoundation` below `0.9.23+2` segfaults there, and the fixed version
requires Flutter ≥ 3.35. A plain `pub get` will not pick it up; the transitive
pin has to be forced.

**Homebrew's `flutter` is not this version.** It has twice shadowed the pinned
SDK mid-session and, running as 3.47.2, silently rewrote `analysis_options.yaml`
(adding an `analyzer.exclude` block) and touched `ios/`. If `flutter --version`
does not say 3.41.9, stop and fix `PATH` before running anything — a build
failure is the good outcome; a silent config rewrite is the bad one.
