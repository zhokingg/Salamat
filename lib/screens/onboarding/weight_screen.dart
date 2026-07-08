import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/dimensions.dart';
import '../../theme/salamat_theme.dart';
import 'widgets.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  static const int _heightMin = 140;
  static const int _heightMax = 220;
  static const int _heightDefault = 165;
  static const int _weightMin = 40;
  static const int _weightMax = 200;
  static const int _weightDefault = 70;

  late final FixedExtentScrollController _hCtl;
  late final FixedExtentScrollController _wCtl;
  late int _hIdx;
  late int _wIdx;

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider);
    final h = (u.height?.round() ?? _heightDefault).clamp(_heightMin, _heightMax);
    final w = (u.weight?.round() ?? _weightDefault).clamp(_weightMin, _weightMax);
    _hIdx = h - _heightMin;
    _wIdx = w - _weightMin;
    _hCtl = FixedExtentScrollController(initialItem: _hIdx);
    _wCtl = FixedExtentScrollController(initialItem: _wIdx);
  }

  @override
  void dispose() {
    _hCtl.dispose();
    _wCtl.dispose();
    super.dispose();
  }

  int get _height => _heightMin + _hIdx;
  int get _weight => _weightMin + _wIdx;

  double get _bmi {
    final m = _height / 100.0;
    return _weight / (m * m);
  }

  String _bmiBand(AppLocalizations loc) {
    final b = _bmi;
    if (b < 18.5) return loc.bmiBandUnder;
    if (b < 25.0) return loc.bmiBandNormal;
    if (b < 30.0) return loc.bmiBandOver;
    return loc.bmiBandObese;
  }

  Color get _bmiColor {
    final b = _bmi;
    if (b < 18.5 || b >= 25.0) return SalamatTokens.amber;
    return SalamatTokens.accent;
  }

  void _next() {
    ref.read(userProvider.notifier).setBody(
          height: _height.toDouble(),
          weight: _weight.toDouble(),
        );
    context.go('/onboarding/target');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 6,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.weightTitle, subtitle: loc.weightSubtitle),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _WheelColumn(
                    label: loc.weightHeightLabel,
                    valueLabel: loc.weightHeightValue(_height),
                    controller: _hCtl,
                    selectedIndex: _hIdx,
                    min: _heightMin,
                    max: _heightMax,
                    onChanged: (i) => setState(() => _hIdx = i),
                  ),
                ),
                Container(width: 1, color: SalamatTokens.ringTrack),
                Expanded(
                  child: _WheelColumn(
                    label: loc.weightWeightLabel,
                    valueLabel: loc.weightWeightValue(_weight),
                    controller: _wCtl,
                    selectedIndex: _wIdx,
                    min: _weightMin,
                    max: _weightMax,
                    onChanged: (i) => setState(() => _wIdx = i),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BmiHint(
            label: loc.bmiLabel,
            bmi: _bmi,
            band: _bmiBand(loc),
            color: _bmiColor,
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      onContinue: _next,
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.label,
    required this.valueLabel,
    required this.controller,
    required this.selectedIndex,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final FixedExtentScrollController controller;
  final int selectedIndex;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SalamatTokens.iconQuiet,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: OnboardingWheelPicker(
            controller: controller,
            selectedIndex: selectedIndex,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
        // Value + unit as a pill chip (metric-only; imperial units would
        // need a real conversion pass through the whole calorie pipeline).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: SalamatTokens.pillBg,
            borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
          ),
          child: Text(
            valueLabel,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SalamatTokens.pillText,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BmiHint extends StatelessWidget {
  const _BmiHint({
    required this.label,
    required this.bmi,
    required this.band,
    required this.color,
  });
  final String label;
  final double bmi;
  final String band;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SalamatTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatTokens.ringTrack),
      ),
      child: Row(
        children: [
          Text(
            '$label  ',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SalamatTokens.textMuted,
            ),
          ),
          Text(
            bmi.toStringAsFixed(1),
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SalamatTokens.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              band,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
