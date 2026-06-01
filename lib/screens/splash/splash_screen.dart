import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) context.go('/onboarding/welcome');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
