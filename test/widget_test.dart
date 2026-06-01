import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamat/main.dart';

void main() {
  testWidgets('Salamat app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SalamatApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
