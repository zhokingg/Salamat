import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'supabase_service.dart';

/// A packaged product, as Open Food Facts describes it.
///
/// Macros are per 100 g, matching the shape the photo path already produces,
/// so the confirmation sheet can treat both the same way.
@immutable
class BarcodeProduct {
  const BarcodeProduct({
    required this.barcode,
    required this.name,
    this.brand,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
    this.servingG,
  });

  final String barcode;
  final String name;
  final String? brand;
  final double kcalPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsPer100;

  /// Grams in one serving when the label states one, else null and the app
  /// falls back to 100 g.
  final int? servingG;

  /// "Nutella · Ferrero" when a brand is known, otherwise just the name.
  String get displayName =>
      (brand == null || brand!.isEmpty) ? name : '$name · $brand';

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'kcal_100g': kcalPer100,
        'protein_100g': proteinPer100,
        'fat_100g': fatPer100,
        'carbs_100g': carbsPer100,
        'serving_g': servingG,
      };

  static BarcodeProduct? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final code = raw['barcode'];
    if (name is! String || name.isEmpty || code is! String) return null;
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return BarcodeProduct(
      barcode: code,
      name: name,
      brand: raw['brand'] as String?,
      kcalPer100: d(raw['kcal_100g']),
      proteinPer100: d(raw['protein_100g']),
      fatPer100: d(raw['fat_100g']),
      carbsPer100: d(raw['carbs_100g']),
      servingG: (raw['serving_g'] as num?)?.toInt(),
    );
  }
}

/// Why a lookup produced no product.
///
/// Deliberately distinguishes "we asked and it is not there" from "we could not
/// ask": the first is an ordinary outcome that offers manual entry, the second
/// is a connection problem and says so.
enum BarcodeMiss {
  /// Open Food Facts has no such product.
  notInDatabase,

  /// The product exists but carries no usable nutrition data.
  noNutrition,

  /// Could not reach the lookup at all.
  offline,

  /// The scanner returned something that is not a barcode.
  invalidCode,
}

/// Result of one lookup: a product, or a reason there is none.
@immutable
class BarcodeResult {
  const BarcodeResult.found(this.product) : miss = null;
  const BarcodeResult.miss(this.miss) : product = null;

  final BarcodeProduct? product;
  final BarcodeMiss? miss;

  bool get isFound => product != null;
}

/// Looks up a scanned barcode.
///
/// The request goes through the `barcode-lookup` Edge Function rather than
/// straight to Open Food Facts, so the source can be changed or cached
/// server-side later without an app release.
///
/// **Costs no scan.** A barcode needs no model call, so this never touches
/// `consume_scan` and the photo allowance is untouched by scanning labels.
///
/// Results are cached by barcode — in memory for the session and in
/// SharedPreferences across launches — so the same tin is never looked up
/// twice. Misses are cached too, briefly: rescanning a product that is not in
/// the database should not re-query it every time the camera catches the code.
class BarcodeLookupService {
  BarcodeLookupService._();

  static const String _kFunctionName = 'barcode-lookup';
  static const String _kCacheKey = 'barcode_cache_v1';
  static const Duration _kTimeout = Duration(seconds: 15);

  /// Products are stable; a barcode maps to the same item indefinitely.
  static const int _kMaxCached = 500;

  static final Map<String, BarcodeProduct> _session = {};

  /// Barcodes known to be absent, for this session only. Not persisted: Open
  /// Food Facts gains products constantly and a permanent "not found" would
  /// keep a newly added item invisible.
  static final Set<String> _sessionMisses = {};

  static bool _diskLoaded = false;

  static Future<void> _loadDisk() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((k, v) {
        final p = BarcodeProduct.fromJson(v);
        if (p != null) _session[k.toString()] = p;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Barcode] cache read failed: $e');
    }
  }

  static Future<void> _saveDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var entries = _session.entries.toList();
      if (entries.length > _kMaxCached) {
        entries = entries.sublist(entries.length - _kMaxCached);
      }
      await prefs.setString(
        _kCacheKey,
        jsonEncode({for (final e in entries) e.key: e.value.toJson()}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Barcode] cache write failed: $e');
    }
  }

  /// True when [barcode] can be answered without a network call.
  static Future<bool> isCached(String barcode) async {
    await _loadDisk();
    return _session.containsKey(barcode.trim());
  }

  static Future<BarcodeResult> lookup({
    required String barcode,
    required String lang,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty || !RegExp(r'^[0-9]{8,14}$').hasMatch(code)) {
      return const BarcodeResult.miss(BarcodeMiss.invalidCode);
    }

    await _loadDisk();
    final cached = _session[code];
    if (cached != null) return BarcodeResult.found(cached);
    if (_sessionMisses.contains(code)) {
      return const BarcodeResult.miss(BarcodeMiss.notInDatabase);
    }

    if (!SupabaseService.isReady) {
      return const BarcodeResult.miss(BarcodeMiss.offline);
    }

    try {
      final res = await SupabaseService.client.functions
          .invoke(_kFunctionName, body: {'barcode': code, 'lang': lang})
          .timeout(_kTimeout);

      final data = res.data;
      if (res.status != 200 || data is! Map) {
        return const BarcodeResult.miss(BarcodeMiss.offline);
      }
      if (data['found'] != true) {
        final reason = data['reason'];
        _sessionMisses.add(code);
        return BarcodeResult.miss(
          reason == 'no_nutrition'
              ? BarcodeMiss.noNutrition
              : BarcodeMiss.notInDatabase,
        );
      }
      final product = BarcodeProduct.fromJson(data['product']);
      if (product == null) {
        return const BarcodeResult.miss(BarcodeMiss.noNutrition);
      }
      _session[code] = product;
      unawaited(_saveDisk());
      return BarcodeResult.found(product);
    } on FunctionException catch (e) {
      final details = e.details;
      final code0 = details is Map ? details['error'] : null;
      if (code0 == 'invalid_barcode') {
        return const BarcodeResult.miss(BarcodeMiss.invalidCode);
      }
      if (kDebugMode) debugPrint('[Barcode] status ${e.status}: $details');
      return const BarcodeResult.miss(BarcodeMiss.offline);
    } catch (e) {
      // Timeout, socket failure, anything else: the user is offline as far as
      // this feature is concerned, and the message says so rather than
      // blaming the service.
      if (kDebugMode) debugPrint('[Barcode] lookup failed: $e');
      return const BarcodeResult.miss(BarcodeMiss.offline);
    }
  }
}
