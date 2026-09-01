// ignore_for_file: avoid_print
//
// The live mail path, now that the project sends through Resend.
//
// One file, several phases, chosen with --dart-define=PHASE=… so the host can
// read the mailbox and confirm a link between two runs. Everything that a
// person would do is done by tapping the real screens; everything that has to
// be shown as evidence is read straight out of the database with the app's own
// client and printed raw.
//
//   PHASE=register   ADDR/PW           register from the UI, then try to sign
//                                      in before confirming
//   PHASE=attach     ADDR/PW/TAKEN     the important one: an anonymous account
//                                      with a day of data gets an email
//   PHASE=signin     ADDR/PW           sign in, then sign out and back in
//
// Addresses are throwaway mailinator boxes, passed in by the runner.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/providers/water_provider.dart';
import 'package:salamat/providers/weight_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/services/auth_service.dart';
import 'package:salamat/services/supabase_service.dart';

const int _shotPort = 8787;
const String _phase = String.fromEnvironment('PHASE');
const String _addr = String.fromEnvironment('ADDR');
const String _pw = String.fromEnvironment('PW');
const String _taken = String.fromEnvironment('TAKEN');
const String _lang = String.fromEnvironment('LANG_CODE', defaultValue: 'ru');
const String _box = String.fromEnvironment('BOX');
const String _newPw = String.fromEnvironment('NEW_PW');

/// The public mailinator inbox, read from the device.
///
/// The whole recovery round trip has to happen inside ONE run of the app:
/// PKCE stores a code verifier when `resetPasswordForEmail` is called and only
/// the same install can redeem the code that comes back. So the test does the
/// waiting and the fetching itself rather than handing off to the host.
const String _inboxApi =
    'https://www.mailinator.com/api/v2/domains/public/inboxes';

Future<String> _httpGet(String url, {bool follow = true}) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await c.getUrl(Uri.parse(url));
    req.followRedirects = follow;
    final res = await req.close();
    if (!follow && res.isRedirect) {
      return res.headers.value('location') ?? '';
    }
    return await res.transform(utf8.decoder).join();
  } finally {
    c.close(force: true);
  }
}

