// Live check of voice entry, as far as a simulator allows.
//
// There is no microphone, so dictation cannot run. What is exercised is
// everything after it: the transcript field (which is what the user corrects),
// the parse of a two-dish phrase through suggest-meal, the per-dish
// confirmation sheet, the save, and the rows that land in Supabase.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';
import 'package:salamat/services/supabase_service.dart';
import 'package:salamat/services/voice_entry_service.dart';

const int _shotPort = 8787;

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final r =
        await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    await (await r.close()).drain<void>();
  } catch (_) {
  } finally {
    c.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['en', 'ru']) {
    final ru = lang == 'ru';
    testWidgets('voice entry ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);
      appRouter.go('/dashboard');
      await settle(tester, ms: 2000);
      debugPrint('V|$lang uid=${SupabaseService.currentUser?.id}');

      // ── the parse itself, straight through the service ──
      final phrase = ru ? 'съел шаурму и колу' : 'I ate a shawarma and a coke';
      final (items, failure) =
          await VoiceEntryService.parse(text: phrase, lang: lang);
      if (items == null) {
        debugPrint('V|$lang parse FAILED $failure');
      } else {
        debugPrint('V|$lang parsed ${items.length} item(s) from "$phrase"');
        for (final i in items) {
          final sum = i.protein * 4 + i.fat * 9 + i.carbs * 4;
          debugPrint('V|$lang   ${i.name} | ${i.grams} g | ${i.kcal} kcal | '
              'P${i.protein.round()} F${i.fat.round()} C${i.carbs.round()} | '
              'sums=${sum.round()} | macrosKnown=${i.macrosKnown}');
        }
      }

      // A sentence with no food in it must come back as "not understood".
      final (none, noneFail) = await VoiceEntryService.parse(
        text: ru ? 'сегодня хорошая погода' : 'the weather is nice today',
        lang: lang,
      );
      debugPrint('V|$lang non-food -> items=${none?.length} failure=$noneFail');

      // ── the UI ──
      appRouter.push('/camera');
      await settle(tester, ms: 2500);
      final voiceTab = find.text(ru ? 'Голос' : 'Voice');
      if (voiceTab.evaluate().isEmpty) {
        debugPrint('V|$lang voice tab NOT FOUND');
        return;
      }
      await tester.tap(voiceTab.first);
      await settle(tester, ms: 1800);
      await shot('voice_${lang}_01_idle');

      // Type what dictation would have produced, so the transcript field —
      // the thing the user corrects — is exercised for real.
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field.first, phrase);
        await settle(tester, ms: 800);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester, ms: 800);
        await shot('voice_${lang}_02_transcript');

        final send = find.text(ru ? 'Найти эти блюда' : 'Find these dishes');
        if (send.evaluate().isNotEmpty) {
          await tester.tap(send.first);
          await settle(tester, ms: 12000);
          // Which sheet actually opened — the confirmation, or a failure?
          final itemsTitle =
              find.text(ru ? 'Добавить эти блюда?' : 'Add these dishes?');
          final isItems = itemsTitle.evaluate().isNotEmpty;
          final which = isItems ? 'items_sheet' : 'failure_sheet';
          await shot('voice_${lang}_03_$which');
          debugPrint('V|$lang sheet=$which');
          if (!isItems) return;

          // Exact label, not a substring: the sheet TITLE also contains
          // "Add"/"Добавить", and tapping that does nothing.
          final n = items?.length ?? 2;
          final add = find.text(ru
              ? (n == 1 ? 'Добавить 1 блюдо' : 'Добавить $n блюда')
              : (n == 1 ? 'Add 1 dish' : 'Add $n dishes'));
          if (add.evaluate().isNotEmpty) {
            await tester.tap(add.first);
            await settle(tester, ms: 4000);
            final rows = await SupabaseService.getTodayFoodLogs();
            debugPrint('V|$lang db rows=${rows.length}');
            for (final r in rows) {
              debugPrint('V|$lang   db_row name=${r['name']} kcal=${r['kcal']} '
                  'protein=${r['protein']} fat=${r['fat']} carbs=${r['carbs']} '
                  'grams=${r['grams']}');
            }
            appRouter.go('/meals');
            await settle(tester, ms: 2500);
            await shot('voice_${lang}_04_diary');
          } else {
            debugPrint('V|$lang add button NOT FOUND');
          }
        } else {
          debugPrint('V|$lang send button NOT FOUND');
        }
      }
    });
  }
}
