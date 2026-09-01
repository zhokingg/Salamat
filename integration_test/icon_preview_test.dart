// Renders the three new icons beside three from the set, at the size a
// person actually sees them and blown up, so the drawing can be judged
// rather than imagined.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const int _shotPort = 8787;

const List<String> _newOnes = ['falafel', 'khachapuri', 'meat_french'];
const List<String> _reference = ['plov', 'dolma', 'beshbarmak'];

Future<void> settle(WidgetTester t, {int ms = 1200}) async {
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

Widget _row(List<String> names, double size) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final n in names)
          SvgPicture.asset('assets/dish_icons/$n.svg',
              width: size, height: size),
      ],
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new icons beside the set', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: const Color(0xFF0B0D12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _row(_newOnes, 104),
                _row(_reference, 104),
                _row(_newOnes, 56),
                _row(_reference, 56),
                _row(_newOnes, 32),
                _row(_reference, 32),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester, ms: 2500);
    await shot('newicons_preview');
  });
}
