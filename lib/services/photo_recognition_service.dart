import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'supabase_service.dart';

/// Scans a free account gets for the lifetime of the account.
/// Mirrors `public.free_scan_allowance()` (migration 0006) — the server is
/// authoritative; this constant only seeds the UI before the first read.
const int kFreeScanAllowance = 3;

/// The model returned a well-formed answer it is not confident enough about
/// to show as a dish.
///
/// Distinct from a server failure because it means something different to the
/// user ("couldn't recognise the dish", not "service unavailable") and because
/// **no scan was charged** - the server checks confidence before spending one.
/// The threshold itself lives in `recognize-food`; the client deliberately does
/// not carry a copy of it any more.
class LowConfidenceException implements Exception {
  const LowConfidenceException(this.confidence);

  final double confidence;

  @override
  String toString() => 'LowConfidenceException(confidence: $confidence)';
}

/// The account's lifetime scan allowance is spent.
///
/// Distinct from a server failure for the same reason as
/// [LowConfidenceException]: it is not an outage, it is a state the app has a
/// proper screen for. The caller shows the limit sheet (manual entry first,
/// subscription second) rather than "service unavailable".
///
/// The allowance itself is decided by the server; [used] and [allowance] are
/// only what it reported, for display.
class QuotaExhaustedException implements Exception {
  const QuotaExhaustedException({this.used, this.allowance});

  final int? used;
  final int? allowance;

  @override
  String toString() =>
      'QuotaExhaustedException(used: $used, allowance: $allowance)';
}

/// The server's view of this account's scan allowance.
@immutable
class ScanStatus {
  const ScanStatus({
    required this.isPro,
    required this.used,
    required this.remaining,
    required this.allowance,
  });

  final bool isPro;
  final int used;
  final int remaining;
  final int allowance;

  bool get canScan => isPro || remaining > 0;
}

/// Food photo recognition + scan-allowance reads.
///
/// Free tier: THREE scans for the lifetime of the account. Pro: unlimited.
/// Manual logging is free and unlimited — it never touches this allowance.
///
/// The allowance is owned by the SERVER (migration 0006_scan_events.sql):
/// `scan_status()` reports it and `consume_scan()` spends it, both keyed on
/// `auth.uid()`. The Edge Function spends it after a confident recognition;
/// this client never increments anything. Everything here is a read used to
/// paint the UI — a reinstall no longer resets the count.
///
/// Recognition itself is proxied through the `recognize-food` Supabase
/// Edge Function. The Anthropic API key lives in a Supabase secret —
/// it never ships in the APK. The client only ever sees the parsed JSON
/// the function returns.
class PhotoRecognitionService {
  PhotoRecognitionService._();

  static const String _kFunctionName = 'recognize-food';

  /// What the server says about this account's scan allowance.
  ///
  /// Returns null when it cannot be read (not signed in, offline, or migration
  /// 0006 not applied). Callers treat null as "unknown" and neither block the
  /// camera nor claim a number — the server is the gate either way.
  static Future<ScanStatus?> scanStatus() async {
    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) return null;
    try {
      final res = await SupabaseService.client.rpc('scan_status');
      final row = res is List ? (res.isEmpty ? null : res.first) : res;
      if (row is! Map) return null;
      return ScanStatus(
        isPro: row['is_pro'] == true,
        used: (row['used'] as num?)?.toInt() ?? 0,
        remaining: (row['remaining'] as num?)?.toInt() ?? 0,
        allowance: (row['allowance'] as num?)?.toInt() ?? kFreeScanAllowance,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scanStatus error: $e');
      return null;
    }
  }

  /// Sends [imageFile] to the `recognize-food` Edge Function and returns
  /// the parsed JSON map with keys: `name`, `calories_per_100g`,
  /// `protein_per_100g`, `carbs_per_100g`, `fat_per_100g`, `portion_g`,
  /// `confidence` (0..1). Returns null on any failure (network, upstream,
  /// model returned non-JSON). Caller is responsible for checking
  /// `confidence` before showing a result.
  static Future<Map<String, dynamic>?> recognizeFood(File imageFile) async {
    if (!SupabaseService.isReady) {
      if (kDebugMode) {
        debugPrint('recognizeFood: SupabaseService not initialised');
      }
      return null;
    }
    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mediaType = (ext == 'png') ? 'image/png' : 'image/jpeg';

      final res = await SupabaseService.client.functions.invoke(
        _kFunctionName,
        body: {
          'imageBase64': b64,
          'mediaType': mediaType,
        },
      );

      if (res.status != 200) {
        if (kDebugMode) {
          debugPrint('recognizeFood status ${res.status}: ${res.data}');
        }
        return null;
      }
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      // Some transport paths return a JSON string instead of a decoded map.
      if (data is String) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
      return null;
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      if (e.status == 422 && code == 'low_confidence') {
        final c =
            details is Map ? (details['confidence'] as num?)?.toDouble() : null;
        throw LowConfidenceException(c ?? 0);
      }
      if (e.status == 402 && code == 'scan_quota_exhausted') {
        throw QuotaExhaustedException(
          used: details is Map ? (details['used'] as num?)?.toInt() : null,
          allowance:
              details is Map ? (details['allowance'] as num?)?.toInt() : null,
        );
      }
      if (kDebugMode) {
        debugPrint('recognizeFood status ${e.status}: $details');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('recognizeFood error: $e');
      return null;
    }
  }

  // incrementUsage() intentionally removed. The count is spent server-side
  // inside `recognize-food` via `consume_scan()`, atomically and only on a
  // confident result, so a client-side bump would double-count.
}
