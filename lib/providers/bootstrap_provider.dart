import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Resolves once Supabase is initialized AND an (anonymous) session exists.
///
/// This is the app's startup gate. The splash screen holds until it settles,
/// and any provider that needs auth or the network (e.g. [mealsProvider])
/// awaits it in its `build` so calls never fire before `auth.uid()` is ready —
/// closing the old `unawaited(init())` race.
final bootstrapProvider = FutureProvider<void>((ref) async {
  await SupabaseService.init();
});

/// Loads the persisted profile once, after [bootstrapProvider] settles so a
/// real `auth.uid()` exists. Returns the raw `profiles` row, or null when
/// there's no user, no row, or the read failed.
///
/// The splash screen awaits this to decide between onboarding and the
/// dashboard, and to hydrate `userProvider` for a returning user.
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  await ref.watch(bootstrapProvider.future);
  return SupabaseService.getProfile();
});
