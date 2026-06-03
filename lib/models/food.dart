import 'package:flutter/material.dart';

class Food {
  const Food({
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
    required this.category,
  });

  /// Builds a [Food] from a Supabase `foods` row.
  factory Food.fromMap(Map<String, dynamic> map) {
    double toD(Object? v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int toI(Object? v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return Food(
      name: map['name']?.toString() ?? '',
      kcalPer100: toI(map['kcal_per_100g']),
      proteinPer100: toD(map['protein_per_100g']),
      fatPer100: toD(map['fat_per_100g']),
      carbsPer100: toD(map['carbs_per_100g']),
      category: map['category']?.toString() ?? '',
    );
  }

  final String name;
  final int kcalPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsPer100;
  final String category;

  Color get categoryColor =>
      _categoryColors[category] ?? const Color(0xFF8E8E93);

  String get firstLetter =>
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}

const Map<String, Color> _categoryColors = {
  // Legacy curated categories (kFoods fallback)
  'Основные блюда': Color(0xFFBF7030),
  'Крупы': Color(0xFFB5935A),
  // CSV core dataset categories
  'Блюда ЦА': Color(0xFFBF7030),
  'Гарниры': Color(0xFFB5935A),
  'Супы': Color(0xFFE67E22),
  'Выпечка': Color(0xFFD4A574),
  'Хлеб': Color(0xFFA88354),
  'Салаты': Color(0xFF49AA72),
  'Овощи': Color(0xFF4CAF50),
  'Фрукты': Color(0xFFEF6C9A),
  'Сладкое': Color(0xFFE85A8C),
  'Молочное': Color(0xFF7BB3E8),
  'Мясо': Color(0xFFC0392B),
  'Рыба': Color(0xFF1FA9C7),
  'Яйца': Color(0xFFF1C40F),
  'Напитки': Color(0xFF5B8DEF),
  'Орехи': Color(0xFF8D6E63),
  'Фастфуд': Color(0xFFE07A2F),
  'Завтрак': Color(0xFFF0A500),
};

const List<Food> kFoods = [
  Food(name: 'Плов узбекский', kcalPer100: 245, proteinPer100: 8.0, fatPer100: 11.0, carbsPer100: 29.0, category: 'Основные блюда'),
  Food(name: 'Манты с бараниной', kcalPer100: 185, proteinPer100: 14.0, fatPer100: 9.0, carbsPer100: 18.0, category: 'Основные блюда'),
  Food(name: 'Лагман', kcalPer100: 117, proteinPer100: 7.0, fatPer100: 4.0, carbsPer100: 15.0, category: 'Супы'),
  Food(name: 'Бешбармак', kcalPer100: 130, proteinPer100: 9.0, fatPer100: 5.0, carbsPer100: 14.0, category: 'Основные блюда'),
  Food(name: 'Самса с мясом', kcalPer100: 242, proteinPer100: 9.0, fatPer100: 12.0, carbsPer100: 26.0, category: 'Выпечка'),
  Food(name: 'Шурпа', kcalPer100: 56, proteinPer100: 4.0, fatPer100: 2.0, carbsPer100: 5.0, category: 'Супы'),
  Food(name: 'Боурсак', kcalPer100: 380, proteinPer100: 6.0, fatPer100: 18.0, carbsPer100: 48.0, category: 'Выпечка'),
  Food(name: 'Долма', kcalPer100: 145, proteinPer100: 8.0, fatPer100: 6.0, carbsPer100: 15.0, category: 'Основные блюда'),
  Food(name: 'Лаваш', kcalPer100: 236, proteinPer100: 8.0, fatPer100: 1.0, carbsPer100: 48.0, category: 'Хлеб'),
  Food(name: 'Морковча', kcalPer100: 112, proteinPer100: 2.0, fatPer100: 7.0, carbsPer100: 10.0, category: 'Салаты'),
  Food(name: 'Чак-чак', kcalPer100: 468, proteinPer100: 6.0, fatPer100: 22.0, carbsPer100: 62.0, category: 'Сладкое'),
  Food(name: 'Кефир 2.5%', kcalPer100: 58, proteinPer100: 3.0, fatPer100: 3.0, carbsPer100: 4.0, category: 'Молочное'),
  Food(name: 'Куриный суп', kcalPer100: 68, proteinPer100: 6.0, fatPer100: 2.0, carbsPer100: 6.0, category: 'Супы'),
  Food(name: 'Гречка варёная', kcalPer100: 92, proteinPer100: 3.0, fatPer100: 1.0, carbsPer100: 20.0, category: 'Крупы'),
  Food(name: 'Яйцо варёное', kcalPer100: 155, proteinPer100: 13.0, fatPer100: 11.0, carbsPer100: 1.0, category: 'Яйца'),
];
