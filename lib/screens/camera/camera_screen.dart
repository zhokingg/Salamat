import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../manual_entry/manual_entry_sheet.dart';
import '../manual_entry/photo_limit_sheet.dart';
import '../onboarding/widgets.dart' show OnboardingPrimaryButton;
import '../../services/barcode_lookup_service.dart';
import '../../services/voice_entry_service.dart';
import '../../services/photo_recognition_service.dart';
import '../../theme/salamat_dark.dart';

/// Prototype camera canvas (`#07090C`), darker than `--bg` in light mode
/// and identical in both themes.
const Color _kCamBg = SalamatColorsDark.camBg;

/// Why recognition didn't yield a usable result. Drives the snackbar message
/// the user sees — generic "could not recognise" gets blamed on the AI,
/// network/server errors should make that distinction explicit.
enum _FailureKind { network, server, notRecognised }

/// What the camera screen is currently doing. One screen, two modes — the
/// prototype toggles between them rather than opening a separate scanner.
enum _CaptureMode { photo, barcode, voice }

class _Recognized {
  const _Recognized({
    required this.name,
    required this.confidence,
    required this.grams,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.fatPer100,
    required this.carbsPer100,
  });

  final String name;
  final int confidence;
  final int grams;
  final double kcalPer100;
  final double proteinPer100;
  final double fatPer100;
  final double carbsPer100;

  int get kcal => (kcalPer100 * grams / 100).round();
  double get protein => proteinPer100 * grams / 100;
  double get fat => fatPer100 * grams / 100;
  double get carbs => carbsPer100 * grams / 100;

  _Recognized withGrams(int g) => _Recognized(
        name: name,
        confidence: confidence,
        grams: g,
        kcalPer100: kcalPer100,
        proteinPer100: proteinPer100,
        fatPer100: fatPer100,
        carbsPer100: carbsPer100,
      );
}

const _Recognized _kMockResult = _Recognized(
  name: 'Плов узбекский',
  confidence: 87,
  grams: 200,
  kcalPer100: 245,
  proteinPer100: 8,
  fatPer100: 11,
  carbsPer100: 29,
);

