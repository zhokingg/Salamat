import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/salamat_dark.dart';
import '../../theme/salamat_icons.dart';

/// Detail card for an already-logged meal, built to the prototype's
/// `scDetail`: back / sub-line / delete header, a 168px gradient hero with a
/// source chip, name + serving, then the numbers card with a portion stepper,
/// four macro tiles and per-macro shares, and Duplicate / Save at the bottom.
///
/// Two prototype pieces are not reproduced because the data does not exist:
///
///   * the recognition-confidence chip — confidence is used at scan time to
///     decide whether to show a result at all and is never stored, so the
///     chip shows how the entry was created instead, and only when that is
///     known;
///   * the micronutrient rows (fibre, sugar, sodium) — the `meals` table
///     holds calories and the three macros, nothing else. The rows are reused
///     for each macro's share of the day, which is derivable, rather than
///     filled with invented micros.
///
/// Editing the portion rescales calories and macros proportionally and writes
/// through `updateEntry`, which PATCHes the existing row so `eaten_at` and the
/// id survive.
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.mealType,
    required this.entryId,
  });

  final MealType mealType;
  final String entryId;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  /// Null until the user touches the stepper; keeps "unchanged" distinct from
  /// "changed back to the original", so Save stays disabled until it matters.
  double? _grams;

  MealEntry? _find() {
    final meals = ref.watch(mealsProvider).valueOrNull;
    if (meals == null) return null;
    for (final e in meals.forType(widget.mealType)) {
      if (e.id == widget.entryId) return e;
    }
    return null;
  }

  void _step(int delta, MealEntry base) {
    final current = _grams ?? base.grams;
    // 50 g steps, same granularity as the camera confirm sheet.
    final next = (current + delta).clamp(10, 2000).toDouble();
    setState(() => _grams = next);
  }

  /// Scales one value by the portion change. A zero original portion cannot be
  /// scaled, so the value is left alone rather than divided by zero.
  double _scaled(double value, MealEntry base) {
    final g = _grams;
    if (g == null || base.grams <= 0) return value;
    return value * g / base.grams;
  }

  Future<void> _delete(MealEntry e) async {
    final loc = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.detailDeleteTitle),
        content: Text(loc.detailDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              loc.profileDeleteConfirm,
              style: TextStyle(color: context.c.err),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(mealsProvider.notifier).remove(widget.mealType, e.id);
    if (!mounted) return;
    _back();
    messenger.showSnackBar(
      SnackBar(content: Text(loc.detailDeleted(e.name))),
    );
  }

  Future<void> _duplicate(MealEntry e) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(mealsProvider.notifier).add(
          widget.mealType,
          MealEntry(
            id: const Uuid().v4(),
            name: e.name,
            grams: _grams ?? e.grams,
            kcal: _scaled(e.kcal.toDouble(), e).round(),
            protein: _scaled(e.protein, e),
            fat: _scaled(e.fat, e),
            carbs: _scaled(e.carbs, e),
            source: e.source,
          ),
        );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(loc.detailDuplicated(e.name))),
    );
  }

  /// Writes the rescaled portion back.
  ///
  /// Scales the STORED macros, never the on-screen estimate: persisting an
  /// estimate would silently promote a guess to recorded data.
  Future<void> _save(MealEntry e) async {
    await ref.read(mealsProvider.notifier).updateEntry(
          widget.mealType,
          MealEntry(
            id: e.id,
            name: e.name,
            grams: _grams ?? e.grams,
            kcal: _scaled(e.kcal.toDouble(), e).round(),
            protein: _scaled(e.protein, e),
            fat: _scaled(e.fat, e),
            carbs: _scaled(e.carbs, e),
            source: e.source,
            eatenAt: e.eatenAt,
          ),
        );
    if (mounted) _back();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go('/meals');

  String? _sourceLabel(AppLocalizations loc, String source) => switch (source) {
        'photo' => loc.detailSourcePhoto,
        'manual' => loc.detailSourceManual,
        'suggested' => loc.detailSourceSuggested,
        'barcode' => loc.detailSourceBarcode,
        'voice' => loc.detailSourceVoice,
        // Rows reloaded from Supabase carry no source — `meals` has no such
        // column — so the chip is simply not drawn.
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final entry = _find();

    if (entry == null) {
      // The entry was deleted (possibly by this screen) or never existed.
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: PhosphorIcon(PhosphorIcons.arrowLeft(), size: 20),
            onPressed: _back,
          ),
        ),
        body: Center(
          child: Text(
            loc.mealsNothingYet,
            style: SalamatDarkType.captionL.copyWith(color: c.text3),
          ),
        ),
      );
    }

    final grams = _grams ?? entry.grams;
    final kcal = _scaled(entry.kcal.toDouble(), entry).round();
    // Stored macros only. While a lookup has not landed the entry has none,
    // and every macro readout on this screen renders a dash instead.
    final known = entry.hasMacros;
    final protein = _scaled(entry.protein, entry);
    final fat = _scaled(entry.fat, entry);
    final carbs = _scaled(entry.carbs, entry);
    final norm = ref.watch(userProvider).calorieNorm ?? 2000;
    final changed = _grams != null && _grams != entry.grams;
    final source = _sourceLabel(loc, entry.source);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: SalamatDarkDims.gap8, bottom: 40),
          children: [
            // ── header ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Row(
                children: [
                  _IconButton(
                    icon: PhosphorIcons.arrowLeft(),
                    onTap: _back,
                  ),
                  const SizedBox(width: SalamatDarkDims.gap12),
                  Expanded(
                    child: Text(
                      entry.eatenAt == null
                          ? _mealLabel(loc, widget.mealType)
                          : '${_mealLabel(loc, widget.mealType)} · '
                              '${loc.detailLoggedAt(
                              DateFormat.Hm().format(entry.eatenAt!),
                            )}',
                      style:
                          SalamatDarkType.captionS.copyWith(color: c.text3),
                    ),
                  ),
                  _IconButton(
                    icon: PhosphorIcons.trash(),
                    color: c.err,
                    onTap: () => _delete(entry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── hero ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Container(
                height: 168,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
                  gradient: LinearGradient(
                    begin: const Alignment(-0.5, -1),
                    end: const Alignment(0.5, 1),
                    colors: [c.primarySoft, c.accentSoft],
                  ),
                ),
                child: Stack(
                  children: [
                    // The matched dish icon, not the same bowl for every
                    // entry. This panel is a sixth of the screen; showing the
                    // identical pictogram on every meal made it decoration.
                    Center(
                      child: FoodIllustration.forDish(
                        entry.name,
                        size: 104,
                        radius: SalamatDarkDims.rCard,
                      ),
                    ),
                    if (source != null)
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(
                              SalamatDarkDims.rIcon36,
                            ),
                            boxShadow: c.shadow1,
                          ),
                          child: Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.sparkle(),
                                size: 12,
                                color: c.primary,
                              ),
                              const SizedBox(width: SalamatDarkDims.gap6),
                              Text(
                                source,
                                style: SalamatDarkType.micro.copyWith(
                                  color: c.text,
                                  fontWeight: SalamatDarkType.semi,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── name + serving ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: SalamatDarkType.numM.copyWith(
                      color: c.text,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: SalamatDarkDims.gap6),
                  Text(
                    loc.detailServing(grams.round()),
                    style: SalamatDarkType.captionL.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── numbers ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Container(
                padding: const EdgeInsets.all(SalamatDarkDims.padCard),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
                  boxShadow: c.shadow1,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$kcal',
                          style: SalamatDarkType.numXl.copyWith(color: c.text),
                        ),
                        const SizedBox(width: SalamatDarkDims.gap10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            loc.dashboardKcalUnit,
                            style: SalamatDarkType.caption
                                .copyWith(color: c.text3),
                          ),
                        ),
                        const Spacer(),
                        _Stepper(
                          grams: grams.round(),
                          onLess: () => _step(-50, entry),
                          onMore: () => _step(50, entry),
                        ),
                      ],
                    ),
                    const SizedBox(height: SalamatDarkDims.gap16),
                    Row(
                      children: [
                        Expanded(
                          child: _MacroTile(
                            value: known ? '${protein.round()}' : loc.mealsMacrosUnknown,
                            label: loc.dashboardMacroProtein,
                          ),
                        ),
                        const SizedBox(width: SalamatDarkDims.gap8),
                        Expanded(
                          child: _MacroTile(
                            value: known ? '${carbs.round()}' : loc.mealsMacrosUnknown,
                            label: loc.dashboardMacroCarbs,
                          ),
                        ),
                        const SizedBox(width: SalamatDarkDims.gap8),
                        Expanded(
                          child: _MacroTile(
                            value: known ? '${fat.round()}' : loc.mealsMacrosUnknown,
                            label: loc.dashboardMacroFat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SalamatDarkDims.gap16),
                    // Prototype's micro rows, repurposed for the share of the
                    // day each macro covers — derivable, unlike micros.
                    _ShareRow(
                      label: loc.dashboardMacroProtein,
                      value: protein,
                      target: norm * 0.30 / 4,
                      color: c.primary,
                    ),
                    _ShareRow(
                      label: loc.dashboardMacroCarbs,
                      value: carbs,
                      target: norm * 0.40 / 4,
                      color: c.secondary,
                    ),
                    _ShareRow(
                      label: loc.dashboardMacroFat,
                      value: fat,
                      target: norm * 0.30 / 9,
                      color: c.accent,
                    ),
                    _ShareRow(
                      label: loc.dashboardCaloriesLabel,
                      value: kcal.toDouble(),
                      target: norm.toDouble(),
                      color: c.warn,
                      unit: '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── actions ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FlatButton(
                      label: loc.detailDuplicate,
                      background: c.surface2,
                      foreground: c.text,
                      onTap: () => _duplicate(entry),
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap10),
                  Expanded(
                    child: _FlatButton(
                      label: loc.detailSave,
                      background: changed ? c.primary : c.surface2,
                      foreground: changed ? c.onPrimary : c.text3,
                      // Nothing to save until the portion actually changed.
                      onTap: changed ? () => _save(entry) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _mealLabel(AppLocalizations loc, MealType t) => switch (t) {
        MealType.breakfast => loc.mealBreakfast,
        MealType.lunch => loc.mealLunch,
        MealType.dinner => loc.mealDinner,
        MealType.snack => loc.mealSnack,
      };
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap, this.color});

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: SalamatDarkDims.iconBtn36,
        height: SalamatDarkDims.iconBtn36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon36),
        ),
        child: PhosphorIcon(icon, size: 15, color: color ?? c.text),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.grams,
    required this.onLess,
    required this.onMore,
  });

  final int grams;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        _Round(icon: PhosphorIcons.minus(), onTap: onLess),
        const SizedBox(width: SalamatDarkDims.gap12),
        SizedBox(
          width: 52,
          child: Text(
            loc.gramsSuffix(grams),
            textAlign: TextAlign.center,
            style: SalamatDarkType.numStat.copyWith(color: c.text),
          ),
        ),
        const SizedBox(width: SalamatDarkDims.gap12),
        _Round(
          icon: PhosphorIcons.plus(),
          onTap: onMore,
          tinted: true,
        ),
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.onTap,
    this.tinted = false,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tinted ? c.primarySoft : c.surface2,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon36),
        ),
        child: PhosphorIcon(
          icon,
          size: 13,
          color: tinted ? c.primaryInk : c.text2,
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: SalamatDarkType.numBody.copyWith(color: c.text),
          ),
          const SizedBox(height: SalamatDarkDims.gap5),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SalamatDarkType.eyebrowS.copyWith(
              color: c.text3,
              fontSize: 10,
              letterSpacing: 0.08 * 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// One macro's share of the daily target: label, 84px bar, value.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    this.unit = 'g',
  });

  final String label;
  final double value;
  final double target;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final fraction = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: SalamatDarkType.caption.copyWith(color: c.text2),
            ),
          ),
          SizedBox(
            width: 84,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Container(color: c.surface3),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: SalamatDarkDims.gap12),
          SizedBox(
            width: 52,
            child: Text(
              loc.detailSharePercent((fraction * 100).round()),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SalamatDarkType.captionXs.copyWith(color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
        ),
        child: Text(
          label,
          style: SalamatDarkType.bodyM.copyWith(
            color: foreground,
            fontWeight: SalamatDarkType.semi,
          ),
        ),
      ),
    );
  }
}
