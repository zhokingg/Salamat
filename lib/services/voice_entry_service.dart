import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'supabase_service.dart';

/// One dish parsed out of a spoken sentence.
///
/// Macros are for [grams] — the whole stated portion, not per 100 g — because
/// speech gives a serving ("a shawarma"), not a weight per hundred grams.
@immutable
class VoiceItem {
  const VoiceItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.macrosKnown,
  });

  final String name;
  final int grams;
  final int kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// False when the server could not reconcile the macros; the app shows a
  /// dash rather than zeros pretending to be measurements.
  final bool macrosKnown;

  static VoiceItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final kcal = (raw['kcal'] as num?)?.toInt();
    if (name is! String || name.trim().isEmpty || kcal == null || kcal <= 0) {
      return null;
    }
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return VoiceItem(
      name: name.trim(),
      grams: (raw['grams'] as num?)?.toInt() ?? 100,
      kcal: kcal,
      protein: d(raw['protein_g']),
      fat: d(raw['fat_g']),
      carbs: d(raw['carbs_g']),
      macrosKnown: raw['macros_known'] != false,
    );
  }
}

/// Why a voice entry produced nothing.
///
/// Three separate outcomes rather than one error, because the fix differs:
/// grant the microphone, speak again, or check the connection.
enum VoiceFailure {
  /// The user declined the microphone, or the OS refuses it.
  micDenied,

  /// Speech recognition is unavailable on this device at all.
  unavailable,

  /// Nothing intelligible was heard, or nothing food-like was said.
  notUnderstood,

  /// The parse could not be reached.
  offline,
}

/// Speech capture and phrase parsing for voice food entry.
///
/// Recognition itself is done by the platform (SFSpeechRecognizer on iOS), so
/// there is no key, no backend and no audio leaves the device for that step.
/// Only the resulting TEXT is sent to `suggest-meal` in its `parse` mode.
///
/// **Costs no scan.** The parse spends model tokens, but so does the macro
/// lookup behind ordinary manual entry, and that is free — this is the same
/// mechanism, so it does not touch `consume_scan` either.
class VoiceEntryService {
  VoiceEntryService._();

  static final SpeechToText _speech = SpeechToText();
  static bool _initialised = false;

  /// Whether the engine has been brought up at least once this session.
  static bool get isListening => _speech.isListening;

  /// Brings up the recogniser, asking for the microphone **at this moment** —
  /// not at app start. Returns null on success, or why it could not start.
  ///
  /// `speech_to_text` triggers the OS permission prompt from `initialize()`,
  /// so calling it lazily is what keeps the request tied to the user actually
  /// tapping the microphone.
  static Future<VoiceFailure?> prepare() async {
    if (_initialised && _speech.isAvailable) return null;
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (kDebugMode) debugPrint('[Voice] error ${e.errorMsg}');
        },
        onStatus: (s) {
          if (kDebugMode) debugPrint('[Voice] status $s');
        },
        debugLogging: kDebugMode,
      );
      _initialised = true;
      if (!ok) {
        // The package folds "denied" and "no recogniser" into one false, so
        // ask it which it was.
        final granted = await _speech.hasPermission;
        return granted ? VoiceFailure.unavailable : VoiceFailure.micDenied;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] initialize failed: $e');
      return VoiceFailure.unavailable;
    }
  }

  /// Starts listening. [onText] fires with partial results so the transcript
  /// can be shown as it is spoken.
  ///
  /// [lang] is the app's current locale, so a Russian UI dictates in Russian
  /// regardless of the phone's own language.
  static Future<VoiceFailure?> listen({
    required String lang,
    required void Function(String text, bool isFinal) onText,
  }) async {
    final failure = await prepare();
    if (failure != null) return failure;

    final localeId = await _resolveLocale(lang);
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
        onResult: (r) => onText(r.recognizedWords, r.finalResult),
      );
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] listen failed: $e');
      return VoiceFailure.unavailable;
    }
  }

  static Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  static Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  /// Maps the app locale onto a recogniser locale the device actually has.
  ///
  /// Falls back to whatever the system offers rather than forcing an id the
  /// device does not know, which would silently recognise nothing.
  static Future<String?> _resolveLocale(String lang) async {
    try {
      final locales = await _speech.locales();
      final want = lang == 'ru' ? 'ru' : 'en';
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith(want)) return l.localeId;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] locales failed: $e');
    }
    return null;
  }

  /// Sends the (possibly user-corrected) transcript to `suggest-meal` and
  /// returns one entry per dish.
  ///
  /// Never consumes a scan.
  static Future<(List<VoiceItem>?, VoiceFailure?)> parse({
    required String text,
    required String lang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (null, VoiceFailure.notUnderstood);
    if (!SupabaseService.isReady) return (null, VoiceFailure.offline);

    try {
      final res = await SupabaseService.client.functions
          .invoke('suggest-meal',
              body: {'mode': 'parse', 'text': trimmed, 'lang': lang})
          .timeout(const Duration(seconds: 30));

      final data = res.data;
      if (res.status != 200 || data is! Map) {
        return (null, VoiceFailure.offline);
      }
      final raw = data['items'];
      final items = <VoiceItem>[];
      if (raw is List) {
        for (final e in raw) {
          final item = VoiceItem.fromJson(e);
          if (item != null) items.add(item);
        }
      }
      // The sentence reached the model and it found no food in it. That is
      // "not understood", not a failure of the connection.
      if (items.isEmpty) return (null, VoiceFailure.notUnderstood);
      return (items, null);
    } on FunctionException catch (e) {
      if (kDebugMode) debugPrint('[Voice] parse status ${e.status}');
      // The model occasionally answers with prose instead of JSON; from the
      // user's side that is the phrase not being understood, and the fix is
      // to say it again.
      return (null, VoiceFailure.notUnderstood);
    } catch (e) {
      if (kDebugMode) debugPrint('[Voice] parse failed: $e');
      return (null, VoiceFailure.offline);
    }
  }
}
