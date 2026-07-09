import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/dimensions.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import '../manual_entry/manual_entry_sheet.dart';
import '../manual_entry/photo_limit_sheet.dart';

/// Today's diary, grouped by meal slot. Pure recomposition of existing data —
/// all reads/writes still go through [mealsProvider].
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  void _onCamera(BuildContext context, WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    if (sub.canTakePhoto) {
      context.push('/camera');
    } else {
      showPhotoLimitSheet(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final meals = ref.watch(mealsProvider).valueOrNull ?? const MealsState();
    final localeTag = Localizations.localeOf(context).toString();
    final dateLine = _capitalize(
      DateFormat('EEEE, d MMMM', localeTag).format(DateTime.now()),
    );
    final isEmptyDay =
        MealType.values.every((t) => meals.forType(t).isEmpty);

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDims.tabBarHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.dashboardMeals,
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: SalamatTokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLine,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SalamatTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isEmptyDay)
          _EmptyDay(
            onCamera: () => _onCamera(context, ref),
            onManual: () => showManualEntrySheet(context),
          )
        else ...[
          for (final type in MealType.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MealSection(
                type: type,
                entries: meals.forType(type),
                totalKcal: meals.totalKcal(type),
                onEntryTap: () =>
                    showManualEntrySheet(context, initialMealType: type),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => showManualEntrySheet(context),
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
                  loc.manualAddButton,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// One meal-slot section: duotone slot icon + title + kcal pill, then the
/// entries (or a quiet "Nothing yet" line — deliberately not a card).
class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.type,
    required this.entries,
    required this.totalKcal,
    required this.onEntryTap,
  });

  final MealType type;
  final List<MealEntry> entries;
  final int totalKcal;
  final VoidCallback onEntryTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final empty = entries.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SalamatTokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SalamatIcon(
                type.icon,
                size: 20,
                color: SalamatTokens.accentDeep,
                bubbleColor: SalamatTokens.bubbleMint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.label(loc),
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SalamatTokens.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: SalamatTokens.pill(),
                child: Text(
                  loc.dashboardKcalWithValue(totalKcal),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: totalKcal == 0
                        ? SalamatTokens.textMuted
                        : SalamatTokens.pillText,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          if (empty) ...[
            const SizedBox(height: 10),
            Text(
              loc.mealsNothingYet,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SalamatTokens.textMuted,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(height: 1, color: SalamatTokens.ringTrack),
            const SizedBox(height: 10),
            for (var i = 0; i < entries.length; i++) ...[
              _EntryRow(entry: entries[i], onTap: onEntryTap),
              if (i != entries.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final MealEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final time = entry.eatenAt != null
        ? DateFormat.Hm().format(entry.eatenAt!)
        : null;
    final parts = <String>[
      loc.dashboardKcalWithValue(entry.kcal),
      // Macros estimated from kcal (30/30/40) — the "~" keeps it honest.
      if (entry.isMacroEstimated)
        loc.mealsEstimatedMacros(
          entry.estimatedProtein.round(),
          entry.estimatedFat.round(),
          entry.estimatedCarbs.round(),
        ),
      if (time != null) time,
    ];
    final detail = parts.join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FoodIllustration.forDish(entry.name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: SalamatTokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: SalamatTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whole-day-empty state: camera sticker invite + the two add actions.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onCamera, required this.onManual});

  final VoidCallback onCamera;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          SalamatIcon(
            PhosphorIcons.camera(PhosphorIconsStyle.duotone),
            size: 40,
            color: SalamatTokens.accent,
            bubbleColor: SalamatTokens.bubbleMint,
          ),
          const SizedBox(height: 16),
          Text(
            loc.dashboardSnapFirstMeal,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SalamatTokens.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: SalamatDims.buttonHeight,
            child: ElevatedButton(
              onPressed: onCamera,
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
                loc.navCameraAction,
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
              onPressed: onManual,
              style: OutlinedButton.styleFrom(
                foregroundColor: SalamatTokens.accentDeep,
                side:
                    const BorderSide(color: SalamatTokens.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatTokens.radiusCta),
                ),
              ),
              child: Text(
                loc.manualAddButton,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Meal-slot icons (Duotone) — shared visual mapping for the diary.
extension MealTypeIcon on MealType {
  PhosphorIconData get icon => switch (this) {
        MealType.breakfast =>
          PhosphorIcons.sunHorizon(PhosphorIconsStyle.duotone),
        MealType.lunch => PhosphorIcons.sun(PhosphorIconsStyle.duotone),
        MealType.dinner =>
          PhosphorIcons.moonStars(PhosphorIconsStyle.duotone),
        MealType.snack => PhosphorIcons.cookie(PhosphorIconsStyle.duotone),
      };
}
