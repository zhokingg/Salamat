import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../theme/salamat_dark.dart';
import 'widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // Quiet, under the primary button: anonymous entry is still the default
      // path and this must not read as a registration wall.
      secondaryLabel: loc.authHaveAccount,
      onSecondary: () => context.push('/sign-in'),
    );
  }
}

/// The picture on the first screen.
///
/// WHAT IT USED TO BE
///   `PhosphorIcons.cameraRotate` — the "switch between front and back camera"
///   glyph, floating in the middle of a 210px panel. Wrong in meaning (nothing
///   here switches cameras) and, as a lone outline icon on a third of the
///   screen, it read as a placeholder nobody had got round to.
///
/// SWAPPING IN A REAL PHOTOGRAPH
///   Change [_kHeroAsset] and nothing else. [_HeroArt] picks the renderer from
///   the file extension, so `assets/onboarding/hero.jpg` works with the same
///   one-line edit — SVG goes through flutter_svg, anything else through
///   `Image.asset`, and a photo fills the panel edge to edge instead of
///   sitting inset.
const String _kHeroAsset = 'assets/dish_icons/plov.svg';

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final isVector = _kHeroAsset.toLowerCase().endsWith('.svg');

    return ClipRRect(
      borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // CSS 160deg.
            begin: const Alignment(-0.35, -1),
            end: const Alignment(0.35, 1),
            colors: [c.primarySoft, c.secondarySoft],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A photograph fills the panel; the icon sits in it with room to
            // breathe and the caption beneath.
            if (isVector)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 52),
                child: Center(
                  child: _HeroArt(asset: _kHeroAsset, vector: true),
                ),
              )
            else
              _HeroArt(asset: _kHeroAsset, vector: false),

            // Caption, attached to the picture rather than floating beside it:
            // one line naming the three steps, over a scrim so it stays legible
            // once a photograph is behind it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.bg.withValues(alpha: 0),
                      c.bg.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Text(
                  loc.welcomeHeroCaption,
                  style: SalamatDarkType.eyebrow.copyWith(
                    color: c.text,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders whatever [_kHeroAsset] points at.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.asset, required this.vector});

  final String asset;
  final bool vector;

  @override
  Widget build(BuildContext context) {
    if (vector) {
      return SvgPicture.asset(asset, fit: BoxFit.contain);
    }
    return Image.asset(asset, fit: BoxFit.cover);
  }
}
