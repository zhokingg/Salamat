import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/food.dart';
import '../../providers/meals_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/text_styles.dart';
import 'portion_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialMealType});

  final MealType? initialMealType;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  late MealType _mealType;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? MealType.breakfast;
    _queryCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<Food> get _filtered {
    final q = _queryCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return kFoods;
    return kFoods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: SalamatColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SalamatColors.ink,
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          loc.searchTitle,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SalamatColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SalamatDims.screenPadding,
                8,
                SalamatDims.screenPadding,
                12,
              ),
              child: _SearchField(controller: _queryCtrl, hint: loc.searchHint),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SalamatDims.screenPadding,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final t in MealType.values) ...[
                      _MealChip(
                        type: t,
                        selected: _mealType == t,
                        onTap: () => setState(() => _mealType = t),
                      ),
                      if (t != MealType.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final food = _filtered[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _FoodCard(
                      food: food,
                      onAdd: () => showPortionSheet(
                        context,
                        food: food,
                        mealType: _mealType,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
      borderSide: const BorderSide(color: SalamatColors.line, width: 1.5),
    );
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: SalamatText.body.copyWith(fontWeight: FontWeight.w600),
      cursorColor: SalamatColors.g1,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: SalamatText.body.copyWith(color: SalamatColors.i3),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('🔍', style: TextStyle(fontSize: 18)),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),
        filled: true,
        fillColor: SalamatColors.surf,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
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
          color: selected ? SalamatColors.g1 : SalamatColors.g4,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          type.label(loc),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? SalamatColors.surf : SalamatColors.g1,
          ),
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.food, required this.onAdd});

  final Food food;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: food.categoryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              food.firstLetter,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SalamatColors.surf,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  food.name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  loc.searchPer100(food.kcalPer100),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: SalamatColors.i3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SalamatColors.g1,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: SalamatColors.surf,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