_Recognized? _recognizedFromJson(Map<String, dynamic> j) {
  try {
    final name = j['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;
    final c = (j['confidence'] as num?)?.toDouble() ?? 0.0;
    final k100 = (j['calories_per_100g'] as num?)?.toDouble() ?? 0.0;
    final p100 = (j['protein_per_100g'] as num?)?.toDouble() ?? 0.0;
    final c100 = (j['carbs_per_100g'] as num?)?.toDouble() ?? 0.0;
    final f100 = (j['fat_per_100g'] as num?)?.toDouble() ?? 0.0;
    final g = (j['portion_g'] as num?)?.toInt() ?? 200;
    return _Recognized(
      name: name,
      confidence: (c * 100).round().clamp(0, 100),
      grams: g.clamp(50, 2000),
      kcalPer100: k100,
      proteinPer100: p100,
      fatPer100: f100,
      carbsPer100: c100,
    );
  } catch (_) {
    return null;
  }
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _initialized = false;
  bool _unavailable = false;

  /// Dish confirmed by the service, held for one beat so the viewfinder can
  /// show the prototype's "detected" state before the sheet slides up.
  _Recognized? _detected;
  bool _outOfPhotos = false;

  _CaptureMode _mode = _CaptureMode.photo;

  /// Barcode scanning owns its own camera session; the photo controller stays
  /// untouched so switching back does not re-initialise it.
  MobileScannerController? _scanner;

  /// Guards against the detector firing repeatedly on the same code while a
  /// lookup is already in flight.
  bool _barcodeBusy = false;
  String? _lastBarcode;

  /// The transcript, kept in a controller so the user can correct it before
  /// sending: speech recognition mishears more often than people expect.
  final TextEditingController _voiceCtrl = TextEditingController();
  bool _voiceListening = false;
  bool _voiceParsing = false;
  bool _processing = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _voiceCtrl.addListener(_onVoiceTextChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _controller?.dispose();
    _scanner?.dispose();
    _voiceCtrl.removeListener(_onVoiceTextChanged);
    _voiceCtrl.dispose();
    VoiceEntryService.cancel();
    super.dispose();
  }

  /// The transcript can change two ways: dictation (which already rebuilds via
  /// setState) and the user typing a correction (which does not). Without this
  /// listener the send button stayed disabled after a manual edit, because
  /// `_VoiceView` reads `controller.text` and nothing told it to rebuild.
  void _onVoiceTextChanged() {
    if (mounted) setState(() {});
  }

  void _setMode(_CaptureMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _lastBarcode = null;
      _barcodeBusy = false;
      if (mode != _CaptureMode.voice && _voiceListening) {
        _voiceListening = false;
        VoiceEntryService.cancel();
      }
      if (mode == _CaptureMode.barcode) {
        // Barcode scanning costs nothing, so it stays available even when the
        // photo allowance is spent.
        _scanner ??= MobileScannerController(
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
          detectionSpeed: DetectionSpeed.normal,
        );
      }
    });
  }

  /// One detection from the scanner. Everything here is free: no model call,
  /// no `consume_scan`, so the photo allowance is untouched.
  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_barcodeBusy || !mounted) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final code = raw.trim();
    // The detector fires many times a second on the same label.
    if (code == _lastBarcode) return;

    setState(() {
      _barcodeBusy = true;
      _lastBarcode = code;
    });

    final result = await BarcodeLookupService.lookup(
      barcode: code,
      lang: Localizations.localeOf(context).languageCode,
    );
    if (!mounted) return;
    setState(() => _barcodeBusy = false);

    if (result.isFound) {
      await _showResultSheet(_fromProduct(result.product!));
      // Allow the same product to be scanned again afterwards.
      if (mounted) setState(() => _lastBarcode = null);
      return;
    }
    await _showBarcodeMiss(result.miss!);
    if (mounted) setState(() => _lastBarcode = null);
  }

  /// Turns an Open Food Facts product into the same value the photo path
  /// produces, so both feed one confirmation sheet.
  _Recognized _fromProduct(BarcodeProduct p) => _Recognized(
        name: p.displayName,
        // A label is not a guess; there is nothing to be unsure about.
        confidence: 100,
        grams: (p.servingG ?? 100).clamp(1, 2000),
        kcalPer100: p.kcalPer100,
        proteinPer100: p.proteinPer100,
        fatPer100: p.fatPer100,
        carbsPer100: p.carbsPer100,
      );

  Future<void> _init() async {
    try {
      // The server owns the allowance; this read only decides whether to
      // open the camera at all. A null answer means "unknown" — open it and
      // let the server refuse, rather than locking someone out offline.
      await ref.read(subscriptionProvider.notifier).refreshFromServer();
      if (!mounted) return;
      if (!ref.read(subscriptionProvider).canTakePhoto) {
        setState(() => _outOfPhotos = true);
        return;
      }

      if (!await _ensureCameraPermission()) return;
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _unavailable = true);
        return;
      }
      final controller = CameraController(
        cams.first,
        ResolutionPreset.ultraHigh,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
    } catch (_) {
      if (mounted) setState(() => _unavailable = true);
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (!mounted) return false;
      await _showPermissionDialog();
      return false;
    }

    status = await Permission.camera.request();
    if (!mounted) return false;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showPermissionDialog();
    } else if (mounted) {
      context.pop();
    }
    return false;
  }

  Future<void> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          loc.cameraPermissionTitle,
          style: SalamatDarkType.style(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: sc.text,
          ),
        ),
        content: Text(
          loc.cameraPermissionBody,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: sc.text2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: Text(
              loc.cameraDialogCancel,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sc.text2,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text(
              loc.cameraOpenSettings,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: sc.primaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shutter() async {
    if (_processing) return;
    if (_controller == null || !_initialized) return;
    setState(() => _processing = true);

    if (!ref.read(subscriptionProvider).canTakePhoto) {
      setState(() {
        _processing = false;
        _outOfPhotos = true;
      });
      return;
    }

    try {
      final xfile = await _controller!.takePicture();

      // Three failure modes are distinguished here:
      //   1. SocketException / connection refused → "No connection"
      //   2. recognizeFood returns null (server/AI error) → "Server unavailable"
      //   3. low confidence or null fields → "Could not recognise the dish"
      // Quota is consumed ONLY on a confident, valid result — the free
      // allowance is three scans for the lifetime of the account, so losing
      // one to a network blip is a terrible first experience.
      Map<String, dynamic>? json;
      _FailureKind? failure;
      var quotaExhausted = false;
      try {
        json = await PhotoRecognitionService.recognizeFood(File(xfile.path));
      } on SocketException {
        failure = _FailureKind.network;
      } on HttpException {
        failure = _FailureKind.network;
      } on LowConfidenceException {
        // Server says the answer is not good enough to show. No scan was spent.
        failure = _FailureKind.notRecognised;
      } on QuotaExhaustedException {
        // Not an outage: the allowance is gone and there is a screen for that.
        quotaExhausted = true;
      } catch (e) {
        if (kDebugMode) debugPrint('recognizeFood unexpected error: $e');
        failure = _FailureKind.server;
      }

      if (!mounted) return;
      setState(() => _processing = false);

      if (quotaExhausted) {
        // Re-read the authoritative counts, then offer manual entry first and
        // the subscription second — never a bare error.
        await ref.read(subscriptionProvider.notifier).refreshFromServer();
        if (!mounted) return;
        setState(() => _outOfPhotos = true);
        await showPhotoLimitSheet(context);
        return;
      }

      if (failure != null) {
        _showFailureSnack(failure);
        return;
      }
      if (json == null) {
        // Service swallowed an error and returned null — treat as server-side.
        _showFailureSnack(_FailureKind.server);
        return;
      }
      // No confidence check here any more: `recognize-food` applies the
      // threshold and answers 422 when it is not met, which arrives as
      // LowConfidenceException above. A second copy of the number here is what
      // let the two sides disagree and charge the user for a failure.
      final r = _recognizedFromJson(json);
      if (r == null) {
        _showFailureSnack(_FailureKind.notRecognised);
        return;
      }

      // The scan was already consumed server-side, atomically, inside
      // `recognize-food`. Adopt the counts it returned so the camera button
      // updates without another round trip.
      final scan = json['_scan'];
      if (mounted && scan is Map && scan['used'] is num) {
        ref.read(subscriptionProvider.notifier).applyServerCounts(
              used: (scan['used'] as num).toInt(),
            );
      }

      if (!mounted) return;
      // Prototype `camDone`: the frame turns neon and the dish is labelled
      // before the confirmation sheet appears.
      setState(() {
        _processing = false;
        _detected = r;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _showResultSheet(r);
      if (mounted) setState(() => _detected = null);

      // The result comes FIRST, always. Only once the user has seen and
      // dismissed what they scanned does the app mention a subscription —
      // never a cold paywall in front of the thing they asked for.
      if (mounted && ref.read(subscriptionProvider).exhausted) {
        await _showLastScanOffer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      if (kDebugMode) debugPrint('shutter error: $e');
      _showFailureSnack(_FailureKind.server);
    }
  }

  /// Confirmation for a spoken phrase: one row per dish, so "shawarma and a
  /// coke" is two editable lines rather than one merged blob.
  Future<void> _showVoiceItems(List<VoiceItem> items) async {
    final loc = AppLocalizations.of(context)!;
    var slot = _defaultSlotForNow();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sc.sheet,
      barrierColor: sc.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SalamatDarkDims.rSheetTop),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.voiceItemsTitle,
                  style: SalamatDarkType.style(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: sc.text)),
              const SizedBox(height: SalamatDarkDims.gap14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: SalamatDarkDims.gap8),
                  itemBuilder: (_, i) => _VoiceItemRow(item: items[i]),
                ),
              ),
              const SizedBox(height: SalamatDarkDims.gap14),
              Row(
                children: [
                  for (final t in MealType.values) ...[
                    if (t != MealType.values.first)
                      const SizedBox(width: SalamatDarkDims.gap6),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setSheet(() => slot = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: slot == t ? sc.primarySoft : sc.surface2,
                            borderRadius: BorderRadius.circular(
                                SalamatDarkDims.rPill),
                          ),
                          child: Text(
                            t.label(loc),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SalamatDarkType.micro.copyWith(
                              color: slot == t ? sc.primary : sc.text3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              SizedBox(
                width: double.infinity,
                child: OnboardingPrimaryButton(
                  label: loc.voiceAddAll(items.length),
                  enabled: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _saveVoiceItems(items, slot);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MealType _defaultSlotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 22) return MealType.dinner;
    return MealType.snack;
  }

  void _saveVoiceItems(List<VoiceItem> items, MealType slot) {
    final loc = AppLocalizations.of(context)!;
    final notifier = ref.read(mealsProvider.notifier);
    for (final it in items) {
      notifier.add(
        slot,
        MealEntry(
          id: const Uuid().v4(),
          name: it.name,
          grams: it.grams.toDouble(),
          kcal: it.kcal,
          // Unreconcilable macros stay zero, which every screen renders as a
          // dash rather than as measured zeros.
          protein: it.macrosKnown ? it.protein : 0,
          fat: it.macrosKnown ? it.fat : 0,
          carbs: it.macrosKnown ? it.carbs : 0,
          source: 'voice',
        ),
      );
    }
    final messenger = ScaffoldMessenger.of(context);
    if (context.canPop()) context.pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: sc.primaryInk,
        behavior: SnackBarBehavior.floating,
        content: Text(
          loc.voiceAddAll(items.length),
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sc.primary,
          ),
        ),
      ),
    );
  }

  /// Starts or stops dictation.
  ///
  /// The microphone is requested HERE, on first use, rather than at app start:
  /// `VoiceEntryService.prepare` is what raises the OS prompt, and it is only
  /// called from this tap.
  Future<void> _toggleVoice() async {
    if (_voiceListening) {
      await VoiceEntryService.stop();
      if (mounted) setState(() => _voiceListening = false);
      return;
    }
    _voiceCtrl.clear();
    final failure = await VoiceEntryService.listen(
      lang: Localizations.localeOf(context).languageCode,
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceCtrl.text = text;
          _voiceCtrl.selection =
              TextSelection.collapsed(offset: _voiceCtrl.text.length);
          if (isFinal) _voiceListening = false;
        });
      },
    );
    if (!mounted) return;
    if (failure != null) {
      await _showVoiceFailure(failure);
      return;
    }
    setState(() => _voiceListening = true);
  }

  /// Sends the (possibly corrected) transcript for parsing.
  Future<void> _sendVoice() async {
    final text = _voiceCtrl.text.trim();
    if (text.isEmpty || _voiceParsing) return;
    // Read the locale before any await; the context may not survive one.
    final lang = Localizations.localeOf(context).languageCode;
    if (_voiceListening) {
      await VoiceEntryService.stop();
      if (mounted) setState(() => _voiceListening = false);
    }
    setState(() => _voiceParsing = true);
    final (items, failure) = await VoiceEntryService.parse(
      text: text,
      lang: lang,
    );
    if (!mounted) return;
    setState(() => _voiceParsing = false);
    if (failure != null || items == null) {
      await _showVoiceFailure(failure ?? VoiceFailure.notUnderstood);
      return;
    }
    await _showVoiceItems(items);
  }

  /// Three distinct outcomes, three different fixes — never one generic error.
  Future<void> _showVoiceFailure(VoiceFailure failure) async {
    final loc = AppLocalizations.of(context)!;
    final (title, body, offerManual) = switch (failure) {
      VoiceFailure.micDenied =>
        (loc.voiceMicDeniedTitle, loc.voiceMicDeniedBody, false),
      VoiceFailure.unavailable =>
        (loc.voiceUnavailableTitle, loc.voiceUnavailableBody, true),
      VoiceFailure.notUnderstood =>
        (loc.voiceNotUnderstoodTitle, loc.voiceNotUnderstoodBody, true),
      VoiceFailure.offline =>
        (loc.voiceOfflineTitle, loc.voiceOfflineBody, false),
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sc.sheet,
      barrierColor: sc.scrim,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SalamatDarkDims.rSheetTop),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: SalamatDarkType.style(
                    fontSize: 20, fontWeight: FontWeight.w800, color: sc.text)),
            const SizedBox(height: SalamatDarkDims.gap10),
            Text(body,
                style: SalamatDarkType.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    color: sc.text2)),
            const SizedBox(height: SalamatDarkDims.gap20),
            SizedBox(
              width: double.infinity,
              child: OnboardingPrimaryButton(
                label: offerManual ? loc.manualAddButton : loc.retryButton,
                enabled: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (offerManual) showManualEntrySheet(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Honest end states for a barcode that produced no product.
  ///
  /// None of these is an error dialog: "not in the database" is an ordinary
  /// outcome for a shop in Bishkek, and the useful next step is manual entry,
  /// so that is the primary button. Only a connection failure offers a retry.
  Future<void> _showBarcodeMiss(BarcodeMiss miss) async {
    final loc = AppLocalizations.of(context)!;
    final (title, body, offerRetry) = switch (miss) {
      BarcodeMiss.notInDatabase =>
        (loc.barcodeNotFoundTitle, loc.barcodeNotFoundBody, false),
      BarcodeMiss.noNutrition =>
        (loc.barcodeNoNutritionTitle, loc.barcodeNoNutritionBody, false),
      BarcodeMiss.offline =>
        (loc.barcodeOfflineTitle, loc.barcodeOfflineBody, true),
      BarcodeMiss.invalidCode =>
        (loc.barcodeInvalidTitle, loc.barcodeInvalidBody, false),
    };

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sc.sheet,
      barrierColor: sc.scrim,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SalamatDarkDims.rSheetTop),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: SalamatDarkType.style(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: sc.text,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            Text(
              body,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: sc.text2,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),
            SizedBox(
              width: double.infinity,
              child: OnboardingPrimaryButton(
                label: offerRetry ? loc.retryButton : loc.manualAddButton,
                enabled: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (!offerRetry) showManualEntrySheet(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown after the result of the third and final free scan.
  Future<void> _showLastScanOffer() async {
    final loc = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sc.sheet,
      barrierColor: sc.scrim,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SalamatDarkDims.rSheetTop),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.scansExhaustedTitle,
              style: SalamatDarkType.style(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: sc.text,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            Text(
              loc.scansExhaustedBody,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: sc.text2,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),
            SizedBox(
              width: double.infinity,
              child: OnboardingPrimaryButton(
                label: loc.limitGoPro,
                enabled: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/paywall');
                },
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(SalamatDarkDims.gap6),
                  child: Text(
                    loc.scansLater,
                    style: SalamatDarkType.captionL
                        .copyWith(color: sc.text3, height: null),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResultSheet(_Recognized r) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sc.sheet,
      barrierColor: sc.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      // Prototype: `border-radius: 32px 32px 0 0`, `max-height: 60%`.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SalamatDarkDims.rSheetTop),
        ),
      ),
      builder: (sheetCtx) => _ResultSheet(
        initial: r,
        onSave: _onSave,
        onRetake: () => Navigator.of(sheetCtx).pop(),
      ),
    );
  }

  void _showFailureSnack(_FailureKind kind) {
    final loc = AppLocalizations.of(context)!;
    final text = switch (kind) {
      _FailureKind.network => loc.cameraErrorNoNetwork,
      _FailureKind.server => loc.cameraErrorServer,
      _FailureKind.notRecognised => loc.cameraNotRecognized,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: sc.warn,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          text,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sc.surface,
          ),
        ),
      ),
    );
  }

  void _onSave(_Recognized r, MealType slot) {
    final loc = AppLocalizations.of(context)!;
    ref.read(mealsProvider.notifier).add(
          slot,
          MealEntry(
            // Which path produced this entry, so the meal card does not claim
            // a barcode scan was recognised from a photo.
            source: _mode == _CaptureMode.barcode ? 'barcode' : 'photo',
            id: const Uuid().v4(),
            name: r.name,
            grams: r.grams.toDouble(),
            kcal: r.kcal,
            protein: r.protein,
            fat: r.fat,
            carbs: r.carbs,
          ),
        );

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (mounted && context.canPop()) context.pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: sc.primaryInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.cameraAddedSnack,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sc.surface,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final sub = ref.watch(subscriptionProvider);
    return Scaffold(
      backgroundColor: _kCamBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leadingWidth: 38 + SalamatDarkDims.screenPadH,
        leading: Padding(
          padding: const EdgeInsets.only(left: SalamatDarkDims.screenPadH),
          child: _GlassButton(
            icon: PhosphorIcons.x(),
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/dashboard'),
            semanticLabel: loc.cameraDialogCancel,
          ),
        ),
        title: Text(
          switch (_mode) {
            _CaptureMode.photo => loc.cameraTitlePhoto,
            _CaptureMode.barcode => loc.cameraTitleBarcode,
            _CaptureMode.voice => loc.cameraTitleVoice,
          }
              .toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SalamatDarkType.captionXs.copyWith(
            letterSpacing: 0.1 * 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        // Left-aligned rather than centred: with a centred title Flutter hands
        // it the full toolbar width and the Russian strings ran underneath the
        // scans chip. Left-aligned, the AppBar constrains it between the close
        // button and the actions, so it ellipsizes instead of overlapping.
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: SalamatDarkDims.screenPadH,
              top: 8,
              bottom: 8,
            ),
            child: _PhotoCounter(
              text: sub.isPro
                  ? loc.scansUnlimited
                  : loc.scansLeftOf(sub.scansLeft, sub.allowance),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // Barcode mode is never gated on the photo allowance: it costs no
            // model call, so an out-of-scans user can still scan labels.
            child: _mode == _CaptureMode.voice
                ? _VoiceView(
                    controller: _voiceCtrl,
                    listening: _voiceListening,
                    parsing: _voiceParsing,
                    onMic: _toggleVoice,
                    onSend: _sendVoice,
                  )
                : _mode == _CaptureMode.barcode
                ? _BarcodeView(
                    controller: _scanner,
                    busy: _barcodeBusy,
                    onDetect: _onBarcode,
                  )
                : _outOfPhotos
          ? _OutOfPhotosStub(onUpgrade: () => context.push('/paywall'))
          : _unavailable
              ? _UnavailableStub(
                  onSimulate: () => _showResultSheet(_kMockResult),
                )
              : !_initialized
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(child: CameraPreview(_controller!)),
                        Positioned.fill(
                          child: _ViewfinderFrame(
                            scanning: _processing,
                            detected: _detected != null,
                          ),
                        ),
                        if (_detected != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _DetectionLabel(result: _detected!),
                            ),
                          ),
                        if (_detected == null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: FadeTransition(
                                  opacity: _pulse,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sc.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_detected == null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 200,
                            child: _processing
                                ? _LabelOverlay(text: loc.cameraLoading)
                                : _LabelOverlay(
                                    text: loc.cameraHint,
                                    dim: true,
                                  ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ShutterBar(
                            processing: _processing,
                            onTap: _shutter,
                          ),
                        ),
                      ],
                    ),
          ),
          Positioned(
            left: 0,
            right: 0,
            // Only photo mode has a shutter bar to clear; barcode and voice
            // sit lower. This used to test for barcode alone, which put the
            // toggle straight on top of the voice screen's send button.
            bottom: _mode == _CaptureMode.photo ? 132 : 44,
            child: Center(
              child: _ModeToggle(mode: _mode, onChanged: _setMode),
            ),
          ),
        ],
      ),
    );
  }
}

/// One parsed dish in the voice confirmation sheet.
class _VoiceItemRow extends StatelessWidget {
  const _VoiceItemRow({required this.item});

  final VoiceItem item;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final macros = item.macrosKnown
        ? loc.mealsMacros(
            item.protein.round(), item.fat.round(), item.carbs.round())
        : loc.mealsMacrosUnknown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SalamatDarkType.bodyL.copyWith(color: sc.text),
                ),
                const SizedBox(height: SalamatDarkDims.gap2),
                Text(
                  '${loc.detailServing(item.grams)} · $macros',
                  style: SalamatDarkType.micro.copyWith(color: sc.text3),
                ),
              ],
            ),
          ),
          const SizedBox(width: SalamatDarkDims.gap8),
          Text(
            loc.dashboardKcalWithValue(item.kcal),
            style: SalamatDarkType.bodyL.copyWith(color: sc.primary),
          ),
        ],
      ),
    );
  }
}

