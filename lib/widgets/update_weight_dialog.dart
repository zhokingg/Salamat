import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../services/supabase_service.dart';
import '../theme/salamat_theme.dart';

/// Shared "Update weight" dialog — used from the profile setting row and the
/// dashboard Weight card. Persists via upsertUser + logWeight and refreshes
/// [weightLogsProvider] so the sparkline picks the new point up immediately.
Future<void> showUpdateWeightDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  const int minWeight = 40;
  const int maxWeight = 300;
  final loc = AppLocalizations.of(context)!;
  final controller = TextEditingController(
    text: ref.read(userProvider).weight?.round().toString() ?? '',
  );
  String? error;
  final newValue = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: SalamatTokens.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusCard),
          ),
          title: Text(
            loc.profileUpdateWeightDialog,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SalamatTokens.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: loc.profileWeightHint,
              suffixText: loc.profileKgShort,
              errorText: error,
              hintStyle: GoogleFonts.manrope(
                fontSize: 15,
                color: SalamatTokens.textMuted,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: SalamatTokens.ringTrack,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: SalamatTokens.accent,
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                loc.buttonCancel,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SalamatTokens.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null ||
                    parsed < minWeight ||
                    parsed > maxWeight) {
                  setDialogState(() => error =
                      loc.profileWeightRangeError(minWeight, maxWeight));
                  return;
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: Text(
                loc.buttonSave,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SalamatTokens.accentDeep,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  if (newValue != null) {
    final u = ref.read(userProvider);
    ref.read(userProvider.notifier).setBody(
          height: u.height ?? 170,
          weight: newValue.toDouble(),
        );
    // Persist immediately — a local-only mutation silently reverts on the
    // next restart (profile re-hydrates from the server row).
    final updated = ref.read(userProvider);
    SupabaseService.upsertUser(
      name: updated.name.isEmpty ? 'Friend' : updated.name,
      gender: updated.gender == Gender.female ? 'female' : 'male',
      age: updated.age ?? 25,
      heightCm: updated.height ?? 170,
      weightKg: newValue.toDouble(),
      goal: switch (updated.goal) {
        Goal.lose => 'lose',
        Goal.gain => 'gain',
        _ => 'maintain',
      },
      dailyCalories: updated.calorieNorm ?? 2000,
    );
    await SupabaseService.logWeight(newValue.toDouble());
    ref.invalidate(weightLogsProvider);
  }
}
