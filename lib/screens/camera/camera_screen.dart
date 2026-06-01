import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/photo_recognition_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/text_styles.dart';

const Color _kCamBg = Color(0xFF111810);

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

      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isDenied || status.isPermanentlyDenied) {
        await _showPermissionDialog();
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _unavailable = true);
        return;
      }
      final controller = CameraController(
        cams.first,
        ResolutionPreset.medium,
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

  Future<void> _showPermissionDialog() async {
    final loc = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SalamatColors.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          loc.cameraPermissionTitle,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SalamatColors.ink,
          ),
        ),
        content: Text(
          loc.cameraPermissionBody,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: SalamatColors.i2,
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
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SalamatColors.i2,
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
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalamatColors.g1,
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
      await _showResultSheet(r);
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
      backgroundColor: SalamatColors.surf,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        backgroundColor: SalamatColors.warn,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
          ),
        ),
      ),
    );
  }

  void _onSave(_Recognized r) {
    final loc = AppLocalizations.of(context)!;
    ref.read(mealsProvider.notifier).add(
          MealType.lunch,
          MealEntry(
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
        backgroundColor: SalamatColors.g1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.cameraAddedSnack,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
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
                          child: CustomPaint(painter: _ViewfinderPainter()),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: FadeTransition(
                                opacity: _pulse,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: SalamatColors.g2,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 200,
                          child: _processing
                              ? _LabelOverlay(text: loc.cameraLoading)
                              : _LabelOverlay(text: loc.cameraHint, dim: true),
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
        style: GoogleFonts.manrope(
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
        style: GoogleFonts.manrope(
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
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      child: Center(
        child: GestureDetector(
          onTap: processing ? null : onTap,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: processing
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      color: SalamatColors.g2,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 280.0;
    const corner = 40.0;
    const stroke = 2.5;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - squareSize / 2;
    final top = cy - squareSize / 2;
    final right = cx + squareSize / 2;
    final bottom = cy + squareSize / 2;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(left, top), Offset(left + corner, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + corner), paint);
    canvas.drawLine(Offset(right, top), Offset(right - corner, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + corner), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + corner, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - corner), paint);
    canvas.drawLine(
        Offset(right, bottom), Offset(right - corner, bottom), paint);
    canvas.drawLine(
        Offset(right, bottom), Offset(right, bottom - corner), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnavailableStub extends StatelessWidget {
  const _UnavailableStub({required this.onSimulate});

  final Future<void> Function() onSimulate;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SalamatDims.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // The "simulate recognition" mock path is a dev-only affordance.
              // In release the device genuinely has no usable camera, so show
              // a neutral message and no mock button.
              kDebugMode ? loc.cameraUnavailable : loc.cameraUnavailableDevice,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: SalamatDims.buttonHeight,
                child: ElevatedButton(
                  onPressed: onSimulate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SalamatColors.g2,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        SalamatDims.buttonRadius,
                      ),
                    ),
                  ),
                  child: Text(loc.cameraSimulate, style: SalamatText.btn),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutOfPhotosStub extends StatelessWidget {
  const _OutOfPhotosStub({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SalamatDims.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.cameraOutOfPhotos,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: SalamatDims.buttonHeight,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SalamatColors.g2,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      SalamatDims.buttonRadius,
                    ),
                  ),
                ),
                child: Text(loc.cameraTryPro, style: SalamatText.btn),
              ),
            ),
          ],
        ),
      ),
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
  final void Function(_Recognized) onSave;
  final VoidCallback onRetake;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late _Recognized _r;

  @override
  void initState() {
    super.initState();
    _r = widget.initial;
  }

  void _adjust(int delta) {
    final next = (_r.grams + delta).clamp(50, 2000);
    setState(() => _r = _r.withGrams(next));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SalamatColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SalamatDims.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _r.name,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.cameraConfidence(_r.confidence),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.g1,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${_r.kcal}',
                        style: GoogleFonts.manrope(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: SalamatColors.g1,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.cameraKcalPerPortion(_r.grams),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SalamatColors.i3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _MacroRow(
                    label: loc.cameraMacroProtein,
                    value: '${_r.protein.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 10),
                _MacroRow(
                    label: loc.cameraMacroFat,
                    value: '${_r.fat.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 10),
                _MacroRow(
                    label: loc.cameraMacroCarbs,
                    value: '${_r.carbs.toStringAsFixed(1)} ${loc.gramsUnit}'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PortionBtn(
                      icon: Icons.remove_rounded,
                      onTap: () => _adjust(-50),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 90,
                      child: Text(
                        loc.gramsSuffix(_r.grams),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: SalamatColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _PortionBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _adjust(50),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: SalamatDims.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => widget.onSave(_r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SalamatColors.g1,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          SalamatDims.buttonRadius,
                        ),
                      ),
                    ),
                    child: Text(loc.cameraAddButton, style: SalamatText.btn),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: widget.onRetake,
                    child: Text(
                      loc.cameraRetake,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: SalamatColors.i2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SalamatColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SalamatColors.i2,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortionBtn extends StatelessWidget {
  const _PortionBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: SalamatColors.g4,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: SalamatColors.g1),
      ),
    );
  }
}
