# App Store screenshots — Salamat

Device: **iPhone 17 Pro Max** (6.9"), simulator `C5D3C6E3-DDC3-488D-80A3-8FD2BEE8B944`, iOS 26.5.
Every frame is exactly **1320 × 2868**, the size App Store Connect expects for 6.9".

## Naming — one scheme, no exceptions

```
<lang>_<NN>_<screen>.png        ru_01_home.png
```

* `lang` — `ru` or `en`.
* `NN` — position in the store listing, **fixed per screen**. The same screen
  carries the same number in both languages, always.
* `screen` — what is on it.

`NN` is a property of the screen, not of the capture. This folder once held two
captures using two different orders — `01` meant *home* in one and *diary* in
the other — and the only way to tell a stale frame from a current one was the
file's timestamp. Renumbering a screen means renaming both languages together;
adding one means taking the next free number, not reshuffling the rest.

| NN | Screen | ru | en |
|---|---|---|---|
| 01 | Home / dashboard, day in progress | ✅ | ✅ |
| 02 | Diary — today's meals | ✅ | ✅ |
| 03 | Meal card — plov | ✅ | ✅ |
| 04 | What to cook — pantry stocked, dishes suggested | ✅ | ✅ |
| 05 | Personal plan, with the BMI scale | ✅ | ✅ |
| 06 | Progress — week, with history | ✅ | ✅ |
| 07 | Settings | ✅ | ✅ |
| 08 | Paywall — offerings error | ✅ | ✅ |

All sixteen come from **one run, one account, one set of rows**. There is no
second set and no second account.

## What is in the frames

One account, one coherent stretch of time: Аида / Aida, 31, 168 cm, 77.1 kg →
70, norm 2100.

**Today**, on 01–05: eight dishes across four meals with eight different icons,
1605 eaten and **495 kcal left**, water 1.25 of 2.0 L, weight 77.1 kg.

**The five days before today**, seeded for 06: 8 dishes each, 1605–1795 kcal,
130–151 g of protein. Progress is the only screen that needs them, and it needs
them to be real — its trend, protein score, streak and consistency grid are all
derived from `meals` rows. The August capture had a one-day account, which is
why it showed one bar and "0 of 1 days on target".

The score is not arranged to look good. A day counts when it reaches 80 % of
the 30 %-of-calories protein target — 126 g at this norm. The five seeded days
clear it; **today, at 103.5 g, does not**. So the frame reads 83 %, 5 of 6, and
the run prints every day's totals next to the threshold:

```
D-1: 8 dishes, 1605 kcal, protein 145.5 g (threshold 126.0 g) on target
…
[ru] progress: 6 logged days, avg 1682 kcal, protein score 83% (5 of 6), streak 6
```

**Eight weigh-ins** run 78.4 → 77.1, so the weight card draws a line and reads
“−1,3 кг с начала”. **Water** is 1.25 of 2.0 L, five sips of 250 ml.

The plan headline now says the same thing in both languages — “Твой
персональный план” / “Your personal plan”. It used to read “Personal plan based
on your answers” in English, which is a different sentence.

### One account, and what guarantees it

The account is created once, at the top of the run. Weigh-ins, water and the
five days of history carry no language, so they are written once. Between
languages only two things change — the interface language and the dish names
that go with it — and today's eight rows are **deleted and rewritten**, never
appended to. That is the fix for the doubled diary: appending is what produced
sixteen meals and a red overrun last time.

### What the run refuses to do

It fails instead of writing a wrong frame when:

* **the language did not take effect** — the locale is set through
  `localeProvider` and asserted afterwards, and each language additionally
  asserts a localised string on screen (the plan headline, the settings title).
  The August frames were caught mid-switch, with English headings on a Russian
  screen;
* **today holds anything but the eight seeded dishes** — checked against
  `meals` in the database, not against the provider cache, both times;
* **"what to cook" came back empty** — one "add to diary" button per built
  suggestion card; zero means a blank slab under the button;
* **a frame is not 1320 × 2868** — the shot server checks the PNG's IHDR and
  answers 500; `shot()` now fails the test on that instead of swallowing it.

What one run prints:

```
account: 5c88037a-bf93-482b-86d3-c4971f4e799b
  D-1: 8 dishes, 1605 kcal, protein 145.5 g (threshold 126.0 g) on target
  …
water: 1250 ml of 2000
[ru] locale = ru
[ru] today in db: 8 rows
[ru] diary: 8 dishes, 1605 kcal, 495 left
[ru] progress: 6 logged days, avg 1682 kcal, protein score 83% (5 of 6), streak 6
[en] locale = en
[en] today in db: 8 rows
[en] diary: 8 dishes, 1605 kcal, 495 left
done — one account, 5c88037a-bf93-482b-86d3-c4971f4e799b
```

### 08 — the paywall

Offerings do not resolve here (the products are not approved yet), so this is
the error state, captured as it is. The test fails if the copy regresses: no
store name, no weight-by-a-date promise, no "10 scans a day". The current
wording is *"Не удалось загрузить цены подписки. Проверь связь и повтори."* and
*"Цель — 70 кг. План рассчитан примерно на 0,5 кг в неделю."*

Known cosmetic: the screen opens scrolled down to the error card, so the
"РАСПОЗНАНО" eyebrow at the top of the hero is clipped. That scroll is
deliberate app behaviour, not a capture bug — remove it from the shot by
scrolling to top first, at the cost of pushing the error card below the fold.

## Run

```bash
./scripts/capture_store.sh
```

Boots the simulator, starts the host screenshot server, walks the app and writes
verified frames into `store2/`. Overwrites in place. Which walk it runs is
`SALAMAT_TEST` — `integration_test/store_frames_test.dart` seeds the day above
and shoots all eight.

Overridable via env: `SALAMAT_UDID`, `SALAMAT_SHOT_PORT`, `SALAMAT_SHOT_DIR`,
`FLUTTER_BIN`, `SALAMAT_TEST`.

**Build requirement: Flutter 3.41.9.** A narrow window, not a preference:

| Flutter | Result |
|---|---|
| ≥ 3.44 | won't compile — `IconData` became `final`, breaking `phosphor_flutter` + `lucide_icons` |
| < 3.35 | compiles, then crashes on launch — `camera_avfoundation` < 0.9.23+2 segfaults in `CameraPlugin.register` on the iOS 26 runtime |
| **3.41.9** | **both work** |

## How the screenshots are taken

**Not** through Flutter. `convertFlutterSurfaceToImage` is Android-only, and the
iOS `takeScreenshot` path does not give the device-native 1320 × 2868.

`tools/shot_server.py` runs on the host instead. The simulator shares the host
network stack, so the test calls `http://127.0.0.1:8787/shot?name=…` and blocks;
the server runs `xcrun simctl io <udid> screenshot`, reads the PNG IHDR to check
the size, and only then answers. A wrong-sized frame fails the run rather than
being written quietly.

Each language gets its own anonymous account — `SupabaseService` initialises once
per process, so without signing out between languages the second run seeds a
second day onto the first one's account (sixteen meals, a red overrun, 2.5 L of
water). The test also counts the seeded meals afterwards and retries the missing
ones; a frame with a dish silently absent is worse than a failed run.

## Not captured

* **Camera** — the simulator has no camera feed, so there is no honest frame to
  take. Not faked.
* **Paywall prices** — RevenueCat offerings do not resolve in this environment,
  so the paywall can only be shot in its error state. See 08 above.
