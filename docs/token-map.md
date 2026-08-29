# Карта токенов: старая тема → новая

Старые файлы **не удалены** и продолжают работать: `lib/theme/salamat_theme.dart`
(`SalamatTokens`, `SalamatType`), `lib/theme/colors.dart` (`SalamatColors`),
`lib/theme/text_styles.dart` (`SalamatText`), `lib/theme/dimensions.dart`
(`SalamatDims`), `lib/theme/elevation.dart` (`SalamatElevation`).

Новое: `lib/theme/salamat_dark.dart` — `SalamatColorsDark` (ThemeExtension),
`SalamatDarkType`, `SalamatDarkDims`, `SalamatDarkTheme`.
Переключатель: `lib/theme/theme_flag.dart` → `kAppSkin`.

## Как работает флаг

```dart
// lib/theme/theme_flag.dart
const AppSkin kAppSkin = AppSkin.protoDark;   // protoLight | legacy
```

| Значение | ThemeData | Палитра, которую видят экраны (`context.c`) |
|---|---|---|
| `protoDark` | `SalamatDarkTheme.theme` | `SalamatColorsDark.dark` (тёмная из прототипа) |
| `protoLight` | `SalamatDarkTheme.theme` | `SalamatColorsDark.light` (светлая из прототипа) |
| `legacy` | `SalamatTheme.light` (старая, без изменений) | `SalamatColorsDark.legacy` — старые цвета в новых ролях |

Экраны обращаются к цвету только через `context.c.<роль>`, поэтому смена флага
перекрашивает всё приложение без правок в экранах.

**Ограничение, честно:** флаг откатывает цвет, типографику и тени. Разметку он не
откатывает — она переписана по прототипу, а разметка не является токеном. Для полного
визуального откатa нужен git-revert экранов вместе с флагом.

## Цвета

| Старый токен | HEX (старый) | → Новая роль | HEX (protoDark) | Комментарий |
|---|---|---|---|---|
| `SalamatTokens.background` | `#DDEBC9` | `c.bg` | `#000000` | шалфейный холст → AMOLED-чёрный |
| `SalamatTokens.surface` | `#FBF6E8` | `c.surface` | `#0C0F14` | кремовая карточка → почти чёрная |
| `SalamatTokens.surfaceAlt` | `#FFFFFF` | `c.surface2` | `#141922` | «уровень 2» становится вложенной плашкой |
| `SalamatTokens.ringTrack` | `#E4DFC8` | `c.surface3` | `#1C2230` | дорожка колец/прогресса |
| `SalamatTokens.pillBg` | `#E9F2DC` | `c.primarySoft` | `rgba(58,224,126,0.14)` | подложка чипов |
| `SalamatTokens.pillText` | `#52802B` | `c.primaryInk` | `#86EFAC` | акцентный текст на фоне |
| `SalamatTokens.accent` | `#6FA53C` | `c.primary` | `#3AE07E` | главный акцент |
| `SalamatTokens.accentDeep` | `#52802B` | `c.primaryInk` | `#86EFAC` | активные состояния слились с `primaryInk` |
| `SalamatTokens.amber` | `#F0B45C` | `c.warn` | `#FBBF24` | стрики/превышение нормы |
| `SalamatTokens.textPrimary` | `#35402A` | `c.text` | `#F5F7FA` | |
| `SalamatTokens.textMuted` | `#677257` | `c.text2` | `#98A2B3` | |
| `SalamatTokens.iconQuiet` | `#75816A` | `c.text3` | `#6B7686` | приглушённые иконки и подписи объединены |
| `SalamatTokens.onAccent` | `#FFFFFF` | `c.onPrimary` | `#04140A` | **смена смысла**: белый на зелёном → почти чёрный на неоне |
| `SalamatTokens.danger` | `#C0392B` | `c.err` | `#F87171` | |
| `SalamatTokens.bubbleAmber` | `#F5E5C4` | `c.warn` + alpha | — | отдельного токена в прототипе нет |
| `SalamatTokens.bubbleMint` | `#E4EDE0` | `c.accentSoft` | `rgba(45,212,191,0.14)` | |
| `SalamatColors.bg` | `#F4F8F1` | `c.bg` | `#000000` | легаси-палитра |
| `SalamatColors.surf` | `#FFFFFF` | `c.surface` | `#0C0F14` | |
| `SalamatColors.ink` | `#131A10` | `c.text` | `#F5F7FA` | |
| `SalamatColors.i2` | `#627860` | `c.text2` | `#98A2B3` | |
| `SalamatColors.i3` | `#A2B59E` | `c.text3` / `c.line2` | `#6B7686` | |
| `SalamatColors.g1` | `#26593C` | `c.primaryInk` / `c.secondary` | `#86EFAC` / `#8B8DF7` | тёмно-зелёный распался на две роли |
| `SalamatColors.g2` | `#49AA72` | `c.primary` | `#3AE07E` | |
| `SalamatColors.g3` | `#D2EAD8` | `c.surface3` | `#1C2230` | |
| `SalamatColors.g4` | `#EAF4EB` | `c.surface2` / `c.primarySoft` | `#141922` | |
| `SalamatColors.line` | `#DDE8D8` | `c.line` | `rgba(255,255,255,0.10)` | |
| `SalamatColors.warn` | `#BF7030` | `c.warn` | `#FBBF24` | |
| `SalamatColors.danger` | `#C0392B` | `c.err` | `#F87171` | |
| `SalamatColors.cam` | `#111810` | `SalamatColorsDark.camBg` | `#07090C` | фон камеры, вне свапа тем |
| `SalamatElevation.hairline` | `#E7EFE3` | `c.line` | `rgba(255,255,255,0.10)` | |
| `SalamatElevation.card` | 3 слоя, α<0.08 | `c.shadow1` | 2 слоя, α 0.5–0.6 | в тёмной теме тень работает наоборот — глубже и плотнее |

