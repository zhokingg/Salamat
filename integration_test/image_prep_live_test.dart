// ignore_for_file: avoid_print
//
// Before/after for the upload-size fix, against the deployed function.
//
// Runs the SAME 3840x2160 photo through `recognize-food` twice: once as the
// camera would have handed it over, once through ImagePrepService. Reports the
// base64 payload size, the model's own input_tokens, and wall-clock time for
// each.
//
// The photo is fetched from a plain HTTP server on the host so it does not
// have to be bundled into the app:
//
//   cd <scratchpad> && python3 -m http.server 8799
//   fvm flutter test integration_test/image_prep_live_test.dart -d <udid>
//
// Nothing is stubbed. The calls are real, and a confident recognition would
// spend a real scan — which is why the test photo is a landscape: the model
// answers, the token count is real, and the confidence gate refuses it before
// `consume_scan` is reached, so the account's allowance is left alone.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'package:salamat/main.dart' as app;
import 'package:salamat/services/image_prep_service.dart';
import 'package:salamat/services/supabase_service.dart';

const String _photoUrl = 'http://127.0.0.1:8799/big.jpg';

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Calls the function with an explicit payload and returns whatever came back,
/// including the `_usage` block that a 422 carries in its details.
Future<Map<String, dynamic>> _call(List<int> bytes) async {
  final b64 = base64Encode(bytes);
  final sw = Stopwatch()..start();
  Map<String, dynamic> out;
  try {
    final res = await SupabaseService.client.functions.invoke(
      'recognize-food',
      body: {'imageBase64': b64, 'mediaType': 'image/jpeg'},
    );
    sw.stop();
    final d = res.data;
    out = d is Map<String, dynamic> ? d : <String, dynamic>{'raw': '$d'};
  } on FunctionException catch (e) {
    sw.stop();
    final d = e.details;
    out = d is Map<String, dynamic> ? d : <String, dynamic>{'raw': '$d'};
    out['_status'] = e.status;
  }
  out['_client_ms'] = sw.elapsedMilliseconds;
  out['_base64_chars'] = b64.length;
  out['_jpeg_bytes'] = bytes.length;
  out['_dims'] = _jpegDims(bytes);
  return out;
}

/// Width/height straight out of the JPEG's SOF marker, so the dimensions we
/// claim to upload are read from the bytes rather than assumed.
String _jpegDims(List<int> b) {
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    final len = (b[i + 2] << 8) | b[i + 3];
    // SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15
    if (marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC) {
      final h = (b[i + 5] << 8) | b[i + 6];
      final w = (b[i + 7] << 8) | b[i + 8];
      return '${w}x$h';
    }
    i += 2 + len;
  }
  return 'unknown';
}

void _report(String label, Map<String, dynamic> r) {
  final usage = r['_usage'];
  final meta = r['_meta'];
  print('--- $label');
  print('  jpeg bytes      : ${r['_jpeg_bytes']}');
  print('  jpeg dimensions : ${r['_dims']}');
  print('  base64 chars    : ${r['_base64_chars']}   <- request_bytes');
  print('  input_tokens    : ${usage is Map ? usage['input_tokens'] : null}');
  print('  output_tokens   : ${usage is Map ? usage['output_tokens'] : null}');
  print('  server duration : ${meta is Map ? meta['duration_ms'] : null} ms');
  print('  dims seen       : ${meta is Map ? '${meta['image_width']}x${meta['image_height']}' : 'n/a'}');
  print('  CLIENT wall time: ${r['_client_ms']} ms   <- send to response');
  print('  status/error    : ${r['_status'] ?? 200} ${r['error'] ?? ''}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('upload size before/after', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);
    print('signed in as ${SupabaseService.currentUser?.id}');

    // Pull the test photo onto the device.
    final dir = Directory.systemTemp.createTempSync('prep');
    final file = File('${dir.path}/big.jpg');
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(_photoUrl));
    final res = await req.close();
    await res.pipe(file.openWrite());
    client.close();
    final original = await file.length();
    print('photo on device: $original bytes');
    expect(original, greaterThan(1000000));

    print('\n=== BEFORE: the frame as the camera hands it over ===');
    _report('uncompressed', await _call(await file.readAsBytes()));

    print('\n=== the client-side preparation step ===');
    final prepared = await ImagePrepService.prepare(file);
    print('  $prepared');
    print('  shrink factor   : ${prepared.ratio.toStringAsFixed(1)}x');
    print('  prepare took    : ${prepared.elapsed.inMilliseconds} ms');

    print('\n=== AFTER: same photo, ImagePrepService applied ===');
    _report('compressed', await _call(prepared.bytes));
  });
}
