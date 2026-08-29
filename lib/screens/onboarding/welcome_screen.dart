import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../theme/salamat_dark.dart';
import 'widgets.dart';

/// Welcome, repainted to the prototype's `scWelcome`: a 210px hero block with
/// a soft `primary-soft -> secondary-soft` gradient, a large camera glyph and
/// three floating step chips, then a left-aligned 38/600 display headline and
/// a muted supporting line.
///
/// Copy is unchanged — the existing keys already carry Russian. Only the three
/// chips are new copy from the prototype.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _WelcomeHero(),
          const SizedBox(height: SalamatDarkDims.gap32),
          Text(
            loc.welcomeHeadline,
            style: SalamatDarkType.display.copyWith(color: c.text),
          ).animate().fadeIn(duration: 320.ms).moveY(
                begin: 16,
                end: 0,
                duration: 360.ms,
                curve: SalamatDarkDims.ease,
              ),
          const SizedBox(height: SalamatDarkDims.gap12),
          Text(
            loc.welcomeSubtitle,
            style: SalamatDarkType.body
                .copyWith(color: c.text2, height: 1.5),
          ).animate().fadeIn(delay: 120.ms, duration: 320.ms),
          const SizedBox(height: SalamatDarkDims.gap12),
          Text(
            loc.welcomeFreeLine,
            style: SalamatDarkType.captionS.copyWith(color: c.text3),
          ).animate().fadeIn(delay: 200.ms, duration: 320.ms),
        ],
      ),
      buttonLabel: loc.buttonStart,
      onContinue: () => context.push('/onboarding/name'),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final chips = [
      loc.welcomeChipSnap,
      loc.welcomeChipConfirm,
      loc.welcomeChipDone,
    ];
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
        gradient: LinearGradient(
          // CSS 160deg.
          begin: const Alignment(-0.35, -1),
          end: const Alignment(0.35, 1),
          colors: [c.primarySoft, c.secondarySoft],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: PhosphorIcon(
              PhosphorIcons.cameraRotate(),
              size: 64,
              color: c.primary,
            ),
          ),
          Positioned(
            left: SalamatDarkDims.padCardTight,
            right: SalamatDarkDims.padCardTight,
            bottom: SalamatDarkDims.padCardTight,
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: SalamatDarkDims.gap8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius:
                            BorderRadius.circular(SalamatDarkDims.rIcon36),
                        boxShadow: c.shadow1,
                      ),
                      child: Text(
                        chips[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SalamatDarkType.eyebrow.copyWith(
                          color: c.text2,
                          letterSpacing: 0,
                        ),
                      ),
                    ).animate().fadeIn(
                          delay: (200 * i).ms,
                          duration: 300.ms,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
