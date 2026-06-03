import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import 'widgets.dart';

class LongTermScreen extends StatelessWidget {
  const LongTermScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 10,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.longTermTitle),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SalamatColors.surf,
              borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
              border: Border.all(color: SalamatColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _ChartPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 16),
                _LegendRow(
                  color: SalamatColors.g1,
                  label: loc.longTermLegendSalamat,
                ),
                const SizedBox(height: 6),
                _LegendRow(
                  color: SalamatColors.warn,
                  label: loc.longTermLegendOthers,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SalamatColors.g4,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text('📊', style: GoogleFonts.manrope(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.longTermStat,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SalamatColors.g1,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.go('/onboarding/familiarity'),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SalamatColors.i2,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final axis = Paint()
      ..color = SalamatColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), axis);

    final salamat = Paint()
      ..color = SalamatColors.g1
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pathS = Path();
    for (int i = 0; i <= 60; i++) {
      final t = i / 60.0;
      final x = t * w;
      final ease = 1 - math.pow(1 - t, 2).toDouble();
      final y = h * 0.15 + ease * h * 0.65;
      if (i == 0) {
        pathS.moveTo(x, y);
      } else {
        pathS.lineTo(x, y);
      }
    }
    canvas.drawPath(pathS, salamat);

    final other = Paint()
      ..color = SalamatColors.warn
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pathO = Path();
    for (int i = 0; i <= 60; i++) {
      final t = i / 60.0;
      final x = t * w;
      final dip = math.sin(t * math.pi);
      final y = h * 0.18 + (0.45 - 0.55 * dip + 0.6 * t) * h;
      if (i == 0) {
        pathO.moveTo(x, y);
      } else {
        pathO.lineTo(x, y);
      }
    }
    canvas.drawPath(pathO, other);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
