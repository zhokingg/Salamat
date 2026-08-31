import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'supabase_service.dart';

/// One turn in the coach conversation.
@immutable
class CoachMessage {
  const CoachMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  Map<String, String> toWire() =>
      {'role': fromUser ? 'user' : 'assistant', 'content': text};
}

/// The server's view of this account's coach access.
@immutable
class CoachStatus {
  const CoachStatus({
    required this.isPro,
    required this.used,
    required this.remaining,
    required this.monthlyLimit,
  });

  final bool isPro;
  final int used;
  final int remaining;
  final int monthlyLimit;

  bool get canSend => isPro && remaining > 0;
}

/// Why a message could not be sent.
///
/// Four outcomes rather than one error, because each needs a different screen:
/// subscribe, wait for next month, check the connection, or the feature is not
/// switched on yet.
enum CoachFailure {
  /// Free tier. The coach is Pro-only.
  notSubscribed,

  /// Pro, but this month's messages are used up.
  monthlyLimit,

  /// Could not reach the service.
  offline,

  /// The function or migration 0008 is not deployed yet.
  unavailable,
}

/// Nutrition chat, proxied through the `coach` Edge Function.
///
/// The key stays on the server, and so do both limits: the subscription check
/// and the monthly message cap are enforced in Postgres by
/// `consume_coach_message`, not here. Everything in this file is presentation.
class CoachService {
  CoachService._();

  static const String _kFunctionName = 'coach';
  static const Duration _kTimeout = Duration(seconds: 45);

  /// Token usage of the most recent exchange, for cost reporting.
  static ({int? input, int? output})? lastUsage;

  /// Reads the gates without sending anything. Null when unavailable.
  static Future<CoachStatus?> status() async {
    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) return null;
    try {
      final res = await SupabaseService.client.rpc('coach_status');
      final row = res is List ? (res.isEmpty ? null : res.first) : res;
      if (row is! Map) return null;
      return CoachStatus(
        isPro: row['is_pro'] == true,
        used: (row['used'] as num?)?.toInt() ?? 0,
        remaining: (row['remaining'] as num?)?.toInt() ?? 0,
        monthlyLimit: (row['monthly_limit'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Coach] status failed: $e');
      return null;
    }
  }

  /// Sends the conversation and returns the reply, or why it could not.
  ///
  /// [history] is the whole visible conversation; the server keeps only the
  /// most recent window of it, so cost does not grow without bound as the
  /// chat gets longer.
  static Future<(String?, CoachFailure?)> send({
    required List<CoachMessage> history,
    required Map<String, dynamic> context,
    required String lang,
  }) async {
    if (!SupabaseService.isReady) return (null, CoachFailure.offline);

    try {
      final res = await SupabaseService.client.functions
          .invoke(_kFunctionName, body: {
            'messages': history.map((m) => m.toWire()).toList(),
            'context': context,
            'lang': lang,
          })
          .timeout(_kTimeout);

      final data = res.data;
      if (res.status != 200 || data is! Map) {
        return (null, CoachFailure.offline);
      }
      final usage = data['_usage'];
      if (usage is Map) {
        lastUsage = (
          input: (usage['input_tokens'] as num?)?.round(),
          output: (usage['output_tokens'] as num?)?.round(),
        );
      }
      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        return (null, CoachFailure.offline);
      }
      return (reply.trim(), null);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] : null;
      if (kDebugMode) debugPrint('[Coach] status ${e.status}: $details');
      return switch (code) {
        'not_subscribed' => (null, CoachFailure.notSubscribed),
        'monthly_limit' => (null, CoachFailure.monthlyLimit),
        // The gate answers this when migration 0008 is missing: the function
        // fails closed rather than giving a paid feature away.
        'server_misconfigured' => (null, CoachFailure.unavailable),
        _ => (null, CoachFailure.offline),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('[Coach] send failed: $e');
      return (null, CoachFailure.offline);
    }
  }
}
