import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../theme/salamat_icons.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

class SocialProofScreen extends StatelessWidget {
  const SocialProofScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 15,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            loc.socialTitle,
            textAlign: TextAlign.center,
            style: SalamatDarkType.style(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: sc.text,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 90,
                  child: _Avatar(
                    icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                    fg: sc.primary,
                    bg: sc.primarySoft,
                  ),
                ),
                Positioned(
                  right: 90,
                  child: _Avatar(
                    icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                    fg: sc.onPrimary,
                    bg: sc.warn,
                  ),
                ),
                _Avatar(
                  icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                  fg: sc.onPrimary,
                  bg: sc.primary,
                  big: true,
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.push('/onboarding/building'),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.icon,
    required this.fg,
    required this.bg,
    this.big = false,
  });
  final PhosphorIconData icon;
  final Color fg;
  final Color bg;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 80.0 : 64.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: sc.surface2, width: 4),
      ),
      child: PhosphorIcon(icon, size: big ? 36 : 28, color: fg),
    );
  }
}
