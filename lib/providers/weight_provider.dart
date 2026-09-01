import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'session_provider.dart';

/// A single weight measurement, oldest data comes from `weight_logs`.
class WeightLog {
  const WeightLog({required this.kg, required this.loggedAt});

  final double kg;
  final DateTime loggedAt;
}

/// Weight history, oldest → newest. Awaits bootstrap so the query always
/// runs against a live session. Invalidate after logging a new weight.
final weightLogsProvider = FutureProvider<List<WeightLog>>((ref) async {
  await awaitSession(ref);
  final rows = await SupabaseService.getWeightHistory();
  final logs = <WeightLog>[];
  for (final row in rows) {
    final kg = row['weight_kg'];
    final at = DateTime.tryParse(row['logged_at']?.toString() ?? '');
    if (kg is num && at != null) {
      logs.add(WeightLog(kg: kg.toDouble(), loggedAt: at.toLocal()));
    }
  }
  // getWeightHistory returns newest-first; charts read left→right in time.
  logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  return logs;
});
