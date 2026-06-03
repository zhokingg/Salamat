import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food.dart';
import 'supabase_service.dart';

/// Reads the public, read-only `foods` catalog from Supabase.
///
/// Search is a case-insensitive substring match on `name` (backed by the
/// pg_trgm GIN index), ordered alphabetically and paginated with `range`.
/// Writes are not exposed — the table has no client write policy.
class FoodRepository {
  const FoodRepository();

  static const int pageSize = 30;

  /// Returns one page of foods. [query] empty → whole catalog (paginated).
  /// Throws on transport/DB errors so callers can fall back to [kFoods].
  Future<List<Food>> search({
    required String query,
    required int offset,
    int limit = pageSize,
  }) async {
    if (!SupabaseService.isReady) {
      throw StateError('Supabase not initialized');
    }
    final base = SupabaseService.client.from('foods').select();
    final trimmed = query.trim();
    final filtered = trimmed.isEmpty
        ? base
        : base.ilike('name', '%${_escapeLike(trimmed)}%');
    final rows =
        await filtered.order('name').range(offset, offset + limit - 1);
    return rows.map<Food>(Food.fromMap).toList();
  }

  /// Escapes LIKE wildcards so user-typed `%`/`_` match literally.
  static String _escapeLike(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
}

final foodRepositoryProvider =
    Provider<FoodRepository>((ref) => const FoodRepository());
