# Screens that could not be photographed

Three UI surfaces exist in the code but cannot be reached on an emulator. Per the task
brief their full source and every string they display are dumped here instead of a PNG.
The paywall is documented separately in [`paywall_source.md`](paywall_source.md).

| Screen | Where it lives | Why it is unreachable |
|---|---|---|
| Recognition result sheet (`_ResultSheet`) | `lib/screens/camera/camera_screen.dart:753` | Opens only after a **confident** recognition. The emulator's synthetic camera scene is not food, so `PhotoRecognitionService.recognizeFood()` returns nothing and the UI falls back to the `Could not recognise the dish` snackbar (captured as `37_camera_recognition_error.png`). |
| Out-of-photos stub (`_OutOfPhotosStub`) | `lib/screens/camera/camera_screen.dart:680` | Requires the daily quota to be spent. The quota lives in the Supabase `photo_usage` table and is incremented **only after a successful scan** (`camera_screen.dart:316-317`), which never happens on the emulator. Exhausting it would mean writing to the production Supabase project, so it was left alone. |
| Photo-limit sheet (`showPhotoLimitSheet`) | `lib/screens/manual_entry/photo_limit_sheet.dart` | Same gate — shown by `dashboard_shell.dart:54` / `meals_screen.dart:24` only when `subscription.canTakePhoto == false`. |
| Camera-unavailable stub (`_UnavailableStub`) | `lib/screens/camera/camera_screen.dart:625` | Needs a granted camera permission **plus** an empty `availableCameras()`. Booting the emulator with `-camera-back none -camera-front none` was tried: the camera route then never renders at all, because `_ensureCameraPermission()` pops the route first. |

## Mock data the result sheet is built from

```dart
const _Recognized _kMockResult = _Recognized(
  name: 'Плов узбекский',
  confidence: 87,
  grams: 200,
  kcalPer100: 245,
  proteinPer100: 8,
  fatPer100: 11,
  carbsPer100: 29,
);
```

## `_ResultSheet` — recognition result (camera_screen.dart)

```dart
class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.initial,
    required this.onSave,
    required this.onRetake,
  });

  final _Recognized initial;
  final void Function(_Recognized) onSave;
  final VoidCallback onRetake;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late _Recognized _r;

  @override
  void initState() {
    super.initState();
    _r = widget.initial;
  }

  void _adjust(int delta) {
    final next = (_r.grams + delta).clamp(50, 2000);
    setState(() => _r = _r.withGrams(next));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SalamatColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SalamatDims.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _r.name,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.cameraConfidence(_r.confidence),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.g1,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${_r.kcal}',
                        style: GoogleFonts.manrope(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: SalamatColors.g1,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.cameraKcalPerPortion(_r.grams),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SalamatColors.i3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _MacroRow(
                    label: loc.cameraMacroProtein,
                    value: '${_r.protein.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 10),
                _MacroRow(
                    label: loc.cameraMacroFat,
                    value: '${_r.fat.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 10),
                _MacroRow(
                    label: loc.cameraMacroCarbs,
                    value: '${_r.carbs.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PortionBtn(
                      icon: Icons.remove_rounded,
                      onTap: () => _adjust(-50),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 90,
                      child: Text(
                        loc.gramsSuffix(_r.grams),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: SalamatColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _PortionBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _adjust(50),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: SalamatDims.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => widget.onSave(_r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SalamatColors.g1,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          SalamatDims.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(loc.cameraAddButton, style: SalamatText.btn),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: widget.onRetake,
                    child: Text(
                      loc.cameraRetake,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SalamatColors.i2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SalamatColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SalamatColors.i2,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortionBtn extends StatelessWidget {
  const _PortionBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: SalamatColors.g4,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: SalamatColors.g1),
      ),
    );
  }
}
```

## `_OutOfPhotosStub` + `_UnavailableStub` (camera_screen.dart)

