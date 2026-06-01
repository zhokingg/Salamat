import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App locale + persistence.
///
/// Initial value: if any of the OS preferred locales is Russian → `ru`,
/// otherwise → `en`. Once a stored choice is loaded from
/// SharedPreferences it overrides the OS heuristic. Calling [setLocale]
/// writes the choice through.
class LocaleNotifier extends Notifier<Locale> {
  static const String _kStorageKey = 'app_locale';
  static const Locale _ru = Locale('ru');
  static const Locale _en = Locale('en');

  @override
  Locale build() {
    // Async-load any stored override after first build.
    _loadStored();
    return _detectFromDevice();
  }

  Locale _detectFromDevice() {
    final preferred = WidgetsBinding.instance.platformDispatcher.locales;
    final hasRussian = preferred.any((l) => l.languageCode == 'ru');
    return hasRussian ? _ru : _en;
  }

  Future<void> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kStorageKey);
    if (stored == 'ru' || stored == 'en') {
      state = Locale(stored!);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'ru' && locale.languageCode != 'en') return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStorageKey, locale.languageCode);
  }

  void toggle() {
    setLocale(state.languageCode == 'ru' ? _en : _ru);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
