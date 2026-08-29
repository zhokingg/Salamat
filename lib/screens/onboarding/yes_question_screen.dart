import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

enum YesQuestion { lose, order, health }

class YesQuestionScreen extends ConsumerWidget {
  const YesQuestionScreen({super.key, required this.question});

  final YesQuestion question;

  /// First question adapts to the user's goal — asking a gainer whether
  /// they want to lose weight reads like the app wasn't listening.
  String _headline(AppLocalizations loc, Goal? goal) => switch (question) {
        YesQuestion.lose => switch (goal) {
            Goal.gain => loc.yesGainQuestion,
            Goal.maintain || Goal.healthy => loc.yesMaintainQuestion,
            _ => loc.yesLoseQuestion,
          },
        YesQuestion.order => loc.yesOrderQuestion,
        YesQuestion.health => loc.yesHealthQuestion,
      };

  PhosphorIconData get _beforeIcon => switch (question) {
        YesQuestion.lose => PhosphorIcons.smileySad(PhosphorIconsStyle.duotone),
        YesQuestion.order =>
          PhosphorIcons.hamburger(PhosphorIconsStyle.duotone),
        YesQuestion.health => PhosphorIcons.pill(PhosphorIconsStyle.duotone),
      };

  PhosphorIconData get _afterIcon => switch (question) {
        YesQuestion.lose => PhosphorIcons.smiley(PhosphorIconsStyle.duotone),
        YesQuestion.order =>
          PhosphorIcons.bowlFood(PhosphorIconsStyle.duotone),
        YesQuestion.health => PhosphorIcons.heart(PhosphorIconsStyle.duotone),
      };

  String get _next => switch (question) {
        YesQuestion.lose => '/onboarding/yes/order',
        YesQuestion.order => '/onboarding/yes/health',
        YesQuestion.health => '/onboarding/comparison',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final goal = ref.watch(userProvider).goal;
    return OnboardingShell(
      step: 13,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            _headline(loc, goal),
            style: SalamatDarkType.style(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: sc.text,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _Illust(
                  icon: _beforeIcon,
                  iconColor: sc.text2,
                  caption: loc.yesCaptionBefore,
                  bg: sc.surface3,
                ),
              ),
               Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: sc.text3,
                ),
              ),
              Expanded(
                child: _Illust(
                  icon: _afterIcon,
                  iconColor: sc.primary,
                  caption: loc.yesCaptionAfter,
                  bg: sc.primarySoft,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonYes,
      onContinue: () => context.push(_next),
      secondaryLabel: loc.buttonNo,
      onSecondary: () => context.push(_next),
    );
  }
}

class _Illust extends StatelessWidget {
  const _Illust({
    required this.icon,
    required this.iconColor,
    required this.caption,
    required this.bg,
  });
  final PhosphorIconData icon;
  final Color iconColor;
  final String caption;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
          ),
          child: PhosphorIcon(icon, size: 64, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: SalamatDarkType.style(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: sc.text3,
          ),
        ),
      ],
    );
  }
}
