import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../theme/salamat_dark.dart';
import 'manual_entry_sheet.dart';

/// Shown when the free daily photo scan is spent. Manual logging stays free
/// and unlimited — the sheet routes there first, Pro second.
///
/// Repainted to the prototype's sheet chrome: `--sheet` fill, radius 32 on
/// top, a 38x4 `--line-2` grabber, an icon bubble on `--primary-soft`, a
/// 21/600 title over a 13.5 muted line, then a neon primary and a quiet
/// `--surface-2` secondary — the same button pair as the camera's blocked
/// state, so the two read as one family.
Future<void> showPhotoLimitSheet(
  BuildContext context, {
  MealType? initialMealType,
}) {
  return showModalBottomSheet(
    context: context,
    // Root navigator: the sheet must cover the shell (incl. the camera FAB).
    useRootNavigator: true,
    backgroundColor: sc.sheet,
    barrierColor: sc.scrim,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SalamatDarkDims.rSheetTop),
      ),
    ),
    builder: (sheetCtx) {
      final c = sheetCtx.c;
      final loc = AppLocalizations.of(sheetCtx)!;
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, SalamatDarkDims.gap16, 22, 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line2,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
                ),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap24),
            Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
                ),
                child: PhosphorIcon(
                  PhosphorIcons.crownSimple(),
                  size: 24,
                  color: c.primary,
                ),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap16),
            Text(
              loc.limitTitle,
              textAlign: TextAlign.center,
              style: SalamatDarkType.h3.copyWith(color: c.text),
            ),
            const SizedBox(height: SalamatDarkDims.gap8),
            Text(
              loc.paywallSubtitle,
              textAlign: TextAlign.center,
              style: SalamatDarkType.captionL.copyWith(color: c.text2),
            ),
            const SizedBox(height: SalamatDarkDims.gap24),
            _SheetButton(
              label: loc.manualAddButton,
              background: c.primary,
              foreground: c.onPrimary,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                showManualEntrySheet(context, initialMealType: initialMealType);
              },
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            _SheetButton(
              label: loc.limitGoPro,
              background: c.surface2,
              foreground: c.text,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.push('/paywall');
              },
            ),
          ],
        ),
      );
    },
  );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SalamatDarkDims.ctaPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
        ),
        child: Text(
          label,
          style: SalamatDarkType.btn.copyWith(color: foreground),
        ),
      ),
    );
  }
}
