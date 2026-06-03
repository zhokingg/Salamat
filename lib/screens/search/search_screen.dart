import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/food.dart';
import '../../providers/meals_provider.dart';
import '../../services/food_repository.dart';
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
  final ScrollController _scrollCtrl = ScrollController();
  late MealType _mealType;

  static const _debounceDuration = Duration(milliseconds: 300);
  Timer? _debounce;

  final List<Food> _items = [];
  int _offset = 0;
  bool _loading = false; // first page loading
  bool _loadingMore = false; // appending next page
  bool _hasMore = true;
  bool _offline = false; // true once we fell back to kFoods

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType ?? MealType.breakfast;
    _queryCtrl.addListener(_onQueryChanged);
    _scrollCtrl.addListener(_onScroll);
    _resetAndLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onQueryChanged);
    _queryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _resetAndLoad);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) _loadMore();
  }

  /// Local fallback used when Supabase is unreachable.
  List<Food> _localFallback(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return kFoods;
    return kFoods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _resetAndLoad() async {
    final query = _queryCtrl.text;
    setState(() {
      _loading = true;
      _offline = false;
      _offset = 0;
      _hasMore = true;
      _items.clear();
    });
    try {
      final repo = ref.read(foodRepositoryProvider);
      final page = await repo.search(query: query, offset: 0);
      if (!mounted || query != _queryCtrl.text) return;
      setState(() {
        _items.addAll(page);
        _offset = page.length;
        _hasMore = page.length == FoodRepository.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || query != _queryCtrl.text) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_localFallback(query));
        _offline = true;
        _hasMore = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _offline) return;
    final query = _queryCtrl.text;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(foodRepositoryProvider);
      final page = await repo.search(query: query, offset: _offset);
      if (!mounted || query != _queryCtrl.text) return;
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length == FoodRepository.pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
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
              // These chips pick the meal slot a tapped dish gets added to
              // (breakfast/lunch/dinner/snack) — they are NOT a dish filter.
              // The label makes that intent explicit.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.searchAddTo,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SalamatColors.i3,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            if (_offline)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SalamatDims.screenPadding,
                  4,
                  SalamatDims.screenPadding,
                  0,
                ),
                child: Text(
                  loc.searchOffline,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.i3,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations loc) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SalamatColors.g1),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          loc.searchEmpty,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: SalamatColors.i3,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: SalamatColors.g1,
                ),
              ),
            ),
          );
        }
        final food = _items[i];
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
