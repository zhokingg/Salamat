import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/meal_suggestion_service.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show SalamatCard, SalamatEyebrow;

/// "What to cook" — three dishes from what the user has, sized to what is
/// left of the day.
///
/// Two deliberate choices run through the whole screen:
///   * every nutrition figure is a band, never a point, because the model is
///     estimating from a free-text list;
///   * the fit badge is three-valued, because with a band "does it fit" has a
///     genuine maybe.
class CookScreen extends ConsumerStatefulWidget {
  const CookScreen({super.key});

  @override
  ConsumerState<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends ConsumerState<CookScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  List<MealSuggestion>? _suggestions;
  bool _loading = false;
  SuggestionFailure? _failure;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(pantryProvider.notifier).add(text);
    _input.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _suggest(int remainingKcal) async {
    final pantry = ref.read(pantryProvider);
    if (pantry.isEmpty || _loading) return;
    final meals = ref.read(mealsProvider).valueOrNull ?? const MealsState();
    final user = ref.read(userProvider);
    final norm = user.calorieNorm ?? 2000;

    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final out = await MealSuggestionService.suggest(
        ingredients: pantry,
        remainingKcal: remainingKcal,
        // Same 30/30/40 display split the rest of the app uses for targets.
        remainingProtein: (norm * 0.30 / 4) - meals.totalProtein,
        remainingFat: (norm * 0.30 / 9) - meals.totalFat,
        remainingCarbs: (norm * 0.40 / 4) - meals.totalCarbs,
        goal: user.goal?.name,
        lang: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = out;
        _loading = false;
      });
    } on SuggestionException catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e.kind;
        _loading = false;
      });
    }
  }

  void _addToDiary(MealSuggestion s) {
    final loc = AppLocalizations.of(context)!;
    // The midpoint is the single value the band justifies.
    ref.read(mealsProvider.notifier).add(
          _slotForNow(),
          MealEntry(
            id: const Uuid().v4(),
            name: s.name,
            source: 'suggested',
            grams: 0,
            kcal: s.kcal.mid,
            protein: (s.protein?.mid ?? 0).toDouble(),
            fat: (s.fat?.mid ?? 0).toDouble(),
            carbs: (s.carbs?.mid ?? 0).toDouble(),
          ),
        );
    final messenger = ScaffoldMessenger.of(context);
    if (context.canPop()) context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.cookAddedToDiary(s.name, s.kcal.mid)),
      ),
    );
  }

  static MealType _slotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 22) return MealType.dinner;
    return MealType.snack;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final pantry = ref.watch(pantryProvider);
    final meals = ref.watch(mealsProvider).valueOrNull ?? const MealsState();
    final norm = ref.watch(userProvider).calorieNorm ?? 2000;
    final remaining = norm - meals.totalKcalAll;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(loc.cookTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SalamatDarkDims.screenPadH,
          0,
          SalamatDarkDims.screenPadH,
          40,
        ),
        children: [
          Text(
            loc.cookSubtitle,
            style: SalamatDarkType.captionL.copyWith(color: c.text2),
          ),
          const SizedBox(height: SalamatDarkDims.gap16),
          _RemainingCard(remaining: remaining, norm: norm),
          const SizedBox(height: SalamatDarkDims.gap20),
          _PantryEditor(
            controller: _input,
            focusNode: _inputFocus,
            items: pantry,
            onAdd: _add,
            onRemove: (i) => ref.read(pantryProvider.notifier).removeAt(i),
            onClear: () => ref.read(pantryProvider.notifier).clear(),
          ),
          const SizedBox(height: SalamatDarkDims.gap20),
          ..._resultArea(loc, c, pantry, remaining),
        ],
      ),
    );
  }

  List<Widget> _resultArea(
    AppLocalizations loc,
    SalamatColorsDark c,
    List<String> pantry,
    int remaining,
  ) {
    // Order matters: the states are mutually exclusive and this is the
    // priority the user experiences them in.
    if (remaining <= 0) {
      return [
        _StateCard(
          icon: PhosphorIcons.checkCircle(),
          title: loc.cookNoBudgetTitle,
          body: loc.cookNoBudgetBody,
        ),
      ];
    }
    if (pantry.isEmpty) {
      return [
        _StateCard(
          icon: PhosphorIcons.bowlFood(),
          title: loc.cookEmptyPantryTitle,
          body: loc.cookEmptyPantryBody,
        ),
      ];
    }
    if (_loading) {
      return [
        SalamatCard(
          radius: SalamatDarkDims.rHero,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: c.primary,
                ),
              ),
              const SizedBox(width: SalamatDarkDims.gap12),
              Text(
                loc.cookLoading,
                style: SalamatDarkType.body.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
      ];
    }
    if (_failure != null) {
      return [
        _StateCard(
          icon: PhosphorIcons.warning(),
          title: loc.cookFailedTitle,
          body: loc.cookFailedBody,
          actionLabel: loc.cookRetry,
          onAction: () => _suggest(remaining),
        ),
      ];
    }
    final out = <Widget>[
      _PrimaryButton(
        label: loc.cookSuggestButton,
        onTap: () => _suggest(remaining),
      ),
    ];
    final list = _suggestions;
    if (list != null && list.isNotEmpty) {
      out
        ..add(const SizedBox(height: SalamatDarkDims.gap20))
        ..add(Text(
          loc.cookWhyRange,
          style: SalamatDarkType.micro.copyWith(color: c.text3),
        ));
      for (final s in list) {
        out
          ..add(const SizedBox(height: SalamatDarkDims.gap12))
          ..add(_SuggestionCard(
            suggestion: s,
            remainingKcal: remaining,
            onAdd: () => _addToDiary(s),
          ));
      }
    }
    return out;
  }
}

