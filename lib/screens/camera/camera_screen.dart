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
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../manual_entry/manual_entry_sheet.dart';
import '../../services/photo_recognition_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/salamat_dark.dart';

/// Prototype camera canvas (`#07090C`), darker than `--bg` in light mode
/// and identical in both themes.
const Color _kCamBg = SalamatColorsDark.camBg;

/// Why recognition didn't yield a usable result. Drives the snackbar message
/// the user sees — generic "could not recognise" gets blamed on the AI,
/// network/server errors should make that distinction explicit.
enum _FailureKind { network, server, notRecognised }

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
  bool _processing = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final sub = ref.read(subscriptionProvider);
      final userId = SupabaseService.currentUser?.id ?? '';
      final can =
          await PhotoRecognitionService.canUsePhoto(userId, sub.isPro);
      if (!mounted) return;
      if (!can) {
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

    final sub = ref.read(subscriptionProvider);
    final userId = SupabaseService.currentUser?.id ?? '';
    final can = await PhotoRecognitionService.canUsePhoto(userId, sub.isPro);
    if (!mounted) return;
    if (!can) {
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
      // Quota is consumed ONLY on a confident, valid result — losing your
      // one free photo to a network blip is a terrible first experience.
      Map<String, dynamic>? json;
      _FailureKind? failure;
      try {
        json = await PhotoRecognitionService.recognizeFood(File(xfile.path));
      } on SocketException {
        failure = _FailureKind.network;
      } on HttpException {
        failure = _FailureKind.network;
      } catch (e) {
        if (kDebugMode) debugPrint('recognizeFood unexpected error: $e');
        failure = _FailureKind.server;
      }

      if (!mounted) return;
      setState(() => _processing = false);

      if (failure != null) {
        _showFailureSnack(failure);
        return;
      }
      if (json == null) {
        // Service swallowed an error and returned null — treat as server-side.
        _showFailureSnack(_FailureKind.server);
        return;
      }
      final conf = (json['confidence'] as num?)?.toDouble() ?? 0.0;
      if (conf <= 0.5) {
        _showFailureSnack(_FailureKind.notRecognised);
        return;
      }
      final r = _recognizedFromJson(json);
      if (r == null) {
        _showFailureSnack(_FailureKind.notRecognised);
        return;
      }

      // Successful, confident result — only NOW consume the quota.
      await PhotoRecognitionService.incrementUsage(userId);
      if (mounted) {
        ref.read(subscriptionProvider.notifier).usePhoto();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      if (kDebugMode) debugPrint('shutter error: $e');
      _showFailureSnack(_FailureKind.server);
    }
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
            source: 'photo',
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
          loc.navCameraAction.toUpperCase(),
          textAlign: TextAlign.center,
          style: SalamatDarkType.captionXs.copyWith(
            letterSpacing: 0.1 * 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: SalamatDarkDims.screenPadH,
              top: 8,
              bottom: 8,
            ),
            child: _PhotoCounter(
              text: loc.cameraCounter(sub.photosUsed, sub.photoLimit),
            ),
          ),
        ],
      ),
      body: _outOfPhotos
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
