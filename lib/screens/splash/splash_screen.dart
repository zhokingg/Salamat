import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/bootstrap_provider.dart';
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

  /// Navigate once the minimum splash time has elapsed AND bootstrap has
  /// finished (resolved or errored — we don't block the UI on a failed init).
  void _tryNavigate() {
    if (!_minElapsed) return;
    final boot = ref.read(bootstrapProvider);
    if (boot.hasValue || boot.hasError) _goNext();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/onboarding/welcome');
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
    // Kick off bootstrap (init + anonymous sign-in) and react when it settles.
    ref.listen(bootstrapProvider, (_, __) => _tryNavigate());
    ref.watch(bootstrapProvider);
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
