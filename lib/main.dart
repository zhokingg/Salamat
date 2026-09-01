import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'providers/locale_provider.dart';
import 'providers/meals_provider.dart';
import 'providers/session_provider.dart';
import 'router.dart';
import 'theme/salamat_dark.dart';
import 'theme/salamat_theme.dart';
import 'theme/theme_flag.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Status-bar icons must contrast with the canvas: the redesign's dark skin
  // needs light icons, both light skins need dark ones.
  final darkCanvas = SalamatDarkTheme.brightness == Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: darkCanvas ? Brightness.light : Brightness.dark,
      statusBarBrightness: darkCanvas ? Brightness.dark : Brightness.light,
    ),
  );
  // Supabase init + anonymous sign-in are driven by `bootstrapProvider`, which
  // the splash screen awaits before routing into the app. See splash_screen.dart.
  runApp(const ProviderScope(child: SalamatApp()));
}

class SalamatApp extends ConsumerWidget {
  const SalamatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    // Alive for the whole app. Watching is the point, not the value: it keeps
    // the profile loaded across session changes and re-points RevenueCat at
    // the current Supabase uid. See sessionBindingProvider.
    ref.watch(sessionBindingProvider);
    // A recovery link opens the app with a short-lived session whose only
    // purpose is to set a new password, so take the person straight there.
    // supabase_flutter does the URL handling itself — it owns an app_links
    // subscription and exchanges the PKCE code — and this is the event it
    // raises once that has happened.
    ref.listen(authEventProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.passwordRecovery) {
        appRouter.go('/new-password');
      }
    });
    return MaterialApp.router(
      title: 'Salamat',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // One flag, one switch: `kAppSkin` in theme/theme_flag.dart. The legacy
      // `SalamatTheme.light` is kept intact as the rollback target.
      theme: kRedesignActive ? SalamatDarkTheme.theme : SalamatTheme.light,
      // Sits under MaterialApp's ScaffoldMessenger, so its message shows over
      // whatever screen is on top — including the camera and the portion
      // sheet, which are where meals are actually added.
      builder: (context, child) => _MealWriteWatcher(child: child),
    );
  }
}


/// Says so when a meal did not save.
///
/// Every path that logs a meal fires `mealsProvider.add(...)` and moves on —
/// the sheet closes, the camera pops — so there is nobody holding the future
/// when the write fails. The notifier rolls the entry back and leaves a
/// [MealWriteFailure] on the state; this is what turns that into something the
/// person sees, instead of a dish that quietly disappears by the next launch.
class _MealWriteWatcher extends ConsumerWidget {
  const _MealWriteWatcher({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(mealsProvider, (previous, next) {
      final failure = next.valueOrNull?.writeFailure;
      if (failure == null) return;
      if (previous?.valueOrNull?.writeFailure?.at == failure.at) return;
      final loc = AppLocalizations.of(context);
      if (loc == null) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Text(loc.mealSaveFailed(failure.dish)),
          ),
        );
    });
    return child ?? const SizedBox.shrink();
  }
}