### Новые роли, которых в старой теме не было

| Новая роль | protoDark | Зачем |
|---|---|---|
| `c.secondary` / `c.secondarySoft` | `#8B8DF7` / `rgba(139,141,247,0.16)` | углеводы, «Salamat noticed», аватар |
| `c.accent` / `c.accentSoft` | `#2DD4BF` / `rgba(45,212,191,0.14)` | жиры, второй стоп градиентов |
| `c.sheet` | `#10141B` | фон модальной шторки отдельно от `surface` |
| `c.scrim` | `rgba(0,0,0,0.62)` | затемнение под шторкой |
| `c.skeletonBase` / `c.skeletonHighlight` | `#141922` / `#1E242F` | шиммер |
| `c.shadow2` | 2 слоя, α 0.7 | FAB, шторки, «ручка» ползунка |
| `SalamatColorsDark.camGlass*` | `rgba(255,255,255,0.12/0.14)` | стеклянные кнопки на камере |
| `SalamatColorsDark.proCardFrom/To` | `#111827` → `#1F2937` | карточка Pro |
| `SalamatColorsDark.crownTileFrom/To` | `#F59E0B` → `#EF4444` | плитка короны на пейволле |

### Роли, которые исчезли

`SalamatTokens.bubbleAmber` / `bubbleMint` — в прототипе нет «стикер-пузырей» как
отдельной сущности: иконка сидит на `primarySoft` / `secondarySoft` / `accentSoft`.

## Типографика

| Старый стиль | Было | → Новый стиль | Стало |
|---|---|---|---|
| `SalamatType.numXl` | 48 / w600 / −1.0 | `SalamatDarkType.numL` | 34 / w600 / −0.04em |
| — | — | `SalamatDarkType.numXxl` | 82 / w600 / −0.05em (ввод веса) |
| `SalamatType.numLg` | 26 / w600 / −0.4 | `SalamatDarkType.numM` | 26 / w600 / −0.03em |
| `SalamatType.h1` | 32 / w700 / −0.6 | `SalamatDarkType.h1` | 30 / w600 / −0.035em |
| `SalamatType.h2` | 24 / w700 / −0.4 | `SalamatDarkType.h2` | 24 / w600 / −0.03em |
| `SalamatType.title` | 18 / w700 / −0.2 | `SalamatDarkType.h3` | 21 / w600 / −0.02em |
| `SalamatType.body` | 16 / w500 / 1.45 | `SalamatDarkType.bodyL` | 16 / w500 |
| `SalamatType.caption` | 13 / w500 / 1.35 | `SalamatDarkType.caption` | 13 / w500 |
| `SalamatType.eyebrow` | 11 / w700 / +1.4 | `SalamatDarkType.eyebrow` | 11 / w600 / +0.12em (= +1.32) |
| `SalamatType.btn` | 16 / w700 / +0.1 | `SalamatDarkType.btn` | 16 / w600 |
| `SalamatText.h1` (легаси) | 44 / w800 | `SalamatDarkType.display` | 38 / w600 / 1.06 |
| `SalamatText.h3` (легаси) | 22 / w700 | `SalamatDarkType.h3` | 21 / w600 |

Ключевое отличие: прототип знает **только** веса 500 и 600. Всё, что было w700/w800,
опускается до w600. Трекинг в прототипе задан в `em` и пересчитывается в абсолютный
`letterSpacing` как `em × fontSize`.

Шрифт: Manrope через `google_fonts` → **системный** (`fontFamily: null`).

## Геометрия

| Старый токен | Было | → Новый | Стало |
|---|---|---|---|
| `SalamatTokens.radiusHero` | 24 | `SalamatDarkDims.rHero` | 24 |
| `SalamatTokens.radiusCard` | 18 | `SalamatDarkDims.rCard` | 22 |
| `SalamatTokens.radiusCta` | 20 | `SalamatDarkDims.rButton` | 18 |
| `SalamatTokens.radiusPill` | 12 | `SalamatDarkDims.rPill` | 99 (настоящая пилюля) |
| `SalamatDims.screenPadding` | 24 | `SalamatDarkDims.screenPadH` | 20 (основные экраны) |
| — | — | `SalamatDarkDims.onboardingPad` | 60 / 24 / 34 |
| `SalamatDims.buttonHeight` | 54 | `SalamatDarkDims.ctaPad` | 17 паддинг (высота из контента) |
| `SalamatDims.buttonRadius` | 14 | `SalamatDarkDims.rButton` | 18 |
| `SalamatDims.fabSize` | 54 | `SalamatDarkDims.fabSize` | 58, с выносом −18 |
| `SalamatDims.tabBarHeight` | 88 | `SalamatDarkDims.navHeight` | 94 |
| `SalamatDims.gap*` | 4…32 | `SalamatDarkDims.gap*` | 2, 4, 5, 6, 8, 10, 12, 14, 16, 20, 22, 24, 26 |
| `SalamatElevation.cardRadius` | 22 | `SalamatDarkDims.rCard` | 22 |
| `SalamatElevation.tileRadius` | 16 | `SalamatDarkDims.rField` | 16 |
