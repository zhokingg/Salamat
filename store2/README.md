# App Store screenshots — Salamat

Device: **iPhone 17 Pro Max** (6.9"), simulator `C5D3C6E3-DDC3-488D-80A3-8FD2BEE8B944`, iOS 26.5.
Every frame is exactly **1320 × 2868**, the size App Store Connect expects for 6.9".

## Run

```bash
./scripts/capture_store.sh
```

One command does everything: boots the simulator, starts the host screenshot
server, walks the whole app, and writes verified frames into `store2/`.
Re-run it after any design change — it overwrites in place.

Overridable via env: `SALAMAT_UDID`, `SALAMAT_SHOT_PORT`, `SALAMAT_SHOT_DIR`, `FLUTTER_BIN`.

**Build requirement: Flutter 3.41.9.** This is a narrow window, not a preference:

| Flutter | Result |
|---|---|
| ≥ 3.44 | won't compile — `IconData` became `final`, breaking `phosphor_flutter` + `lucide_icons` (both already at their latest release) |
| < 3.35 | compiles, but crashes on launch — `camera_avfoundation` < 0.9.22 segfaults in `CameraPlugin.register` on the iOS 26 runtime |
| **3.41.9** | **both work** |

`camera` was bumped `^0.11.0 → ^0.11.4` and `camera_avfoundation` force-upgraded
to `0.9.23+2` (a plain `pub get` leaves the crashing pin in place — it needs
`flutter pub upgrade camera_avfoundation`).

## Frames

| File | Screen | Language |
|---|---|---|
| `en_01_home.png` | Home / dashboard, with data | English |
| `en_02_diary.png` | Diary — today's meals | English |
| `en_03_progress.png` | Progress | English |
| `en_04_plan.png` | "Plan ready" from onboarding | English |
| `en_05_cook.png` | What to cook — pantry stocked | English |
| `en_06_paywall.png` | Paywall (error state, see below) | English |
| `en_07_settings.png` | Settings | English |
| `en_08_meal.png` | Meal card — Beef plov | English |
| `ru_01_home.png` | Home / dashboard, with data | Russian |
| `ru_02_diary.png` | Diary — today's meals | Russian |
| `ru_03_progress.png` | Progress | Russian |
| `ru_04_plan.png` | "Plan ready" from onboarding | Russian |
| `ru_05_cook.png` | What to cook — pantry stocked | Russian |
| `ru_06_paywall.png` | Paywall (error state, see below) | Russian |
| `ru_07_settings.png` | Settings | Russian |
| `ru_08_meal.png` | Meal card — Beef plov | Russian |

The run completes onboarding for real (name → goal → gender → year → weight →
target → celebration → long-term → familiarity → activity → summary → 3× yes →
comparison → social proof → building → plan), then logs two meals by hand
(Beef plov 640 kcal / lunch, Greek salad 320 kcal / dinner) so the diary, home
and progress screens have content. Russian is reached by tapping the language
switch in Settings, exactly as a user would.

## How screenshots are taken

**Not** through Flutter. `convertFlutterSurfaceToImage` is Android-only, and the
iOS `takeScreenshot` path does not give the device-native 1320 × 2868.

Instead `tools/shot_server.py` runs on the host. The iOS simulator shares the
host network stack, so the test calls `http://127.0.0.1:8787/shot?name=…` and
blocks; the server runs `xcrun simctl io <udid> screenshot`, reads the PNG IHDR
to check the size, and only then answers. A wrong-sized frame fails the run
instead of being silently written.

## Not captured

* **Camera** — the simulator has no real camera feed, so there is no honest
  frame to take. Not faked.
* **Paywall prices** — RevenueCat is not configured, so offerings come back
  empty and the paywall renders its error state. Captured as-is, per instructions.
* **Cook suggestions** — the suggestion backend does not respond in this
  environment ("Couldn't pick a dish / The service didn't respond"). The frame
  shows the screen with the pantry stocked (Chicken, Rice, Tomato) and the
  "Suggest 3 dishes" CTA — real UI, real input, no error card. Set
  `kRequestSuggestions = true` in the test to capture actual dish cards once the
  service is reachable.
* **Progress history** — a fresh account has one day of data, so the calorie
  trend shows a single bar. Only a longer-lived account would fill it.

## Keys added

**None.** No app source was modified for testability. Everything is located by
widget type (`OnboardingPrimaryButton`, `OnboardingSelectCard`, `TextField`,
`ElevatedButton`, `ManualEntrySheet`, `CookScreen`) or by text that is identical
in both locales (`Русский` / `English`). Screen changes are made through
`appRouter` by route name — stable, language-independent, and not coordinates.

## Bugs this run surfaced

1. **Paywall says "Google Play" on iOS** — the offerings error reads
   *"Couldn't load prices from Google Play."* Visible in `en_06_paywall.png`.
2. **Untranslated strings in Russian** — the Water card keeps `of 2.0 L` and
   `Saved on this device only` in English. Visible in `ru_01_home.png`.
3. **Missing Supabase table** — `PostgrestException: Could not find the table
   'public.water_logs' in the schema cache` (it suggests `weight_logs`). Thrown
   on every run.
4. **Layout overflow during onboarding** — `A RenderFlex overflowed by 34 pixels
   on the bottom` on a step being disposed mid-transition. Transient; does not
   appear in any captured frame.

Because of (3) and (4), `flutter test` exits non-zero even when all 16 frames are
captured correctly — `integration_test` counts any unhandled Flutter error as a
test failure. **Trust the `shot` lines and the frame count, not the exit code,**
until those two are fixed. The screenshot server fails loudly and separately if a
frame is missing or the wrong size.

## Also changed

* `ios/Flutter/AppFrameworkInfo.plist` — `MinimumOSVersion 13.0` restored (note:
  the file is under `ios/Flutter/`, not `ios/Runner/`). **Flutter's build
  migration strips this key on every build**, so it must be restored after the
  final release build; restoring it once is not durable.
* `.gitignore` — added `.claude/`, `.idea/`, `supabase/.temp/`, `flutter_01.log`, `*.iml`.

Nothing is committed.