/// What is left of today, so the user can judge the suggestions against it
/// without leaving the screen.
class _RemainingCard extends StatelessWidget {
  const _RemainingCard({required this.remaining, required this.norm});

  final int remaining;
  final int norm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final over = remaining <= 0;
    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SalamatEyebrow(loc.cookRemainingLabel),
                const SizedBox(height: SalamatDarkDims.gap6),
                Text(
                  '${remaining > 0 ? remaining : 0}',
                  style: SalamatDarkType.numM
                      .copyWith(color: over ? c.err : c.text),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              loc.dashboardConsumedOfNorm(norm),
              style: SalamatDarkType.captionS.copyWith(color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _PantryEditor extends StatelessWidget {
  const _PantryEditor({
    required this.controller,
    required this.focusNode,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final full = items.length >= PantryNotifier.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SalamatEyebrow(loc.cookPantryHeader)),
            if (items.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SalamatDarkDims.gap6,
                    vertical: SalamatDarkDims.gap4,
                  ),
                  child: Text(
                    loc.cookClearAll,
                    style: SalamatDarkType.captionS.copyWith(color: c.text3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: SalamatDarkDims.gap10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !full,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                style: SalamatDarkType.bodyS.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: full
                      ? loc.cookPantryFull(PantryNotifier.maxItems)
                      : loc.cookAddHint,
                ),
              ),
            ),
            const SizedBox(width: SalamatDarkDims.gap8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: full ? null : onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SalamatDarkDims.padCardSmall,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: full ? c.surface2 : c.primary,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
                ),
                child: Text(
                  loc.cookAddButton,
                  style: SalamatDarkType.body
                      .copyWith(color: full ? c.text3 : c.onPrimary),
                ),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: SalamatDarkDims.gap12),
          Wrap(
            spacing: SalamatDarkDims.gap8,
            runSpacing: SalamatDarkDims.gap8,
            children: [
              for (var i = 0; i < items.length; i++)
                _PantryChip(
                  label: items[i],
                  onRemove: () => onRemove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PantryChip extends StatelessWidget {
  const _PantryChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.only(
        left: SalamatDarkDims.gap12,
        right: SalamatDarkDims.gap6,
        top: SalamatDarkDims.gap8,
        bottom: SalamatDarkDims.gap8,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: SalamatDarkType.captionS.copyWith(color: c.text),
          ),
          const SizedBox(width: SalamatDarkDims.gap4),
          Semantics(
            button: true,
            label: loc.cookRemoveItem(label),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: PhosphorIcon(
                  PhosphorIcons.x(),
                  size: 13,
                  color: c.text3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.remainingKcal,
    required this.onAdd,
  });

  final MealSuggestion suggestion;
  final int remainingKcal;
  final VoidCallback onAdd;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final s = widget.suggestion;
    final fit = s.fitFor(widget.remainingKcal);

    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: SalamatDarkType.h3.copyWith(color: c.text),
                ),
              ),
              const SizedBox(width: SalamatDarkDims.gap8),
              _FitBadge(fit: fit),
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                loc.cookRangeKcal(s.kcal.min, s.kcal.max),
                style: SalamatDarkType.numTitle.copyWith(color: c.text),
              ),
              if (s.timeMinutes != null) ...[
                const SizedBox(width: SalamatDarkDims.gap10),
                PhosphorIcon(PhosphorIcons.clock(), size: 13, color: c.text3),
                const SizedBox(width: SalamatDarkDims.gap4),
                Text(
                  loc.cookTimeMinutes(s.timeMinutes!),
                  style: SalamatDarkType.captionS.copyWith(color: c.text3),
                ),
              ],
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap12),
          Row(
            children: [
              if (s.protein != null)
                Expanded(
                  child: _MacroBand(
                    label: loc.dashboardMacroProtein,
                    range: s.protein!,
                    color: c.primary,
                  ),
                ),
              if (s.carbs != null) ...[
                const SizedBox(width: SalamatDarkDims.gap8),
                Expanded(
                  child: _MacroBand(
                    label: loc.dashboardMacroCarbs,
                    range: s.carbs!,
                    color: c.secondary,
                  ),
                ),
              ],
              if (s.fat != null) ...[
                const SizedBox(width: SalamatDarkDims.gap8),
                Expanded(
                  child: _MacroBand(
                    label: loc.dashboardMacroFat,
                    range: s.fat!,
                    color: c.accent,
                  ),
                ),
              ],
            ],
          ),
          if (s.ingredients.isNotEmpty || s.steps.isNotEmpty) ...[
            const SizedBox(height: SalamatDarkDims.gap12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded ? loc.cookStepsHeader : loc.cookIngredientsHeader,
                    style: SalamatDarkType.captionS.copyWith(
                      color: c.primaryInk,
                      fontWeight: SalamatDarkType.semi,
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap4),
                  PhosphorIcon(
                    _expanded
                        ? PhosphorIcons.caretUp()
                        : PhosphorIcons.caretDown(),
                    size: 12,
                    color: c.primaryInk,
                  ),
                ],
              ),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: SalamatDarkDims.gap10),
            if (s.ingredients.isNotEmpty) ...[
              SalamatEyebrow(loc.cookIngredientsHeader),
              const SizedBox(height: SalamatDarkDims.gap6),
              for (final i in s.ingredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.name,
                          style: SalamatDarkType.caption
                              .copyWith(color: c.text2),
                        ),
                      ),
                      Text(
                        i.amount,
                        style:
                            SalamatDarkType.caption.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
            ],
            if (s.steps.isNotEmpty) ...[
              const SizedBox(height: SalamatDarkDims.gap10),
              SalamatEyebrow(loc.cookStepsHeader),
              const SizedBox(height: SalamatDarkDims.gap6),
              for (var i = 0; i < s.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${i + 1}. ${s.steps[i]}',
                    style: SalamatDarkType.caption
                        .copyWith(color: c.text2, height: 1.4),
                  ),
                ),
            ],
          ],
          const SizedBox(height: SalamatDarkDims.gap14),
          _PrimaryButton(label: loc.cookAddToDiary, onTap: widget.onAdd),
          const SizedBox(height: SalamatDarkDims.gap6),
          Center(
            child: Text(
              loc.cookMidpointNote,
              style: SalamatDarkType.micro.copyWith(color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBand extends StatelessWidget {
  const _MacroBand({
    required this.label,
    required this.range,
    required this.color,
  });

  final String label;
  final NutrientRange range;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SalamatDarkType.eyebrowS
                .copyWith(color: color, letterSpacing: 0.1 * 10.5),
          ),
          const SizedBox(height: SalamatDarkDims.gap4),
          Text(
            loc.cookRangeG(range.min, range.max),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SalamatDarkType.captionS.copyWith(
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-valued fit badge. `borderline` is not a hedge — it is the honest
/// answer when the band crosses the remainder.
class _FitBadge extends StatelessWidget {
  const _FitBadge({required this.fit});

  final BudgetFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final (label, fg) = switch (fit) {
      BudgetFit.fits => (loc.cookFits, c.primary),
      BudgetFit.borderline => (loc.cookBorderline, c.warn),
      BudgetFit.over => (loc.cookOver, c.err),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Text(
        label,
        style: SalamatDarkType.eyebrowS.copyWith(color: fg, letterSpacing: 0),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final PhosphorIconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      padding: const EdgeInsets.all(SalamatDarkDims.padHero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
              ),
              child: PhosphorIcon(icon, size: 24, color: c.primary),
            ),
          ),
          const SizedBox(height: SalamatDarkDims.gap16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: SalamatDarkType.h3.copyWith(color: c.text),
          ),
          const SizedBox(height: SalamatDarkDims.gap8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: SalamatDarkType.captionL.copyWith(color: c.text2),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SalamatDarkDims.gap20),
            _PrimaryButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SalamatDarkDims.ctaPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
        ),
        child: Text(
          label,
          style: SalamatDarkType.btn.copyWith(color: c.onPrimary),
        ),
      ),
    );
  }
}
