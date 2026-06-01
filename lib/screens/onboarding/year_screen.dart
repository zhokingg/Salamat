import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/colors.dart';
import 'widgets.dart';

class YearScreen extends ConsumerStatefulWidget {
  const YearScreen({super.key});

  @override
  ConsumerState<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends ConsumerState<YearScreen> {
  // Minimum age policy. Salamat is a calorie / weight-management app; we
  // don't serve under-16s for safety + regulatory reasons (KOPPA-equivalent,
  // Play Families policy, app-store age ratings).
  static const int _minAge = 16;

  static const int _minYear = 1940;
  late final int _maxYear;
  late final int _defaultYear;

  late final FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    // Year ceiling enforces the minimum age — the wheel can't even land on
    // a too-recent year. The explicit _next() check below is defensive in
    // case state is ever bypassed (e.g. resumed from a stored back-stack).
    _maxYear = currentYear - _minAge;
    _defaultYear = currentYear - 25;
    final existingAge = ref.read(userProvider).age;
    final startYear = existingAge != null
        ? (currentYear - existingAge).clamp(_minYear, _maxYear)
        : _defaultYear;
    _index = startYear - _minYear;
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _year => _minYear + _index;
  int get _age => DateTime.now().year - _year;

  void _next() {
    if (_age < _minAge) {
      // Safety net — should be unreachable while _maxYear is computed from
      // _minAge, but if a future change loosens the wheel this stops the
      // bypass before anything's saved.
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.yearMinAgeWarning(_minAge)),
        ),
      );
      return;
    }
    ref.read(userProvider.notifier).setAge(_age);
    context.go('/onboarding/weight');
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
          OnboardingHeadline(loc.yearTitle, subtitle: loc.yearSubtitle),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: OnboardingWheelPicker(
              controller: _controller,
              selectedIndex: _index,
              min: _minYear,
              max: _maxYear,
              onChanged: (i) => setState(() => _index = i),
            ),
          ),
          Center(
            child: Text(
              loc.yearAgeLabel(_age),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SalamatColors.g1,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      onContinue: _next,
    );
  }
}