/// Voice mode: dictate, correct the transcript, send.
class _VoiceView extends StatelessWidget {
  const _VoiceView({
    required this.controller,
    required this.listening,
    required this.parsing,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool listening;
  final bool parsing;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final hasText = controller.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: parsing ? null : onMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? sc.primary : sc.surface2,
                ),
                child: PhosphorIcon(
                  listening
                      ? PhosphorIcons.stop(PhosphorIconsStyle.fill)
                      : PhosphorIcons.microphone(PhosphorIconsStyle.fill),
                  size: 34,
                  color: listening ? sc.onPrimary : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap16),
            Text(
              parsing
                  ? loc.voiceParsing
                  : listening
                      ? loc.voiceListening
                      : loc.voiceTapToSpeak,
              textAlign: TextAlign.center,
              style: SalamatDarkType.bodyL.copyWith(color: Colors.white),
            ),
            const SizedBox(height: SalamatDarkDims.gap8),
            Text(
              hasText ? loc.voiceCheckText : loc.voiceExample,
              textAlign: TextAlign.center,
              style: SalamatDarkType.micro
                  .copyWith(color: Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),
            // The transcript is editable on purpose: recognition mishears, and
            // a wrong word here becomes a wrong dish in the diary.
            TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              enabled: !parsing,
              textInputAction: TextInputAction.done,
              style: SalamatDarkType.bodyL.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: loc.voiceHint,
                hintStyle: SalamatDarkType.micro
                    .copyWith(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(SalamatDarkDims.rTile),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap12),
            SizedBox(
              width: double.infinity,
              child: OnboardingPrimaryButton(
                label: loc.voiceSend,
                enabled: hasText && !parsing,
                onTap: onSend,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            Text(
              loc.voiceFreeNote,
              style: SalamatDarkType.micro
                  .copyWith(color: Colors.white.withValues(alpha: 0.45)),
            ),
            // Leaves room for the mode toggle floating below.
            const SizedBox(height: 112),
          ],
        ),
      ),
    );
  }
}

