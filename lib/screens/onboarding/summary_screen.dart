import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final u = ref.watch(userProvider);
    final bmi = u.bmi;
    final band = u.bmiBandLabel(loc);

    return OnboardingShell(
      step: 12,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.summaryTitle),
          const SizedBox(height: 24),
          // The four answers, two by two. They used to be a narrow column
          // beside a 96x200 green panel holding a person pictogram — a third
          // of the screen carrying no information. The tiles take the width
          // back and the scale below uses it for something.
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: loc.summaryStatBmi,
                  value: bmi == 0 ? loc.valueDash : bmi.toStringAsFixed(1),
                  hint: band.isEmpty ? null : band,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: loc.summaryStatTarget,
                  value: u.targetWeight != null
                      ? loc.weightWeightValue(u.targetWeight!.round())
                      : loc.valueDash,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: loc.summaryStatLevel,
                  value: u.familiarity?.label(loc) ?? loc.valueDash,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: loc.summaryStatActivity,
                  value: u.activityLevel?.label(loc) ?? loc.valueDash,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Current weight and height echoed back. They are what the BMI above
          // is computed from, and showing them turns the scale from a number
          // that appeared out of nowhere into something the user can check.
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: loc.summaryStatNow,
                  value: u.weight != null
                      ? loc.weightWeightValue(u.weight!.round())
                      : loc.valueDash,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: loc.weightHeightLabel,
                  value: u.height != null
                      ? loc.weightHeightValue(u.height!.round())
                      : loc.valueDash,
                ),
              ),
            ],
          ),
          if (bmi > 0) ...[
            const SizedBox(height: 16),
            _BmiScaleCard(bmi: bmi, band: u.bmiBand),
          ],
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.push('/onboarding/yes/lose'),
    );
  }
}


/// Where this BMI falls on the standard bands.
///
/// Deliberately quiet. This is the second screen after a stranger has told the
/// app their weight, and the honest register for that moment is a reference
/// card, not a verdict: one muted track, the user's own band picked out, a
/// marker, and a line saying what the number does not know. No red, no
/// warning icon, and no word anybody would repeat back to themselves at 2am.
class _BmiScaleCard extends StatelessWidget {
  const _BmiScaleCard({required this.bmi, required this.band});

  final double bmi;
  final BmiBand band;

  /// The scale's ends. Wide enough that a real person is never pinned to an
  /// edge, narrow enough that the normal band is not a sliver.
  static const double _min = 15;
  static const double _max = 35;

  /// Band edges, in BMI. These are the standard cut-offs; the labels around
  /// them are ours.
  static const List<double> _edges = [18.5, 25, 30];

  double get _t => ((bmi - _min) / (_max - _min)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final zones = <(BmiBand, String, double)>[
      (BmiBand.under, loc.bmiScaleZoneUnder, (_edges[0] - _min) / (_max - _min)),
      (BmiBand.normal, loc.bmiScaleZoneNormal, (_edges[1] - _edges[0]) / (_max - _min)),
      (BmiBand.over, loc.bmiScaleZoneOver, (_edges[2] - _edges[1]) / (_max - _min)),
      (BmiBand.obese, loc.bmiScaleZoneHigh, (_max - _edges[2]) / (_max - _min)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        border: Border.all(color: sc.surface3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.bmiScaleTitle.toUpperCase(),
            style: SalamatDarkType.style(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: sc.text3,
            ),
          ),
          const SizedBox(height: 14),
          // Align, not LayoutBuilder: OnboardingShell wraps its body in an
          // IntrinsicHeight, and LayoutBuilder cannot answer an intrinsic
          // height query. Align maps [0,1] onto [-1,1] and insets by the
          // marker's own width, so the marker never hangs off either end.
          Align(
            alignment: Alignment(_t * 2 - 1, 0),
            child: PhosphorIcon(
              PhosphorIcons.caretDown(PhosphorIconsStyle.fill),
              size: 14,
              color: sc.primary,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                for (final (b, _, w) in zones)
                  Expanded(
                    flex: (w * 1000).round(),
                    child: Container(
                      height: 10,
                      margin: const EdgeInsets.only(right: 2),
                      // Neutral on purpose. Green here would read as
                      // approval in the normal band and as a bizarre
                      // congratulation in the top one; this marks
                      // where you are and says nothing about it.
                      color: b == band ? sc.text2 : sc.surface3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (b, label, w) in zones)
                Expanded(
                  flex: (w * 1000).round(),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: SalamatDarkType.style(
                      fontSize: 10,
                      fontWeight: b == band ? FontWeight.w700 : FontWeight.w500,
                      color: b == band ? sc.text : sc.text3,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            loc.bmiScaleNote,
            style: SalamatDarkType.style(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: sc.text2,
              height: 1.35,
            ),
          ),
        ],
      ),
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
        color: sc.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sc.surface3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: SalamatDarkType.style(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: sc.text3,
            ),
          ),
          const SizedBox(height: 4),
          // The band label goes UNDER the value, not beside it. Side by side,
          // a long band name ("Заметно выше нормы") squeezed the number down
          // to "3..." — the one figure the tile exists to show.
          Text(
            value,
            style: SalamatDarkType.style(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: sc.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 2,
              style: SalamatDarkType.style(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sc.text2,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
