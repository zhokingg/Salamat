# Salamat — скриншоты экранов

Снято на Android-эмуляторе `Medium_Phone_API_36` (Google Play x86_64, API 36, 1080×2400),
debug-сборка APK из текущего рабочего дерева (ветка `redesign-dark`, версия `1.0.0+12`).
Код приложения не менялся.

**Стек:** Flutter 3.29.3 / Dart 3.7.2 · `applicationId` = `kg.salamat.app` · `minSdk` 21,
`compileSdk` 35, `targetSdk` 35 (значения по умолчанию Flutter Gradle Plugin) · iOS deployment target 13.0.

## Как снималось

* Скриншот: `adb exec-out screencap -p > screens/NN_имя.png`
* Навигация: `adb shell uiautomator dump` → поиск узла по тексту → центр `bounds` → `adb shell input tap X Y`

## Язык

Образ эмулятора не рутован, поэтому системную локаль сменить не удалось — устройство осталось
`en-US`. Английский прогон (`00`–`44`) снят на системной локали, русский (`46`–`64`) — после
переключения языка в приложении (Профиль → Язык → Русский); для русского онбординга
значение `flutter.app_locale=ru` было записано в `shared_prefs` через `adb run-as` **до**
первого запуска. Это данные на устройстве, а не правка кода.

---

## Онбординг и основной сценарий (EN)

| Файл | Экран | Заметки |
|---|---|---|
| `00_splash_native.png` | Нативный splash Android | Иконка запуска, до первого кадра Flutter. В debug-сборке держится ~12 с (JIT), в release заметно короче |
| `01_splash.png` | Splash приложения (`/splash`) | `splash_screen.dart`. Минимум 2 с, страховочный таймаут 8 с |
| `02_onboarding_01_welcome.png` | Приветствие (`/onboarding/welcome`) | Шаг 1/17 |
| `03_onboarding_02_name.png` | Имя (`/onboarding/name`) | Шаг 2/17, введено «Aizhan» |
| `04_onboarding_03_goal.png` | Главная цель (`/onboarding/goal`) | Шаг 3/17, выбрано «Lose weight» |
| `05_onboarding_04_gender.png` | Пол (`/onboarding/gender`) | Шаг 4/17, выбрано «Female» |
| `06_onboarding_05_year.png` | Год рождения (`/onboarding/year`) | Шаг 5/17, колесо, по умолчанию 2001 |
| `07_onboarding_06_weight.png` | Рост и вес (`/onboarding/weight`) | Шаг 6/17, два колеса + плашка ИМТ |
| `08_onboarding_07_target.png` | Целевой вес (`/onboarding/target`) | Шаг 7/17 |
| `09_onboarding_08_celebration.png` | Поздравление (`/onboarding/celebration`) | Конфетти в кадре — это анимация `confetti` |
| `10_onboarding_09_long_term.png` | Долгосрочный результат (`/onboarding/long-term`) | Шаг 9/17, график Salamat vs обычные диеты |
| `11_onboarding_10_familiarity.png` | Осведомлённость (`/onboarding/familiarity`) | Шаг 10/17, выбрано «Beginner» |
| `12_onboarding_11_activity.png` | Активность (`/onboarding/activity`) | Шаг 11/17, выбрано «Lightly active» |
| `13_onboarding_12_summary.png` | Сводка плана (`/onboarding/summary`) | Шаг 12/17 |
| `14_onboarding_13_yes_lose.png` | Вопрос «да» — похудеть (`/onboarding/yes/lose`) | Шаг 13/17 |
| `15_onboarding_14_yes_order.png` | Вопрос «да» — питание (`/onboarding/yes/order`) | Тот же виджет, другой `YesQuestion` |
| `16_onboarding_15_yes_health.png` | Вопрос «да» — здоровье (`/onboarding/yes/health`) | |
| `17_onboarding_16_comparison.png` | Что даёт Salamat (`/onboarding/comparison`) | Шаг 14/17 |
| `18_onboarding_17_social_proof.png` | Соцдоказательство (`/onboarding/social-proof`) | Шаг 15/17 |
| `19_onboarding_18_building.png` | Построение плана (`/onboarding/building`) | Лоадер 4,2 с, поймано на 40 % |
| `20_onboarding_19_plan_ready.png` | План готов (`/onboarding/plan`) | Норма 1487 ккал, Б112/Ж50/У149 |
| `21_dashboard_empty.png` | Главная — пустое состояние (`/dashboard`) | 0 приёмов, «Snap your first meal», «Log your first weigh-in» |
| `22_meals_empty.png` | Приёмы пищи — пустое состояние (`/meals`) | |
| `23_manual_entry_sheet.png` | Ручной ввод, свёрнутый (`manual_entry_sheet.dart`) | Модальная шторка |
| `24_manual_entry_details.png` | Ручной ввод, развёрнутый | Заполнено: Beshbarmak, 620 ккал, 38/24/55, 350 г |
| `25_meals_filled.png` | Приёмы пищи с записью | Завтрак 620 ккал + тост «Added to breakfast ✓» |
| `26_dashboard_filled.png` | Главная с данными | Осталось 867 ккал |
| `27_progress.png` | Прогресс (`/progress`) | Стрик, круги БЖУ, история |
| `28_profile.png` | Профиль (`/profile`) | Верх экрана |
| `29_profile_scrolled.png` | Профиль, прокрутка вниз | Sign out / Delete account |
| `30_update_weight_dialog.png` | Диалог «Обновить вес» | `update_weight_dialog.dart` |
| `31_goal_edit.png` | Изменение цели, шаг 1 (`/goal-edit`) | |
| `32_goal_edit_step2.png` | Изменение цели, шаг 2 | Целевой вес + «Save» |
| `33_paywall_offerings_error.png` | **Пейволл (`/paywall`) — состояние ошибки** | Экран рисуется, но цены не грузятся: RevenueCat не настроен. См. `paywall_source.md` |
| `34_camera_permission.png` | Системный запрос доступа к камере | Перед `/camera` |
| `35_camera.png` | Камера (`/camera`) | Видоискатель, счётчик «0 of 1». В кадре синтетическая сцена эмулятора |
| `36_camera_analyzing.png` | Камера — распознавание | «Recognising dish...» |
| `37_camera_recognition_error.png` | **Камера — ошибка распознавания** | «Could not recognise the dish»: сцена эмулятора — не еда |
| `38_dashboard_scrolled.png` | Главная, прокрутка вниз | Карточка веса и «Snack idea» |

