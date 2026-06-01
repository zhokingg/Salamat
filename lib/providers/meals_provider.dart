import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Meal slot. Display labels come from AppLocalizations via the extension
/// below — the enum itself only carries the emoji (purely visual, locale-agnostic).
enum MealType {
  breakfast('🌅'),
  lunch('☀️'),
  dinner('🌙'),
  snack('🥪');

  const MealType(this.emoji);

  final String emoji;
}

extension MealTypeLoc on MealType {
  String label(AppLocalizations loc) => switch (this) {
        MealType.breakfast => loc.mealBreakfast,
        MealType.lunch => loc.mealLunch,
        MealType.dinner => loc.mealDinner,
        MealType.snack => loc.mealSnack,
      };

  String labelLower(AppLocalizations loc) => switch (this) {
        MealType.breakfast => loc.mealBreakfastLower,
        MealType.lunch => loc.mealLunchLower,
        MealType.dinner => loc.mealDinnerLower,
        MealType.snack => loc.mealSnackLower,
      };
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final String id;
  final String name;
  final double grams;
  final int kcal;
  final double protein;
  final double fat;
  final double carbs;
}

class MealsState {
  const MealsState({this.entries = const {}});

  final Map<MealType, List<MealEntry>> entries;

  List<MealEntry> forType(MealType type) => entries[type] ?? const [];

  int totalKcal(MealType type) =>
      forType(type).fold(0, (sum, e) => sum + e.kcal);

  int get totalKcalAll =>
      MealType.values.fold(0, (sum, t) => sum + totalKcal(t));

  double _macroSum(double Function(MealEntry) pick) => MealType.values
      .expand((t) => forType(t))
      .fold(0.0, (sum, e) => sum + pick(e));

  double get totalProtein => _macroSum((e) => e.protein);
  double get totalFat => _macroSum((e) => e.fat);
  double get totalCarbs => _macroSum((e) => e.carbs);

  MealsState copyWithAdded(MealType type, MealEntry entry) {
    final next = Map<MealType, List<MealEntry>>.from(entries);
    final list = List<MealEntry>.from(next[type] ?? const []);
    list.add(entry);
    next[type] = list;
    return MealsState(entries: next);
  }
}

class MealsNotifier extends Notifier<MealsState> {
  @override
  MealsState build() => const MealsState();

  void add(MealType type, MealEntry entry) {
    state = state.copyWithAdded(type, entry);
  }
}

final mealsProvider =
    NotifierProvider<MealsNotifier, MealsState>(MealsNotifier.new);
