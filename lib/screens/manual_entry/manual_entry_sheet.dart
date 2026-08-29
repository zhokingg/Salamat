import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_dark.dart';

/// Free manual meal logging — no limits. Photo scanning is the paid
/// convenience; typing a dish in is always available.
Future<void> showManualEntrySheet(
  BuildContext context, {
  MealType? initialMealType,
}) {
  return showModalBottomSheet(
    context: context,
    // Root navigator: the sheet must cover the shell (incl. the camera FAB).
    useRootNavigator: true,
    backgroundColor: sc.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SalamatDarkDims.rHero),
      ),
    ),
    builder: (_) => ManualEntrySheet(initialMealType: initialMealType),
  );
}

class ManualEntrySheet extends ConsumerStatefulWidget {
  const ManualEntrySheet({super.key, this.initialMealType});

  final MealType? initialMealType;

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  static const int _kcalMin = 1;
  static const int _kcalMax = 5000;
  static const double _defaultPortionG = 100;

  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _portionCtrl = TextEditingController();

  late MealType _mealType;
  bool _detailsOpen = false;
  bool _kcalTouched = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? MealType.breakfast;
    _nameCtrl.addListener(_onChanged);
    _kcalCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _portionCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int? get _kcal => int.tryParse(_kcalCtrl.text.trim());

  bool get _kcalValid =>
      _kcal != null && _kcal! >= _kcalMin && _kcal! <= _kcalMax;

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && _kcalValid;

  double _macro(TextEditingController c) {
    // digitsOnly keeps input >= 0 by construction.
    return double.tryParse(c.text.trim()) ?? 0;
  }

  void _save() {
    if (!_canSave) return;
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final portion = double.tryParse(_portionCtrl.text.trim());
    ref.read(mealsProvider.notifier).add(
          _mealType,
          MealEntry(
            id: const Uuid().v4(),
            name: _nameCtrl.text.trim(),
            grams: (portion == null || portion <= 0)
                ? _defaultPortionG
                : portion,
            kcal: _kcal!,
            protein: _macro(_proteinCtrl),
            fat: _macro(_fatCtrl),
            carbs: _macro(_carbsCtrl),
            source: 'manual',
          ),
        );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          loc.manualAddedSnack(_mealType.labelLower(loc)),
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sc.primaryInk,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final name = _nameCtrl.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
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
                  color: sc.surface3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDarkDims.screenPadH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Live illustration preview — same name-keyword mapping
                      // the diary uses for photo entries.
                      FoodIllustration.forDish(
                        name.isEmpty ? '?' : name,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.manualTitle,
                          style: SalamatDarkType.style(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: sc.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Meal-slot chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in MealType.values) ...[
                          _MealChip(
                            type: t,
                            selected: _mealType == t,
                            onTap: () => setState(() => _mealType = t),
                          ),
                          if (t != MealType.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // White level-2 card with the form fields
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(
                          controller: _nameCtrl,
                          hint: loc.manualNameLabel,
                          keyboardType: TextInputType.text,
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _kcalCtrl,
                          hint: loc.manualKcalLabel,
                          keyboardType: TextInputType.number,
                          digitsOnly: true,
                          errorText: _kcalTouched &&
                                  _kcalCtrl.text.isNotEmpty &&
                                  !_kcalValid
                              ? loc.manualKcalError
                              : null,
                          onChanged: (_) =>
                              setState(() => _kcalTouched = true),
                        ),
                        const SizedBox(height: 8),
                        // Collapsed details block
                        InkWell(
                          onTap: () =>
                              setState(() => _detailsOpen = !_detailsOpen),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SalamatIcon(
                                  _detailsOpen
                                      ? PhosphorIcons.caretUp()
                                      : PhosphorIcons.caretDown(),
                                  size: 16,
                                  color: sc.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  loc.manualAddDetails,
                                  style: SalamatDarkType.style(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: sc.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_detailsOpen) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _proteinCtrl,
                                  hint: loc.manualProtein,
                                  keyboardType: TextInputType.number,
                                  digitsOnly: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Field(
                                  controller: _fatCtrl,
                                  hint: loc.manualFat,
                                  keyboardType: TextInputType.number,
                                  digitsOnly: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  controller: _carbsCtrl,
                                  hint: loc.manualCarbs,
                                  keyboardType: TextInputType.number,
                                  digitsOnly: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _Field(
                                  controller: _portionCtrl,
                                  hint: loc.manualPortion,
                                  keyboardType: TextInputType.number,
                                  digitsOnly: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: SalamatDarkDims.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sc.primary,
                        foregroundColor: sc.onPrimary,
                        disabledBackgroundColor: sc.primarySoft,
                        disabledForegroundColor: sc.text2,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SalamatDarkDims.rButton),
                        ),
                      ),
                      child: Text(
                        loc.manualAddToMeal(_mealType.label(loc)),
                        style: SalamatDarkType.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  const _MealChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MealType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? sc.primary : sc.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type.label(loc),
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? sc.onPrimary : sc.primaryInk,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.digitsOnly = false,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool digitsOnly;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters:
          digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
      onChanged: onChanged,
      style: SalamatDarkType.bodyL.copyWith(fontWeight: FontWeight.w600),
      cursorColor: sc.primary,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        errorText: errorText,
        hintStyle:
            SalamatDarkType.bodyL.copyWith(color: sc.text2),
        filled: true,
        // Fields sit on the white card — the pill tint keeps them visible.
        fillColor: sc.primarySoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: border,
        border: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
          borderSide:
               BorderSide(color: sc.primary, width: 1.5),
        ),
      ),
    );
  }
}
