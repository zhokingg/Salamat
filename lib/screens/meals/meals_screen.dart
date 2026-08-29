import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/salamat_icons.dart';
import '../manual_entry/manual_entry_sheet.dart';
import '../manual_entry/photo_limit_sheet.dart';
import '../../theme/salamat_dark.dart';

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
        bottom: SalamatDarkDims.navHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          // Prototype: `Today's meals` as an H2 with a `--primary-ink` text
          // action on the right that jumps to the camera.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.dashboardTodaysMeals,
                      style: SalamatDarkType.h2.copyWith(color: sc.text),
                    ),
                    const SizedBox(height: SalamatDarkDims.gap2),
                    Text(
                      dateLine,
                      style:
                          SalamatDarkType.captionS.copyWith(color: sc.text3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onCamera(context, ref),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: SalamatDarkDims.gap10,
                    top: SalamatDarkDims.gap6,
                    bottom: SalamatDarkDims.gap6,
                  ),
                  child: Text(
                    loc.dashboardScanAction,
                    style: SalamatDarkType.captionS.copyWith(
                      color: sc.primaryInk,
                      fontWeight: SalamatDarkType.semi,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (isEmptyDay) ...[
          _EmptyDay(
            onCamera: () => _onCamera(context, ref),
            onManual: () => showManualEntrySheet(context),
          ),
          const SizedBox(height: SalamatDarkDims.gap10),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SalamatDarkDims.screenPadH,
            ),
            child: _CookAction(onTap: () => context.push('/cook')),
          ),
        ] else ...[
          for (final type in MealType.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MealSection(
                type: type,
                entries: meals.forType(type),
                totalKcal: meals.totalKcal(type),
                onEntryTap: () =>
                    showManualEntrySheet(context, initialMealType: type),
                onEntryOpen: (e) =>
                    context.push('/meal/${type.name}/${e.id}'),
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
                  foregroundColor: sc.primary,
                  side:  BorderSide(
                      color: sc.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rButton),
                  ),
                ),
                child: Text(
                  loc.manualAddButton,
                  style: SalamatDarkType.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SalamatDarkDims.gap10),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SalamatDarkDims.screenPadH,
            ),
            child: _CookAction(onTap: () => context.push('/cook')),
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
    required this.onEntryOpen,
  });

  final MealType type;
  final List<MealEntry> entries;
  final int totalKcal;
  final VoidCallback onEntryTap;

  /// Opens the detail card for one logged entry.
  final ValueChanged<MealEntry> onEntryOpen;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final empty = entries.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        boxShadow: sc.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SalamatIcon(
                type.icon,
                size: 20,
                color: sc.primary,
                bubbleColor: sc.accentSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.label(loc),
                  style: SalamatDarkType.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: sc.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
        color: sc.primarySoft,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
                child: Text(
                  loc.dashboardKcalWithValue(totalKcal),
                  style: SalamatDarkType.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: totalKcal == 0
                        ? sc.text2
                        : sc.primaryInk,
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
              style: SalamatDarkType.style(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: sc.text2,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(height: 1, color: sc.surface3),
            const SizedBox(height: 10),
            for (var i = 0; i < entries.length; i++) ...[
              _EntryRow(
                entry: entries[i],
                onTap: () => onEntryOpen(entries[i]),
              ),
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
      borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
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
                  style: SalamatDarkType.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: sc.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: SalamatDarkType.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: sc.text2,
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
            color: sc.primary,
            bubbleColor: sc.accentSoft,
          ),
          const SizedBox(height: 16),
          Text(
            loc.dashboardSnapFirstMeal,
            textAlign: TextAlign.center,
            style: SalamatDarkType.style(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: sc.text,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: SalamatDarkDims.buttonHeight,
            child: ElevatedButton(
              onPressed: onCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: sc.primary,
                foregroundColor: sc.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatDarkDims.rButton),
                ),
              ),
              child: Text(
                loc.navCameraAction,
                style: SalamatDarkType.style(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: SalamatDarkDims.buttonHeight,
            child: OutlinedButton(
              onPressed: onManual,
              style: OutlinedButton.styleFrom(
                foregroundColor: sc.primary,
                side:
                     BorderSide(color: sc.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatDarkDims.rButton),
                ),
              ),
              child: Text(
                loc.manualAddButton,
                style: SalamatDarkType.style(
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

/// Quiet entry point to "What to cook". Secondary by design: photo and manual
/// logging stay the primary paths, this is the "I don't know what to make"
/// detour.
class _CookAction extends StatelessWidget {
  const _CookAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        ),
        child: Row(
          children: [
            Container(
              width: SalamatDarkDims.iconTile42,
              height: SalamatDarkDims.iconTile42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.secondarySoft,
                borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon42),
              ),
              child: PhosphorIcon(
                PhosphorIcons.cookingPot(),
                size: 20,
                color: c.secondary,
              ),
            ),
            const SizedBox(width: SalamatDarkDims.gap14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.cookTitle,
                    style: SalamatDarkType.bodyL.copyWith(color: c.text),
                  ),
                  const SizedBox(height: SalamatDarkDims.gap2),
                  Text(
                    loc.cookSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SalamatDarkType.micro.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            PhosphorIcon(
              PhosphorIcons.caretRight(),
              size: 13,
              color: c.text3,
            ),
          ],
        ),
      ),
    );
  }
}
