import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import 'widgets.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final u = ref.watch(userProvider);
    final bmi = u.bmi;
    final band = u.bmiBandLabel(loc);

    return OnboardingShell(
      step: 13,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.summaryTitle),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _StatTile(
                      label: loc.summaryStatBmi,
                      value: bmi == 0 ? loc.valueDash : bmi.toStringAsFixed(1),
                      hint: band.isEmpty ? null : band,
                    ),
                    const SizedBox(height: 10),
                    _StatTile(
                      label: loc.summaryStatTarget,
                      value: u.targetWeight != null
                          ? loc.weightWeightValue(u.targetWeight!.round())
                          : loc.valueDash,
                    ),
                    const SizedBox(height: 10),
                    _StatTile(
                      label: loc.summaryStatLevel,
                      value: u.familiarity?.label(loc) ?? loc.valueDash,
                    ),
                    const SizedBox(height: 10),
                    _StatTile(
                      label: loc.summaryStatActivity,
                      value: u.activityLevel?.label(loc) ?? loc.valueDash,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 96,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SalamatColors.g4,
                  borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
                ),
                child: Text(
                  u.gender == Gender.female ? '🧍‍♀️' : '🧍‍♂️',
                  style: const TextStyle(fontSize: 84),
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.go('/onboarding/yes/lose'),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.hint});
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: SalamatColors.i3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Text(
                  hint!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.g1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
