import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamat/main.dart';
import 'package:salamat/providers/bootstrap_provider.dart';

void main() {
  testWidgets('Salamat app boots', (WidgetTester tester) async {
    // Boot through the test seam: the real bootstrap initializes Supabase,
    // whose auth client installs a periodic refresh timer that outlives the
    // widget tree and fails the test with "A Timer is still pending".
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapRunnerProvider.overrideWithValue(() async {}),
        ],
        child: const SalamatApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