/// Photo / barcode / voice switch, floating over the preview.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _CaptureMode mode;
  final ValueChanged<_CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(loc.barcodeModePhoto, _CaptureMode.photo),
          _segment(loc.barcodeModeCode, _CaptureMode.barcode),
          _segment(loc.voiceModeVoice, _CaptureMode.voice),
        ],
      ),
    );
  }

  Widget _segment(String label, _CaptureMode value) {
    final selected = mode == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
        ),
        child: Text(
          label,
          style: SalamatDarkType.style(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The barcode viewfinder.
class _BarcodeView extends StatelessWidget {
  const _BarcodeView({
    required this.controller,
    required this.busy,
    required this.onDetect,
  });

  final MobileScannerController? controller;
  final bool busy;
  final void Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: c,
            onDetect: onDetect,
            // The package renders its own English message when there is no
            // camera. Replaced with ours so the Russian build never shows an
            // untranslated string.
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  kDebugMode
                      ? loc.cameraUnavailable
                      : loc.cameraUnavailableDevice,
                  textAlign: TextAlign.center,
                  style: SalamatDarkType.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: _ViewfinderFrame(scanning: busy)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 200,
          child: _LabelOverlay(
            text: busy ? loc.barcodeSearching : loc.barcodeHint,
            dim: !busy,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 160,
          child: IgnorePointer(
            child: Center(
              child: Text(
                loc.barcodeFreeNote,
                style: SalamatDarkType.micro.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoCounter extends StatelessWidget {
  const _PhotoCounter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: SalamatDarkType.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _LabelOverlay extends StatelessWidget {
  const _LabelOverlay({required this.text, this.dim = false});
  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: SalamatDarkType.style(
          fontSize: dim ? 11 : 13,
          fontWeight: dim ? FontWeight.w700 : FontWeight.w600,
          color: dim
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white,
          letterSpacing: dim ? 2.0 : 0.2,
        ),
      ),
    );
  }
}

class _ShutterBar extends StatelessWidget {
  const _ShutterBar({required this.processing, required this.onTap});

  final bool processing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCamBg,
      padding: const EdgeInsets.only(top: 22, bottom: 44),
      child: Center(
        child: GestureDetector(
          onTap: processing ? null : onTap,
          child: Container(
            width: SalamatDarkDims.shutterSize,
            height: SalamatDarkDims.shutterSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              // Prototype: `box-shadow: 0 0 0 6px rgba(255,255,255,0.16)`.
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.16),
                  spreadRadius: 6,
                ),
              ],
            ),
            child: processing
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: _kCamBg,
                      strokeWidth: 3,
                    ),
                  )
                : PhosphorIcon(
                    PhosphorIcons.camera(),
                    size: 29,
                    color: _kCamBg,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Viewfinder frame. Prototype: `inset: 112px 34px 176px`, radius 28,
/// `border: 1.5px solid rgba(255,255,255,0.22)`.
class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame({required this.scanning, this.detected = false});

  /// While recognising, the prototype swaps the border to `--primary` over a
  /// faint green wash (`camScan`).
  final bool scanning;

  /// After a confident result (`camDone`) the wash deepens to `camBoxFill`.
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = scanning || detected;
    return Padding(
      padding: SalamatDarkDims.viewfinderInset,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: SalamatDarkDims.ease,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rViewfinder),
          color: detected
              ? SalamatColorsDark.camBoxFill
              : scanning
                  ? SalamatColorsDark.camScanFill
                  : null,
          border: Border.all(
            color:
                active ? c.primary : Colors.white.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Detection label from the prototype's `camDone`: a `--primary` chip with
/// `#04140A` ink, radius 8, pinned to the top-left of the viewfinder frame.
///
/// The prototype positions one chip per detected region. The recognition
/// edge function returns no bounding boxes — only name, macros and
/// confidence — so the chip is anchored to the frame itself rather than to
/// invented coordinates, and exactly one is drawn.
class _DetectionLabel extends StatelessWidget {
  const _DetectionLabel({required this.result});

  final _Recognized result;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: SalamatDarkDims.viewfinderInset,
      child: Align(
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: const Offset(9, -12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rBar),
            ),
            child: Text(
              loc.cameraDetectedBoxLabel(result.name, result.confidence),
              style: SalamatDarkType.eyebrowS.copyWith(
                color: c.onPrimary,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scaleXY(
            begin: 0.9,
            end: 1,
            duration: 240.ms,
            curve: SalamatDarkDims.ease,
          ),
    );
  }
}

/// Glass icon button used on the camera chrome:
/// `rgba(255,255,255,0.14)` on a 38x38 box, radius 13.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: SalamatDarkDims.iconBtn38,
          height: SalamatDarkDims.iconBtn38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SalamatColorsDark.camGlassStrong,
            borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon38),
          ),
          child: PhosphorIcon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

/// Shared empty/blocked state for the camera surface: a glyph in a translucent
/// bubble, a headline, an optional supporting line, then a neon primary action
/// and an optional quiet secondary one. Follows the prototype's empty-state
/// composition (icon bubble, 21/600 title, 13.5 muted body, radius-18 CTA)
/// against the camera's own `#07090C` canvas.
class _CameraStateStub extends StatelessWidget {
  const _CameraStateStub({
    required this.icon,
    required this.title,
    this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final PhosphorIconData icon;
  final String title;
  final String? body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding
      (
        padding: const EdgeInsets.symmetric(
          horizontal: SalamatDarkDims.gap24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SalamatColorsDark.camGlass,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
                ),
                child: PhosphorIcon(icon, size: 28, color: c.primary),
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SalamatDarkType.h3.copyWith(color: Colors.white),
            ),
            if (body != null) ...[
              const SizedBox(height: SalamatDarkDims.gap8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: SalamatDarkType.captionL.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
            ],
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: SalamatDarkDims.gap24),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPrimary,
                child: Container(
                  padding: const EdgeInsets.all(SalamatDarkDims.ctaPad),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rButton),
                  ),
                  child: Text(
                    primaryLabel!,
                    style: SalamatDarkType.btn.copyWith(color: c.onPrimary),
                  ),
                ),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: SalamatDarkDims.gap10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSecondary,
                child: Container(
                  padding: const EdgeInsets.all(SalamatDarkDims.ctaPad),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SalamatColorsDark.camGlass,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rButton),
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: SalamatDarkType.btn.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// No usable camera on the device. In debug the mock-recognition affordance
/// stays available so the confirm sheet can be exercised without hardware.
class _UnavailableStub extends StatelessWidget {
  const _UnavailableStub({required this.onSimulate});

  final Future<void> Function() onSimulate;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _CameraStateStub(
      icon: PhosphorIcons.warning(),
      title: kDebugMode ? loc.cameraUnavailable : loc.cameraUnavailableDevice,
      primaryLabel: kDebugMode ? loc.cameraSimulate : null,
      onPrimary: kDebugMode ? onSimulate : null,
    );
  }
}

/// Daily free scan spent. Manual logging stays free, so it leads; Pro second.
class _OutOfPhotosStub extends StatelessWidget {
  const _OutOfPhotosStub({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _CameraStateStub(
      icon: PhosphorIcons.crownSimple(),
      title: loc.cameraOutOfPhotos,
      body: loc.paywallSubtitle,
      primaryLabel: loc.cameraTryPro,
      onPrimary: onUpgrade,
      secondaryLabel: loc.manualAddButton,
      onSecondary: () => showManualEntrySheet(context),
    );
  }
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({
    required this.initial,
    required this.onSave,
    required this.onRetake,
  });

  final _Recognized initial;
  final void Function(_Recognized, MealType) onSave;
  final VoidCallback onRetake;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late _Recognized _r;

  /// Meal slot the dish lands in. Defaults from the clock rather than the old
  /// hardcoded lunch: the prototype puts the choice in the user's hands.
  late MealType _slot;

  @override
  void initState() {
    super.initState();
    _r = widget.initial;
    _slot = _slotForNow();
  }

  static MealType _slotForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 22) return MealType.dinner;
    return MealType.snack;
  }

  void _adjust(int delta) {
    final next = (_r.grams + delta).clamp(50, 2000);
    setState(() => _r = _r.withGrams(next));
  }

  String _slotLabel(AppLocalizations loc, MealType t) => switch (t) {
        MealType.breakfast => loc.mealBreakfast,
        MealType.lunch => loc.mealLunch,
        MealType.dinner => loc.mealDinner,
        MealType.snack => loc.mealSnack,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: SalamatDarkDims.gap16),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line2,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rPill),
                  ),
                ),
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              // eyebrow + title, running total on the right
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.cameraDetectedOne.toUpperCase(),
                          style: SalamatDarkType.eyebrow.copyWith(
                            color: c.primaryInk,
                            letterSpacing: 0.1 * 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          loc.cameraConfirmTitle,
                          style: SalamatDarkType.h3.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap12),
                  Text(
                    '${_r.kcal}',
                    style: SalamatDarkType.h1.copyWith(
                      color: c.text,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              // detected row
              Container(
                padding: const EdgeInsets.all(SalamatDarkDims.gap12),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius:
                      BorderRadius.circular(SalamatDarkDims.rButton),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius:
                            BorderRadius.circular(SalamatDarkDims.rCheck),
                      ),
                      child: PhosphorIcon(
                        PhosphorIcons.check(),
                        size: 12,
                        color: c.onPrimary,
                      ),
                    ),
                    const SizedBox(width: SalamatDarkDims.gap12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                SalamatDarkType.bodyM.copyWith(color: c.text),
                          ),
                          const SizedBox(height: SalamatDarkDims.gap2),
                          Text(
                            '${loc.cameraConfidence(_r.confidence)} · '
                            '${loc.cameraKcalPerPortion(_r.grams)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SalamatDarkType.micro
                                .copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SalamatDarkDims.gap8),
                    _StepBtn(
                      icon: PhosphorIcons.minus(),
                      onTap: () => _adjust(-50),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text(
                        loc.gramsSuffix(_r.grams),
                        textAlign: TextAlign.center,
                        style: SalamatDarkType.captionS.copyWith(
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    _StepBtn(
                      icon: PhosphorIcons.plus(),
                      onTap: () => _adjust(50),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              // macros, as three compact readouts
              Row(
                children: [
                  Expanded(
                    child: _MacroChip(
                      label: loc.cameraMacroProtein,
                      value: '${_r.protein.round()} ${loc.gramsUnit}',
                      color: c.primary,
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap8),
                  Expanded(
                    child: _MacroChip(
                      label: loc.cameraMacroCarbs,
                      value: '${_r.carbs.round()} ${loc.gramsUnit}',
                      color: c.secondary,
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap8),
                  Expanded(
                    child: _MacroChip(
                      label: loc.cameraMacroFat,
                      value: '${_r.fat.round()} ${loc.gramsUnit}',
                      color: c.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              Text(
                loc.cameraMealSlotHint.toUpperCase(),
                style: SalamatDarkType.eyebrow.copyWith(color: c.text3),
              ),
              const SizedBox(height: SalamatDarkDims.gap8),
              Row(
                children: [
                  for (final t in MealType.values) ...[
                    if (t != MealType.values.first)
                      const SizedBox(width: SalamatDarkDims.gap6),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _slot = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _slot == t ? c.primary : c.surface2,
                            borderRadius: BorderRadius.circular(
                              SalamatDarkDims.rIcon38,
                            ),
                          ),
                          child: Text(
                            _slotLabel(loc, t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SalamatDarkType.captionS.copyWith(
                              color: _slot == t ? c.onPrimary : c.text2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: SalamatDarkDims.gap16),
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onRetake,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: SalamatDarkDims.sheetButtonPad,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius:
                            BorderRadius.circular(SalamatDarkDims.rButton),
                      ),
                      child: Text(
                        loc.cameraRetake,
                        style: SalamatDarkType.body.copyWith(color: c.text),
                      ),
                    ),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onSave(_r, _slot),
                      child: Container(
                        padding: const EdgeInsets.all(
                          SalamatDarkDims.sheetButtonPad,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius:
                              BorderRadius.circular(SalamatDarkDims.rButton),
                        ),
                        child: Text(
                          loc.cameraLogKcal(_r.kcal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SalamatDarkType.btnS
                              .copyWith(color: c.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 26x26 stepper button, radius 9, `--surface` on `--surface-2`.
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});

  final PhosphorIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rStep),
        ),
        child: PhosphorIcon(icon, size: 11, color: c.text2),
      ),
    );
  }
}

/// Compact macro readout: coloured eyebrow over a tabular value.
class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SalamatDarkType.eyebrowS.copyWith(
              color: color,
              letterSpacing: 0.1 * 10.5,
            ),
          ),
          const SizedBox(height: SalamatDarkDims.gap4),
          Text(
            value,
            style: SalamatDarkType.captionS.copyWith(
              color: c.text,
              fontWeight: SalamatDarkType.semi,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
