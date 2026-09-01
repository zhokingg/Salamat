import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'providers/locale_provider.dart';
import 'providers/meals_provider.dart';
import 'services/auth_link.dart';
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
      builder: (context, child) => _Notices(child: child),
    );
  }
}


/// One-off messages that have no screen of their own: a meal that did not
/// save, and a link from an email that did something worth naming.
///
/// Every path that logs a meal fires `mealsProvider.add(...)` and moves on —
/// the sheet closes, the camera pops — so there is nobody holding the future
/// when the write fails. The notifier rolls the entry back and leaves a
/// [MealWriteFailure] on the state; this is what turns that into something the
/// person sees, instead of a dish that quietly disappears by the next launch.
class _Notices extends ConsumerStatefulWidget {
  const _Notices({required this.child});

  final Widget? child;

  @override
  ConsumerState<_Notices> createState() => _NoticesState();
}

class _NoticesState extends ConsumerState<_Notices> {
  @override
  void initState() {
    super.initState();
    authLinkNotice.addListener(_onAuthLink);
  }

  @override
  void dispose() {
    authLinkNotice.removeListener(_onAuthLink);
    super.dispose();
  }

  /// Says out loud what a link from an email did.
  ///
  /// The email-change link is the one that needs it: it lands on settings, and
  /// without a word there the screen just appears, with the address quietly
  /// different. The failure case has its own screen and needs nothing here.
  void _onAuthLink() {
    final result = authLinkNotice.value;
    if (result == null || !mounted) return;
    authLinkNotice.value = null;
    if (result.kind != AuthLinkKind.emailChange) return;
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (loc == null || messenger == null) return;
    final email = result.email;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text(
            email == null
                ? loc.authEmailConfirmedPlain
                : loc.authEmailConfirmed(email),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
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
    return widget.child ?? const SizedBox.shrink();
  }
}