## Русская локаль

| Файл | Экран | Заметки |
|---|---|---|
| `39_profile_ru.png` | Профиль | Сразу после переключения языка |
| `40_dashboard_ru.png` | Главная | С данными |
| `41_meals_ru.png` | Приёмы пищи | С данными |
| `42_progress_ru.png` | Прогресс | |
| `43_paywall_ru.png` | Пейволл | То же состояние ошибки цен |
| `44_delete_account_dialog.png` | Диалог удаления аккаунта | Необратимое действие, нажата «Отмена» |
| `46_ru_onb_01_welcome.png` … `64_ru_onb_19_plan_ready.png` | Весь онбординг, 19 экранов | Порядок совпадает с английским прогоном `02`–`20` |

Экрана `45` нет: «Выйти» в профиле не показывает подтверждения, а сразу разлогинивает
и уводит на `/onboarding/welcome` — снимать было нечего.

---

## Палитра

### `SalamatTokens` — `lib/theme/salamat_theme.dart` (актуальная тема, `SalamatTheme.light`)

| Токен | HEX | Роль |
|---|---|---|
| `background` | `#DDEBC9` | Шалфейный холст экрана |
| `surface` | `#FBF6E8` | Кремовая карточка (уровень 1) |
| `surfaceAlt` | `#FFFFFF` | Белая карточка на кремовой (уровень 2) |
| `accent` | `#6FA53C` | Действия и прогресс |
| `accentDeep` | `#52802B` | Активные состояния, акцент |
| `amber` | `#F0B45C` | Стрики, вес, бейджи достижений |
| `pillBg` | `#E9F2DC` | Фон пилюль/бейджей |
| `pillText` | `#52802B` | Текст пилюль |
| `textPrimary` | `#35402A` | Основной текст |
| `textMuted` | `#677257` | Второстепенный текст |
| `iconQuiet` | `#75816A` | Приглушённые иконки |
| `onAccent` | `#FFFFFF` | Текст/иконки на заливке accent |
| `ringTrack` | `#E4DFC8` | Дорожка колец прогресса |
| `bubbleAmber` | `#F5E5C4` | Пузырь стикер-иконки (огонь) |
| `bubbleMint` | `#E4EDE0` | Пузырь стикер-иконки (капля) |
| `danger` | `#C0392B` | Ошибки, деструктивные действия |

### `SalamatColors` — `lib/theme/colors.dart` (легаси-палитра, ещё используется пейволлом и камерой)

| Токен | HEX | | Токен | HEX |
|---|---|---|---|---|
| `bg` | `#F4F8F1` | | `g1` | `#26593C` |
| `surf` | `#FFFFFF` | | `g2` | `#49AA72` |
| `ink` | `#131A10` | | `g3` | `#D2EAD8` |
| `i2` | `#627860` | | `g4` | `#EAF4EB` |
| `i3` | `#A2B59E` | | `line` | `#DDE8D8` |
| `warn` | `#BF7030` | | `danger` | `#C0392B` |
| `cam` | `#111810` | | | |

