import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/bootstrap_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _minTimer;
  Timer? _maxTimer;
  bool _minElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Hold the brand for a minimum, then proceed as soon as bootstrap settles.
    _minTimer = Timer(const Duration(seconds: 2), () {
      _minElapsed = true;
      _tryNavigate();
    });
    // Safety net: never trap the user on splash if the network hangs.
    _maxTimer = Timer(const Duration(seconds: 8), _goNext);
  }

  /// Navigate once the minimum splash time has elapsed AND the profile load
  /// has finished (resolved or errored — we don't block the UI on a failed
  /// init). [profileProvider] awaits bootstrap internally, so this still
  /// honours the startup gate (init + anonymous session) before deciding.
  void _tryNavigate() {
    if (!_minElapsed) return;
    final profile = ref.read(profileProvider);
    if (profile.hasValue || profile.hasError) _goNext();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final row = ref.read(profileProvider).valueOrNull;
    if (_isOnboarded(row)) {
      // Returning user: restore their data and skip straight to the dashboard.
      ref.read(userProvider.notifier).hydrateFromProfile(row!);
      context.go('/dashboard');
    } else {
      context.go('/onboarding/welcome');
    }
  }

  /// A profile counts as "onboarded" only when both name and calorie norm are
  /// set. The `handle_new_user` trigger inserts an empty row at anonymous
  /// sign-in, so a row merely existing does not mean onboarding is done.
  static bool _isOnboarded(Map<String, dynamic>? row) {
    if (row == null) return false;
    final name = (row['name'] as String?)?.trim() ?? '';
    final kcalRaw = row['calorie_norm'];
    final kcal = kcalRaw is num
        ? kcalRaw.toInt()
        : int.tryParse(kcalRaw?.toString() ?? '') ?? 0;
    return name.isNotEmpty && kcal > 0;
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _maxTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kick off bootstrap (init + anonymous sign-in) then the profile load, and
    // react when it settles. profileProvider transitively starts bootstrap.
    ref.listen(profileProvider, (_, __) => _tryNavigate());
    ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: SalamatColors.g1,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LeafIcon(size: 88),
              const SizedBox(height: 20),
              Text(
                'Salamat',
                style: GoogleFonts.manrope(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: SalamatColors.surf,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeafIcon extends StatelessWidget {
  const _LeafIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LeafPainter()),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SalamatColors.surf
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.95, h * 0.25, w * 0.95, h * 0.75, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.05, h * 0.75, w * 0.05, h * 0.25, w * 0.5, h * 0.08)
      ..close();

    canvas.drawPath(path, paint);

    final vein = Paint()
      ..color = SalamatColors.g1
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.18),
      Offset(w * 0.5, h * 0.85),
      vein,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