```dart
class _UnavailableStub extends StatelessWidget {
  const _UnavailableStub({required this.onSimulate});

  final Future<void> Function() onSimulate;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SalamatDims.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // The "simulate recognition" mock path is a dev-only affordance.
              // In release the device genuinely has no usable camera, so show
              // a neutral message and no mock button.
              kDebugMode ? loc.cameraUnavailable : loc.cameraUnavailableDevice,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: SalamatDims.buttonHeight,
                child: ElevatedButton(
                  onPressed: onSimulate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SalamatColors.g2,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SalamatDims.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(loc.cameraSimulate, style: SalamatText.btn),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutOfPhotosStub extends StatelessWidget {
  const _OutOfPhotosStub({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SalamatDims.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.cameraOutOfPhotos,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: SalamatDims.buttonHeight,
              child: ElevatedButton(
                onPressed: () => showManualEntrySheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SalamatColors.g1,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SalamatDims.buttonRadius,
                    ),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.manualAddButton,
                  style: SalamatText.btnDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: SalamatDims.buttonHeight,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalamatColors.g2,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SalamatDims.buttonRadius,
                    ),
                  ),
                ),
                child: Text(loc.cameraTryPro, style: SalamatText.btn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## `photo_limit_sheet.dart` (full file)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../theme/dimensions.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import 'manual_entry_sheet.dart';

/// Shown when the free daily photo scan is spent. Manual logging stays free
/// and unlimited — the sheet routes there first, Pro second.
Future<void> showPhotoLimitSheet(
  BuildContext context, {
  MealType? initialMealType,
}) {
  return showModalBottomSheet(
    context: context,
    // Root navigator: the sheet must cover the shell (incl. the camera FAB).
    useRootNavigator: true,
    backgroundColor: SalamatTokens.surface,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SalamatTokens.radiusHero),
      ),
    ),
    builder: (sheetCtx) => Padding(
      padding: const EdgeInsets.fromLTRB(
        SalamatDims.screenPadding,
        20,
        SalamatDims.screenPadding,
        20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: SalamatTokens.ringTrack,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          SalamatIcon(
            PhosphorIcons.camera(PhosphorIconsStyle.duotone),
            size: 28,
            color: SalamatTokens.accent,
            bubbleColor: SalamatTokens.bubbleMint,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(sheetCtx)!.limitTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SalamatTokens.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: SalamatDims.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                showManualEntrySheet(context,
                    initialMealType: initialMealType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SalamatTokens.accentDeep,
                foregroundColor: SalamatTokens.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatTokens.radiusCta),
                ),
              ),
              child: Text(
                AppLocalizations.of(sheetCtx)!.manualAddButton,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: SalamatDims.buttonHeight,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                context.push('/paywall');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: SalamatTokens.accentDeep,
                side: const BorderSide(
                    color: SalamatTokens.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatTokens.radiusCta),
                ),
              ),
              child: Text(
                AppLocalizations.of(sheetCtx)!.limitGoPro,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

## Strings used by the camera screen and its sheets

| key | EN | RU |
|---|---|---|
| `cameraAddButton` | ✓ Add to diary | ✓ Добавить в дневник |
| `cameraAddedSnack` | Added ✓ | Добавлено ✓ |
| `cameraConfidence` | $percent% match | $percent% совпадение |
| `cameraCounter` | $used of $limit | $used из $limit |
| `cameraDialogCancel` | Cancel | Отмена |
| `cameraErrorNoNetwork` | No internet connection | Нет подключения к интернету |
| `cameraErrorServer` | Service is temporarily unavailable | Сервис временно недоступен |
| `cameraHint` | POINT AT THE DISH | НАВЕДИ НА БЛЮДО |
| `cameraKcalPerPortion` | kcal per $g g | ккал на $g г |
| `cameraLoading` | Recognising dish... | Определяю блюдо... |
| `cameraMacroCarbs` | Carbs | Углеводы |
| `cameraMacroFat` | Fat | Жиры |
| `cameraMacroProtein` | Protein | Белки |
| `cameraNotRecognized` | Could not recognise the dish | Не удалось определить блюдо |
| `cameraOpenSettings` | Open Settings | Открыть настройки |
| `cameraOutOfPhotos` | Your free scan for today is used | Бесплатный скан на сегодня использован |
| `cameraPermissionBody` | Allow camera access in Settings to recognise dishes from photos. | Разреши доступ к камере в настройках, чтобы распознавать блюда на фото. |
| `cameraPermissionTitle` | Camera access needed | Нужен доступ к камере |
| `cameraRetake` | ↺ Retake | ↺ Переснять |
| `cameraSimulate` | Simulate recognition | Симулировать распознавание |
| `cameraTryPro` | Try Pro | Попробовать Pro |
| `cameraUnavailable` | Camera not available on the simulator | Камера недоступна на симуляторе |
| `cameraUnavailableDevice` | Camera is not available on this device | Камера недоступна на этом устройстве |
| `gramsSuffix` | $g g | $g г |
| `gramsUnit` | g | г |
