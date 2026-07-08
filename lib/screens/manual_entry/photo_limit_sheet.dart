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