/// The newest link in [box] whose text contains [marker].
Future<String?> _linkFromInbox(String box, String marker,
    {int attempts = 30}) async {
  for (var i = 0; i < attempts; i++) {
    try {
      final list = jsonDecode(await _httpGet('$_inboxApi/$box'));
      final msgs = (list['msgs'] as List).cast<Map<String, dynamic>>();
      for (final m in msgs.reversed) {
        final full =
            jsonDecode(await _httpGet("$_inboxApi/$box/messages/${m['id']}"));
        for (final part in (full['parts'] as List? ?? const [])) {
          final body = (part['body'] ?? '').toString().replaceAll('&amp;', '&');
          final match = RegExp(r"""https?://[^\s"'<>\]]+""")
              .allMatches(body)
              .map((e) => e.group(0)!)
              .where((l) => l.contains(marker));
          if (match.isNotEmpty) return match.first;
        }
      }
    } catch (_) {
      // The public API answers 500 now and then; keep waiting.
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  return null;
}

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

/// Raw rows, printed as the database returns them.
Future<void> dumpRows(String tag) async {
  final uid = SupabaseService.currentUser?.id;
  print('--- $tag ---');
  print('auth uid        = $uid');
  print('auth email      = ${SupabaseService.currentUser?.email}');
  print('is_anonymous    = ${SupabaseService.currentUser?.isAnonymous}');
  if (uid == null) return;
  final c = SupabaseService.client;
  try {
    print('profiles        = ${await c.from('profiles').select().eq('id', uid)}');
    print('meals           = ${await c.from('meals').select('id,meal_type,name,kcal').eq('user_id', uid).order('name')}');
    print('weight_logs     = ${await c.from('weight_logs').select('weight_kg').eq('user_id', uid)}');
    print('water_logs      = ${await c.from('water_logs').select('amount_ml').eq('user_id', uid)}');
  } catch (e) {
    print('read failed: $e');
  }
}

Future<void> typeAuthFields(
  WidgetTester tester, {
  required String email,
  required String password,
  String? confirm,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await settle(tester, ms: 300);
  await tester.enterText(fields.at(1), password);
  await settle(tester, ms: 300);
  if (confirm != null) {
    await tester.enterText(fields.at(2), confirm);
    await settle(tester, ms: 300);
  }
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester, ms: 600);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live mail — $_phase', (WidgetTester tester) async {
    // The deep-link phase must use REAL SharedPreferences: PKCE stores a code
    // verifier when the reset is requested, and only the same install can
    // redeem the code that comes back. Mock prefs live in memory and die with
    // the test process, which is exactly the process that has to hand over to
    // the OS here.
    final realPrefs = _phase == 'dlrequest';
    if (!realPrefs) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': _lang,
        'onboarding_completed': true,
      });
    }
    app.main();
    await settle(tester, ms: 9000);

    if (!realPrefs) {
      // Fresh anonymous account for every run.
      try {
        await SupabaseService.client.auth.signOut();
        await SupabaseService.client.auth.signInAnonymously();
      } catch (e) {
        print('session reset failed: $e');
      }
      await settle(tester, ms: 2500);
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    switch (_phase) {
      // =================================================================
      case 'register':
        appRouter.go('/onboarding/welcome');
        await settle(tester, ms: 2000);
        await tester.tap(find.text('Создать аккаунт').last);
        await settle(tester, ms: 2000);
        await typeAuthFields(tester,
            email: _addr, password: _pw, confirm: _pw);
        await tester.tap(find.text('Создать'));
        await settle(tester, ms: 9000);
        await shot('live_1_registered');
        print('registered $_addr');

        // Sign in before the link is opened.
        appRouter.go('/sign-in');
        await settle(tester, ms: 2500);
        await typeAuthFields(tester, email: _addr, password: _pw);
        await tester.tap(find.text('Войти'));
        await settle(tester, ms: 8000);
        await shot('live_2_signin_unconfirmed');
        print('unconfirmed sign-in, session uid = '
            '${SupabaseService.currentUser?.id} '
            'email=${SupabaseService.currentUser?.email}');

        // The address the app is showing back to the person.
        final err = find.byType(Text).evaluate().map((e) {
          final w = e.widget;
          return w is Text ? (w.data ?? '') : '';
        }).where((t) => t.contains('подтвержд') || t.contains('связь'));
        print('message on screen: ${err.toList()}');
        break;

      // =================================================================
      case 'attach':
        // 4. An address that already belongs to somebody else.
        if (_taken.isNotEmpty) {
          appRouter.push('/settings');
          await settle(tester, ms: 2500);
          await tester.tap(find.text('Аккаунт').last);
          await settle(tester, ms: 2000);
          await typeAuthFields(tester, email: _taken, password: 'Sal-taken-1234');
          await tester.tap(find.text('Привязать'));
          await settle(tester, ms: 9000);
          await shot('live_3_address_taken');
          print('after taken-address attempt: uid='
              '${SupabaseService.currentUser?.id} '
              'email=${SupabaseService.currentUser?.email} '
              'anonymous=${AuthService.isAnonymous}');
          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await settle(tester, ms: 1200);
          appRouter.go('/dashboard');
          await settle(tester, ms: 1500);
        }

        // 2. A real day of data on an anonymous account.
        await SupabaseService.upsertUser(
          name: 'Аида',
          gender: 'female',
          age: 31,
          heightCm: 168,
          weightKg: 77.1,
          goal: 'lose',
          dailyCalories: 2100,
          targetWeightKg: 70,
        );
        container.invalidate(profileProvider);
        await settle(tester, ms: 2000);
        container.read(userProvider.notifier)
          ..setName(name: 'Аида', lastName: '')
          ..setBody(height: 168, weight: 77.1)
          ..setAge(31)
          ..setCalorieNorm(2100);
        const uuid = Uuid();
        for (final (type, name, kcal) in const [
          (MealType.breakfast, 'Овсянка на молоке', 320),
          (MealType.lunch, 'Плов', 520),
          (MealType.dinner, 'Куриная грудка на гриле', 240),
        ]) {
          await container.read(mealsProvider.notifier).add(
                type,
                MealEntry(
                  id: uuid.v4(),
                  name: name,
                  grams: 250,
                  kcal: kcal,
                  protein: 20,
                  fat: 10,
                  carbs: 40,
                  source: 'manual',
                ),
              );
        }
        await SupabaseService.logWeight(77.1);
        container.invalidate(weightLogsProvider);
        for (var i = 0; i < 4; i++) {
          await container.read(waterProvider.notifier).add();
          await settle(tester, ms: 200);
        }
        await settle(tester, ms: 2500);
        await dumpRows('BEFORE the email is attached');
        await shot('live_4_before_attach');

        // Attach, through the sheet a person would use.
        appRouter.push('/settings');
        await settle(tester, ms: 2500);
        await tester.tap(find.text('Аккаунт').last);
        await settle(tester, ms: 2000);
        await typeAuthFields(tester, email: _addr, password: _pw);
        await tester.tap(find.text('Привязать'));
        await settle(tester, ms: 10000);
        await shot('live_5_attached');
        await dumpRows('AFTER the email is attached');
        print('pendingEmail = ${AuthService.pendingEmail}');
        break;

      // =================================================================
      case 'signin':
        appRouter.go('/sign-in');
        await settle(tester, ms: 2500);
        await typeAuthFields(tester, email: _addr, password: _pw);
        await tester.tap(find.text('Войти'));
        await settle(tester, ms: 10000);
        await shot('live_6_signed_in');
        await dumpRows('AFTER signing in');
        final u = container.read(userProvider);
        print('on screen: name="${u.name}" norm=${u.calorieNorm} '
            'weight=${u.weight} target=${u.targetWeight}');
        print('diary entries = '
            '${MealType.values.expand((t) => (container.read(mealsProvider).valueOrNull ?? const MealsState()).forType(t)).length}');
        print('weight logs   = '
            '${container.read(weightLogsProvider).valueOrNull?.length}');
        print('water ml      = '
            '${container.read(waterProvider).valueOrNull?.totalMl}');

        // 6. Out and back in.
        print('--- sign out ---');
        await AuthService.signOut();
        await settle(tester, ms: 4000);
        print('after signOut uid = ${SupabaseService.currentUser?.id} '
            '(anonymous=${AuthService.isAnonymous})');
        appRouter.go('/sign-in');
        await settle(tester, ms: 2500);
        await typeAuthFields(tester, email: _addr, password: _pw);
        await tester.tap(find.text('Войти'));
        await settle(tester, ms: 10000);
        await shot('live_7_signed_back_in');
        await dumpRows('AFTER signing back in');
        final u2 = container.read(userProvider);
        print('on screen: name="${u2.name}" norm=${u2.calorieNorm} '
            'weight=${u2.weight}');
        print('diary entries = '
            '${MealType.values.expand((t) => (container.read(mealsProvider).valueOrNull ?? const MealsState()).forType(t)).length}');
        print('weight logs   = '
            '${container.read(weightLogsProvider).valueOrNull?.length}');
        print('water ml      = '
            '${container.read(waterProvider).valueOrNull?.totalMl}');
        break;

      // =================================================================
      case 'recover':
        // Ask for the mail from the app itself, so gotrue attaches a PKCE
        // challenge and stores the verifier on this install.
        appRouter.go('/sign-in');
        await settle(tester, ms: 2500);
        await tester.tap(find.text('Забыли пароль?'));
        await settle(tester, ms: 2000);
        await tester.enterText(find.byType(TextField).first, _addr);
        await settle(tester, ms: 400);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester, ms: 600);
        await tester.tap(find.text('Отправить ссылку'));
        await settle(tester, ms: 8000);
        await shot('live_8_reset_sent');
        print('reset requested for $_addr');

        final link = await _linkFromInbox(_box, 'type=recovery');
        print('recovery link: $link');
        expect(link, isNotNull, reason: 'no recovery mail arrived');

        // Opening the link: the server confirms and redirects. This is the
        // same 303 a phone would follow.
        final location = await _httpGet(link!, follow: false);
        print('link redirects to: $location');
        final code = Uri.parse(location.replaceFirst('#', '?'))
            .queryParameters['code'];
        print('code in redirect: $code');
        expect(code, isNotNull,
            reason: 'the recovery link came back without a PKCE code');

        // Exactly what supabase_flutter does when iOS hands it the deep link.
        // The OS half is proved separately (simctl openurl -> "handle
        // deeplink uri"); this is the half that lives in the app.
        await SupabaseService.client.auth.getSessionFromUrl(
          Uri.parse('kg.salamat.app://login-callback?code=$code'),
        );
        await settle(tester, ms: 4000);
        print('recovery session uid = ${SupabaseService.currentUser?.id} '
            'email=${SupabaseService.currentUser?.email}');
        print('route now: '
            '${appRouter.routerDelegate.currentConfiguration.uri}');
        await shot('live_9_new_password');

        // Set the new password on the screen the link lands on.
        final pwFields = find.byType(TextField);
        await tester.enterText(pwFields.at(0), _newPw);
        await settle(tester, ms: 300);
        await tester.enterText(pwFields.at(1), _newPw);
        await settle(tester, ms: 300);
        // The keyboard's "done" on the second field already submits — the
        // field's onSubmit is the same handler as the button. Tap only if the
        // button is still there, or the finder fails on a screen that has
        // already moved on to "password changed".
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester, ms: 8000);
        final saveBtn = find.text('Сохранить пароль');
        if (saveBtn.evaluate().isNotEmpty) {
          await tester.tap(saveBtn, warnIfMissed: false);
          await settle(tester, ms: 8000);
        }
        await shot('live_10_password_changed');
        expect(find.text('Пароль изменён.'), findsOneWidget,
            reason: 'the screen never confirmed the change');

        // And in with the new one.
        await AuthService.signOut();
        await settle(tester, ms: 3000);
        appRouter.go('/sign-in');
        await settle(tester, ms: 2500);
        await typeAuthFields(tester, email: _addr, password: _newPw);
        await tester.tap(find.text('Войти'), warnIfMissed: false);
        await settle(tester, ms: 10000);
        await shot('live_11_signin_new_password');
        await dumpRows('AFTER signing in with the new password');
        final u3 = container.read(userProvider);
        print('on screen: name="${u3.name}" norm=${u3.calorieNorm}');
        print('diary entries = '
            '${MealType.values.expand((t) => (container.read(mealsProvider).valueOrNull ?? const MealsState()).forType(t)).length}');

        // The old password must no longer work.
        final old = await AuthService.signIn(address: _addr, password: _pw);
        print('sign-in with the OLD password -> $old');
        break;

      // =================================================================
      case 'attachrow':
        // The settings row must catch up the moment the address is submitted,
        // with no restart. Attaching keeps the same uid, which is exactly why
        // a screen keyed on the uid alone never noticed.
        appRouter.push('/settings');
        await settle(tester, ms: 2500);

        String rowValue() {
          final texts = find
              .byType(Text)
              .evaluate()
              .map((e) => (e.widget as Text).data ?? '')
              .toList();
          return texts.firstWhere(
            (t) =>
                t == 'Почта не привязана' ||
                (t.contains('@') && t.contains('mailinator')),
            orElse: () => '<not found>',
          );
        }

        print('row before: "${rowValue()}"');
        await shot('row_1_before');
        expect(rowValue(), 'Почта не привязана');

        await tester.tap(find.text('Аккаунт').last);
        await settle(tester, ms: 2000);
        await typeAuthFields(tester, email: _addr, password: _pw);
        await tester.tap(find.text('Привязать'));
        await settle(tester, ms: 12000);

        // The sheet is still up; the row behind it is visible in the frame.
        print('row after (sheet still open): "${rowValue()}"');
        await shot('row_2_after_sheet_open');

        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await settle(tester, ms: 2500);
        final after = rowValue();
        print('row after (sheet closed):     "$after"');
        print('session uid = ${SupabaseService.currentUser?.id} '
            'email=${SupabaseService.currentUser?.email} '
            'newEmail=${SupabaseService.currentUser?.newEmail}');
        await shot('row_3_after');
        expect(after, _addr,
            reason: 'the account row did not catch up with the attached address');
        break;

      // =================================================================
      case 'dlrequest':
        // Half one of the round trip, and the half that must happen inside the
        // app: asking for the mail, so gotrue stores the PKCE verifier on THIS
        // install. The host then opens the link the OS way and the app is
        // launched again by iOS, verifier still in place.
        appRouter.go('/forgot-password');
        await settle(tester, ms: 3000);
        await tester.enterText(find.byType(TextField).first, _addr);
        await settle(tester, ms: 400);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester, ms: 8000);
        await shot('dl_1_reset_requested');
        print('reset requested for $_addr');

        final dlLink = await _linkFromInbox(_box, 'type=recovery');
        print('RECOVERY_LINK=$dlLink');
        expect(dlLink, isNotNull, reason: 'no recovery mail arrived');
        break;

      default:
        fail('unknown PHASE "$_phase"');
    }
  });
}