`#26593C` — это же цвет иконки запуска и `adaptive_icon_background` в `pubspec.yaml`.

### Тень и линии — `lib/theme/elevation.dart`

`hairline` `#E7EFE3`; тень карточки — три слоя `#08111810` / `#0A111810` / `#06111810`
(суммарная альфа < 0.08).

## Шрифты

Единственная гарнитура — **Manrope**, подключается через `google_fonts` (`^6.2.1`), то есть
тянется с Google Fonts в рантайме, не лежит в `assets`. Fallback-цепочка для глифов, которых
в Manrope нет (₸ / U+20B8, часть кириллических сокращений, эмодзи): `Roboto` → `Noto Sans` →
`sans-serif`.

Шкала `SalamatType` (актуальная):

| Стиль | Размер | Начертание | Интерлиньяж | Трекинг |
|---|---|---|---|---|
| `numXl` (главная цифра калорий) | 48 | w600 | 1.0 | −1.0 |
| `numLg` (БЖУ, вес) | 26 | w600 | 1.0 | −0.4 |
| `h1` | 32 | w700 | 1.1 | −0.6 |
| `h2` | 24 | w700 | 1.15 | −0.4 |
| `title` | 18 | w700 | 1.2 | −0.2 |
| `body` | 16 | w500 | 1.45 | 0 |
| `caption` | 13 | w500 | 1.35 | 0 |
| `eyebrow` (КАПС) | 11 | w700 | 1.0 | +1.4 |
| `btn` | 16 | w700 | 1.2 | +0.1 |

Легаси-шкала `SalamatText` (`lib/theme/text_styles.dart`) добавляет `h1` 44 / w800 и
`h3` 22 / w700 — ими ещё пользуются пейволл и камера.

## Геометрия

`SalamatTokens`: карточка 18, hero 24, CTA 20, пилюля 12.
`SalamatDims`: отступ экрана 24, высота кнопки 54, радиус кнопки 14, радиус карточки 18,
FAB 54, таб-бар 88; шаги отступов 4/8/12/16/20/24/32.
`SalamatElevation`: карточка 22, тайл 16, пилюля 12.

---

## Что снять не удалось

| Экран | Причина |
|---|---|
| **Блок цен на пейволле** | RevenueCat не настроен: `Purchases.getOfferings()` не возвращает `current`, `_loadOfferings()` уходит в `_loadError`. Сам экран снят в состоянии ошибки (`33`, `43`), исходник виджета и все строки/цены — в [`paywall_source.md`](paywall_source.md) |
| **Шторка результата распознавания** (`_ResultSheet`) | Открывается только после уверенного распознавания. Синтетическая сцена камеры эмулятора — не еда, поэтому всегда «Could not recognise the dish». Исходник — в [`unreachable_screens.md`](unreachable_screens.md) |
| **Заглушка «фото на сегодня кончились»** (`_OutOfPhotosStub`) и **шторка лимита фото** (`photo_limit_sheet.dart`) | Лимит живёт в таблице Supabase `photo_usage` и увеличивается только после успешного скана. Исчерпать его означало бы писать в продовый Supabase — не делал. Исходник — в [`unreachable_screens.md`](unreachable_screens.md) |
| **Заглушка «камера недоступна»** (`_UnavailableStub`) | Нужны выданное разрешение **и** пустой `availableCameras()`. Запуск эмулятора с `-camera-back none -camera-front none` не помогает: `_ensureCameraPermission()` закрывает роут раньше, чем что-либо отрисуется |
| **Русский онбординг на системной локали `ru`** | Образ эмулятора не рутован, `setprop persist.sys.locale` запрещён. Снято через запись `flutter.app_locale=ru` в `shared_prefs` — результат тот же, но системные диалоги (запрос камеры) остаются английскими |

Отдельное наблюдение, не связанное с задачей: на втором (русском) тестовом аккаунте кнопки
входа в камеру (`Сканировать блюдо` и центральный FAB) перестали реагировать — роут `/camera`
не открывается и шторка лимита не показывается. На первом аккаунте всё работало, поэтому
экраны камеры `34`–`37` сняты там. Возможно, стоит проверить `_onCamera` /
`subscriptionProvider.canTakePhoto` — но в рамках этой задачи я ничего не чинил.

## Изменения окружения, откаченные в конце

* Клавиатуры (`ime disable`) — отключались, чтобы IME не попадал в кадр; включены обратно.
* Эмулятор перезапускался с `-camera-back none -camera-front none` — вернул конфигурацию по умолчанию.
* Разрешение `android.permission.CAMERA` выдавалось через `pm grant` — обычное runtime-разрешение приложения, остаётся вместе с данными приложения на эмуляторе.
* В коде проекта не изменено ничего; signing configs, ключи и `.env` не трогались; ничего не коммитилось.
