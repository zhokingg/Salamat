import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';

import 'providers/locale_provider.dart';
import 'router.dart';
import 'theme/salamat_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Light theme → dark status-bar icons.
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
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
      theme: SalamatTheme.light,
    );
  }
}
