import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../models/food.dart';
import '../../providers/meals_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/text_styles.dart';

enum _PortionPreset { s, m, l, custom }

extension on _PortionPreset {
  String label(AppLocalizations loc) => switch (this) {
        _PortionPreset.s => loc.portionPresetSmall,
        _PortionPreset.m => loc.portionPresetMedium,
        _PortionPreset.l => loc.portionPresetLarge,
        _PortionPreset.custom => loc.portionPresetCustom,
      };

  int? get grams => switch (this) {
        _PortionPreset.s => 150,
        _PortionPreset.m => 250,
        _PortionPreset.l => 350,
        _PortionPreset.custom => null,
      };
}

Future<void> showPortionSheet(
  BuildContext context, {
  required Food food,
  required MealType mealType,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: SalamatColors.surf,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PortionSheet(food: food, mealType: mealType),
  );
}

class PortionSheet extends ConsumerStatefulWidget {
  const PortionSheet({
    super.key,
    required this.food,
    required this.mealType,
  });

  final Food food;
  final MealType mealType;

  @override
  ConsumerState<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends ConsumerState<PortionSheet> {
  _PortionPreset _preset = _PortionPreset.s;
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  int get _grams {
    final preset = _preset.grams;
    if (preset != null) return preset;
    final parsed = int.tryParse(_customCtrl.text.trim());
    if (parsed == null || parsed <= 0) return 0;
    return parsed;
  }

  bool get _canAdd => _grams > 0;

  int get _kcal => (widget.food.kcalPer100 * _grams / 100).round();
  double get _protein => widget.food.proteinPer100 * _grams / 100;
  double get _fat => widget.food.fatPer100 * _grams / 100;
  double get _carbs => widget.food.carbsPer100 * _grams / 100;

  void _add() {
    if (!_canAdd) return;
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(mealsProvider.notifier).add(
          widget.mealType,
          MealEntry(
            id: const Uuid().v4(),
            name: widget.food.name,
            grams: _grams.toDouble(),
            kcal: _kcal,
            protein: _protein,
            fat: _fat,
            carbs: _carbs,
          ),
        );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: SalamatColors.g1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.portionAddedSnack(widget.mealType.labelLower(loc)),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
                  widget.food.name,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.portionPer100,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: SalamatColors.i3,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (final p in _PortionPreset.values) ...[
                      Expanded(
                        child: _PortionChip(
                          preset: p,
                          selected: _preset == p,
                          onTap: () => setState(() => _preset = p),
                        ),
                      ),
                      if (p != _PortionPreset.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
                if (_preset == _PortionPreset.custom) ...[
                  const SizedBox(height: 16),
                  _CustomGramsField(
                    controller: _customCtrl,
                    hint: loc.portionCustomHint,
                    suffix: loc.gramsUnit,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 20),
                _ResultCard(
                  kcal: _kcal,
                  protein: _protein,
                  fat: _fat,
                  carbs: _carbs,
                  grams: _grams,
                ),
                const SizedBox(height: 20),
                _AddButton(
                  label: loc.portionAddToMeal(widget.mealType.label(loc)),
                  enabled: _canAdd,
                  onTap: _add,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortionChip extends StatelessWidget {
  const _PortionChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _PortionPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final grams = preset.grams;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? SalamatColors.g1 : SalamatColors.g4,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? SalamatColors.g1 : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              preset.label(loc),
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? SalamatColors.surf : SalamatColors.g1,
                height: 1.0,
              ),
            ),
            if (grams != null) ...[
              const SizedBox(height: 4),
              Text(
                loc.portionGramsShort(grams),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? SalamatColors.surf.withValues(alpha: 0.8)
                      : SalamatColors.i2,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomGramsField extends StatelessWidget {
  const _CustomGramsField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    required this.suffix,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
      borderSide: const BorderSide(color: SalamatColors.line, width: 2),
    );
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: SalamatText.body.copyWith(fontWeight: FontWeight.w700),
      cursorColor: SalamatColors.g1,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: SalamatText.body.copyWith(color: SalamatColors.i3),
        hintStyle: SalamatText.body.copyWith(color: SalamatColors.i3),
        filled: true,
        fillColor: SalamatColors.surf,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: border,
        border: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
          borderSide: const BorderSide(color: SalamatColors.g1, width: 2),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.grams,
  });

  final int kcal;
  final double protein;
  final double fat;
  final double carbs;
  final int grams;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SalamatColors.g4,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatColors.g3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$kcal',
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: SalamatColors.ink,
                  height: 1.0,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  loc.portionKcalWithGrams(grams),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SalamatColors.i2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroBadge(label: 'Б', value: protein),
              const SizedBox(width: 12),
              _MacroBadge(label: 'Ж', value: fat),
              const SizedBox(width: 12),
              _MacroBadge(label: 'У', value: carbs),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  const _MacroBadge({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SalamatColors.i2,
            ),
          ),
          TextSpan(
            text: '${value.toStringAsFixed(1)}${loc.gramsUnit}',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SalamatColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: SizedBox(
        width: double.infinity,
        height: SalamatDims.buttonHeight,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: SalamatColors.g1,
            disabledBackgroundColor: SalamatColors.g1,
            disabledForegroundColor: SalamatColors.surf,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
            ),
          ),
          child: Text(label, style: SalamatText.btn),
        ),
      ),
    );
  }
}
