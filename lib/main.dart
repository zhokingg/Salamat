import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';

import 'providers/locale_provider.dart';
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
    );
  }
}
