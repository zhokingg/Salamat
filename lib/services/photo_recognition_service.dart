import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../providers/subscription_provider.dart';
import 'supabase_service.dart';

/// Food photo recognition + lifetime photo-quota tracking.
///
/// Free tier: 3 photos TOTAL (lifetime). Pro tier: 10/day.
///
/// Quota lives in `public.photo_usage` (migration 0001_init.sql) and is
/// bumped via the `increment_photo_usage()` RPC (auth-scoped).
///
/// Recognition itself is proxied through the `recognize-food` Supabase
/// Edge Function. The Anthropic API key lives in a Supabase secret —
/// it never ships in the APK. The client only ever sees the parsed JSON
/// the function returns.
class PhotoRecognitionService {
  PhotoRecognitionService._();

  static const String _kFunctionName = 'recognize-food';

  /// Returns true if [userId] is allowed to take another photo.
  /// Pro: always true. Free: true iff lifetime total in `photo_usage` < 3.
  /// Not-signed-in or backend error: fail-open (return true).
  static Future<bool> canUsePhoto(String userId, bool isPro) async {
    if (isPro) return true;
    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) {
      return true;
    }
    try {
      final rows = await SupabaseService.client
          .from('photo_usage')
          .select('count');
      final total = (rows as List).fold<int>(
        0,
        (sum, r) => sum + (((r as Map)['count'] as num?)?.toInt() ?? 0),
      );
      return total < kFreeLifetimePhotoLimit;
    } catch (e) {
      if (kDebugMode) debugPrint('canUsePhoto error: $e');
      return true;
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
    } catch (e) {
      if (kDebugMode) debugPrint('recognizeFood error: $e');
      return null;
    }
  }

  /// Bumps the per-day counter via `increment_photo_usage()` RPC. The RPC
  /// uses `auth.uid()`; [userId] is accepted for signature compatibility
  /// but unused on the wire.
  static Future<void> incrementUsage(String userId) async {
    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) return;
    try {
      await SupabaseService.client.rpc('increment_photo_usage');
    } catch (e) {
      if (kDebugMode) debugPrint('incrementUsage error: $e');
    }
  }
}
