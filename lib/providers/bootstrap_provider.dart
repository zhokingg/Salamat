import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/onboarding_flag.dart';
import '../services/purchases_service.dart';
import '../services/supabase_service.dart';
import 'user_provider.dart';

/// Resolves once Supabase is initialized AND an (anonymous) session exists.
///
/// This is the app's startup gate. The splash screen holds until it settles,
/// and any provider that needs auth or the network (e.g. [mealsProvider])
/// awaits it in its `build` so calls never fire before `auth.uid()` is ready —
/// closing the old `unawaited(init())` race.
final bootstrapProvider = FutureProvider<void>((ref) async {
  await SupabaseService.init();
  // RevenueCat is keyed to the Supabase (anonymous) uid so a purchase
  // survives reinstalls and stays linked to this account's data.
  await PurchasesService.init();
});

/// A profile row counts as "onboarded" only when both name and calorie norm
/// are set. The `handle_new_user` trigger inserts an empty row at anonymous
/// sign-in, so a row merely existing does not mean onboarding is done.
bool isProfileOnboarded(Map<String, dynamic>? row) {
  if (row == null) return false;
  final name = (row['name'] as String?)?.trim() ?? '';
  final kcalRaw = row['calorie_norm'];
  final kcal = kcalRaw is num
      ? kcalRaw.toInt()
      : int.tryParse(kcalRaw?.toString() ?? '') ?? 0;
  return name.isNotEmpty && kcal > 0;
}

/// Loads the persisted profile once, after [bootstrapProvider] settles so a
/// real `auth.uid()` exists. Returns the raw `profiles` row, or null when
/// there's no user, no row, or the read failed.
///
/// Side effects for an onboarded row: hydrates [userProvider] (so a returning
/// user's data appears even if the splash already navigated on the local
/// flag) and sets the local onboarding flag (covers reinstall-with-profile).
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  await ref.watch(bootstrapProvider.future);
  final row = await SupabaseService.getProfile();
  if (isProfileOnboarded(row)) {
    ref.read(userProvider.notifier).hydrateFromProfile(row!);
    await OnboardingFlag.setCompleted();
  }
  return row;
});
