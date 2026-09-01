import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show OnboardingPrimaryButton;

/// Why the app ended up here.
enum LinkProblem {
  /// A link from an auth email that could not be used — expired, already
  /// spent, or refused by the server.
  authLink,

  /// Any address the router does not recognise.
  unknownRoute,
}

/// The screen a bad link lands on.
///
/// It replaces `Text('Route not found: …')`, which is what a person saw after
/// opening the confirmation mail: a raw exception with a URL full of tokens in
/// it. Nothing here is technical, nothing is lost, and there is one way out.
class LinkProblemScreen extends StatelessWidget {
  const LinkProblemScreen({super.key, required this.problem});

  final LinkProblem problem;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.gap24,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhosphorIcon(
                PhosphorIcons.linkBreak(PhosphorIconsStyle.duotone),
                size: 40,
                color: c.text3,
              ),
              const SizedBox(height: SalamatDarkDims.gap20),
              Text(
                loc.linkProblemTitle,
                style: SalamatDarkType.h2.copyWith(color: c.text),
              ),
              const SizedBox(height: SalamatDarkDims.gap12),
              Text(
                problem == LinkProblem.authLink
                    ? loc.linkProblemAuthBody
                    : loc.linkProblemUnknownBody,
                style: SalamatDarkType.bodyM
                    .copyWith(color: c.text2, height: 1.5),
              ),
              const SizedBox(height: SalamatDarkDims.gap32),
              OnboardingPrimaryButton(
                label: loc.linkProblemCta,
                enabled: true,
                onTap: () => context.go('/dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
