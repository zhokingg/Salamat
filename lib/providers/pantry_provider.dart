import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_prefs.dart';
import 'session_provider.dart';

/// The ingredients the user says they have at home.
///
/// Kept on the device only. It is a scratch list the user edits constantly,
/// it carries no value on another device, and persisting it would mean a new
/// Supabase table — which this feature is explicitly not allowed to add.
/// `shared_preferences` is already a dependency, so no new package either.
class PantryNotifier extends Notifier<List<String>> {
  /// Per account — see [userScopedKey].
  static const String _kLegacyKey = 'pantry_items';
  static String get _kStorageKey => userScopedKey(_kLegacyKey);

  /// Guards against unbounded growth from a user pasting a shopping list, and
  /// matches the ceiling the Edge Function enforces server-side.
  static const int maxItems = 40;
  static const int maxItemLength = 60;

  @override
  List<String> build() {
    // Bound to the session: the list is what THIS person says is in their
    // fridge, and it must not appear in the next account.
    ref.watch(currentUidProvider);
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await adoptLegacyKey(prefs, _kLegacyKey, _kStorageKey);
      final raw = prefs.getString(_kStorageKey);
      if (raw == null) {
        state = const [];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = [
        for (final v in decoded)
          if (v is String && v.trim().isNotEmpty) v.trim(),
      ];
    } catch (_) {
      // A corrupt or unreadable entry is not worth failing the screen over —
      // the list simply starts empty.
    }
  }

  Future<void> _persist(List<String> items) async {
    state = items;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(items));
    } catch (_) {
      // In-memory state already updated; a failed write only costs the user
      // the list on next launch.
    }
  }

  /// Adds one item. Accepts a comma-separated paste as several items, which is
  /// how people actually type "яйца, помидоры, рис".
  void add(String raw) {
    final parts = raw
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.length > maxItemLength
            ? s.substring(0, maxItemLength)
            : s);
    if (parts.isEmpty) return;

    final next = [...state];
    for (final p in parts) {
      // Case-insensitive dedupe: "Рис" and "рис" are the same thing.
      final exists =
          next.any((e) => e.toLowerCase() == p.toLowerCase());
      if (!exists && next.length < maxItems) next.add(p);
    }
    if (next.length != state.length) _persist(next);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    _persist(next);
  }

  void clear() => _persist(const []);

  bool get isFull => state.length >= maxItems;
}

final pantryProvider =
    NotifierProvider<PantryNotifier, List<String>>(PantryNotifier.new);
