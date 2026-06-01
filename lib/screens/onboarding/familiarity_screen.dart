import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/user_provider.dart';
import '../../theme/elevation.dart';
import 'widgets.dart';

class FamiliarityScreen extends ConsumerStatefulWidget {
  const FamiliarityScreen({super.key});

  @override
  ConsumerState<FamiliarityScreen> createState() => _FamiliarityScreenState();
}

class _FamiliarityScreenState extends ConsumerState<FamiliarityScreen> {
  Familiarity? _selected;

  static const _icons = {
    Familiarity.novice: LucideIcons.sprout,
    Familiarity.intermediate: LucideIcons.bookOpen,
    Familiarity.expert: LucideIcons.graduationCap,
  };

  @override
  void initState() {
    super.initState();
    _selected = ref.read(userProvider).familiarity;
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setFamiliarity(_selected!);
    context.go('/onboarding/activity');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 11,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.familiarityTitle),
          const SizedBox(height: 24),
          // Soft amber social-proof highlight.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF4DE),
              borderRadius: BorderRadius.circular(SalamatElevation.tileRadius),
              boxShadow: SalamatElevation.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4D679),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lightbulb,
                    size: 16,
                    color: Color(0xFF7A5A0F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.familiarityHint,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7A5A0F),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 180.ms, duration: 320.ms),
          const SizedBox(height: 24),
          for (final f in Familiarity.values) ...[
            OnboardingSelectCard(
              title: f.label(loc),
              subtitle: f.subtitle(loc),
              leading: OnboardingLeadingIcon(
                icon: _icons[f] ?? LucideIcons.circle,
                selected: _selected == f,
              ),
              selected: _selected == f,
              onTap: () => setState(() => _selected = f),
            ),
            if (f != Familiarity.values.last) const SizedBox(height: 12),
          ],
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      buttonEnabled: _selected != null,
      onContinue: _next,
    );
  }
}
