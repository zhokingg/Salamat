import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';

import 'providers/locale_provider.dart';
import 'router.dart';
import 'theme/colors.dart';
import 'theme/text_styles.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SalamatColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SalamatColors.g1,
          primary: SalamatColors.g1,
          secondary: SalamatColors.g2,
          surface: SalamatColors.surf,
          onPrimary: SalamatColors.surf,
          onSurface: SalamatColors.ink,
        ),
        textTheme: SalamatText.theme,
        splashFactory: InkRipple.splashFactory,
      ),
    );
  }
}
