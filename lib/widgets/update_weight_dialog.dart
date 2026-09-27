import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../providers/selected_date_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../services/supabase_service.dart';
import '../theme/salamat_dark.dart';

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
          backgroundColor: sc.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
          ),
          title: Text(
            loc.profileUpdateWeightDialog,
            style: SalamatDarkType.style(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: sc.text,
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
              hintStyle: SalamatDarkType.style(
                fontSize: 15,
                color: sc.text2,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:  BorderSide(
                  color: sc.surface3,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:  BorderSide(
                  color: sc.primary,
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
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: sc.text2,
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
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sc.primary,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  if (newValue != null) {
    final day = ref.read(selectedDateProvider);
    final viewingToday = isToday(day);
    final u = ref.read(userProvider);
    // The profile carries CURRENT weight, so only a weigh-in dated today may
    // move it; back-filling an older day must not rewrite today's figure.
    if (viewingToday) {
      ref.read(userProvider.notifier).setBody(
            height: u.height ?? 170,
            weight: newValue.toDouble(),
          );
    }
    // Persist immediately — a local-only mutation silently reverts on the
    // next restart (profile re-hydrates from the server row).
    final updated = ref.read(userProvider);
    if (viewingToday) {
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
        targetWeightKg: updated.targetWeight,
        activityLevel: updated.activityLevel?.name,
        familiarity: updated.familiarity?.name,
      );
    }
    await SupabaseService.logWeight(
      newValue.toDouble(),
      // Local noon on a past day — inside the day whichever way the UTC
      // offset falls.
      loggedAt:
          viewingToday ? null : DateTime(day.year, day.month, day.day, 12),
    );
    ref.invalidate(weightLogsProvider);
  }
}
