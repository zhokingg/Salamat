import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/sources.dart';
import '../theme/salamat_dark.dart';

/// Where the numbers come from, next to the numbers.
///
/// App Store guideline 1.4.1: an app that produces medical-style figures has
/// to say how, and cite it, in a place the person can find. This card sits
/// directly under the calorie target and the BMI scale — not in settings, not
/// behind an "about" link — with the standards named in its header even when
/// it is collapsed, and every source a tappable link that opens the paper or
/// the WHO/FAO page itself. Nothing links to a page of ours.
///
/// The card is also where the app is honest about what is convention rather
/// than citation: the activity multipliers, the ±500 kcal shift and the
/// 1200/1500 floors all have a sentence saying so. Pinning a paper to a number
/// the paper does not contain would be the opposite of what 1.4.1 is for.
///
/// Register: reference. It explains; it does not reassure, warn or promise.
class MethodologyCard extends StatefulWidget {
  const MethodologyCard({
    super.key,
    this.showCalories = true,
    this.showBmi = true,
    this.initiallyExpanded = false,
  });

  final bool showCalories;
  final bool showBmi;
  final bool initiallyExpanded;

  @override
  State<MethodologyCard> createState() => _MethodologyCardState();
}

class _MethodologyCardState extends State<MethodologyCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final standards = <String>[
      if (widget.showCalories) loc.methodStandardMifflin,
      if (widget.showBmi) loc.methodStandardWho,
    ].join(' · ');

    return Semantics(
      container: true,
      button: true,
      expanded: _open,
      label: '${loc.methodTitle}. $standards',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sc.surface2,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
          border: Border.all(color: sc.surface3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.bookOpenText(PhosphorIconsStyle.duotone),
                      size: 22,
                      color: sc.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.methodTitle,
                            style: SalamatDarkType.style(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: sc.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // The standards are visible without opening the
                          // card, so "which formula" is answered at a glance.
                          Text(
                            standards,
                            style: SalamatDarkType.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: sc.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PhosphorIcon(
                      _open
                          ? PhosphorIcons.caretUp()
                          : PhosphorIcons.caretDown(),
                      size: 18,
                      color: sc.text3,
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showCalories) ...[
                      _Section(
                        title: loc.methodKcalTitle,
                        paragraphs: [
                          loc.methodKcalFormula,
                          loc.methodKcalAccuracy,
                          loc.methodActivity,
                          loc.methodGoalShift,
                          loc.methodFloors,
                        ],
                        sources: [
                          (loc.methodSrcMifflin, Sources.mifflin1990),
                          (loc.methodSrcFrankenfield, Sources.frankenfield2005),
                          (loc.methodSrcFao, Sources.faoEnergy2004),
                          (loc.methodSrcHall, Sources.hall2008),
                          (loc.methodSrcKoliaki, Sources.koliaki2018),
                        ],
                      ),
                      if (widget.showBmi) const SizedBox(height: 16),
                    ],
                    if (widget.showBmi)
                      _Section(
                        title: loc.methodBmiTitle,
                        paragraphs: [
                          loc.methodBmiBands,
                          loc.methodBmiCaveat,
                          loc.methodBmiAsia,
                        ],
                        sources: [
                          (loc.methodSrcWhoTable, Sources.whoBmiTable),
                          (loc.methodSrcWhoTrs, Sources.whoTrs854),
                          (loc.methodSrcWhoFact, Sources.whoObesityFactSheet),
                          (loc.methodSrcWhoAsia, Sources.whoAsianBmi2004),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Text(
                      loc.methodNotAdvice,
                      style: SalamatDarkType.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sc.text3,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.paragraphs,
    required this.sources,
  });

  final String title;
  final List<String> paragraphs;

  /// (label, url)
  final List<(String, String)> sources;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: SalamatDarkType.style(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: sc.text3,
          ),
        ),
        const SizedBox(height: 8),
        for (final p in paragraphs) ...[
          Text(
            p,
            style: SalamatDarkType.style(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: sc.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 2),
        Text(
          loc.methodSourcesLabel,
          style: SalamatDarkType.style(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sc.text2,
          ),
        ),
        const SizedBox(height: 4),
        for (final (label, url) in sources) _SourceLink(label: label, url: url),
      ],
    );
  }
}

/// One citation, opened in the system browser.
///
/// The row is the link: no truncated URL to squint at, a proper label, and a
/// hit area a thumb can find. `externalApplication` so the paper opens in the
/// browser rather than in a sheet that hides where the person is.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.label, required this.url});

  final String label;
  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: PhosphorIcon(
                PhosphorIcons.arrowSquareOut(),
                size: 14,
                color: sc.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: SalamatDarkType.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sc.primary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
