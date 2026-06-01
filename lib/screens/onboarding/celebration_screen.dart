import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/colors.dart';
import 'widgets.dart';

class CelebrationScreen extends ConsumerStatefulWidget {
  const CelebrationScreen({super.key});

  @override
  ConsumerState<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends ConsumerState<CelebrationScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final u = ref.watch(userProvider);
    final delta = u.weightDelta.abs().round();
    final goal = u.goal;
    final isLosing = goal == Goal.lose || (goal == null && u.weightDelta > 0);
    final headline = delta > 0
        ? (isLosing ? loc.celebrationLose(delta) : loc.celebrationGain(delta))
        : loc.celebrationMaintain;

    return Stack(
      children: [
        OnboardingShell(
          step: null,
          body: Column(
            children: [
              const Spacer(),
              Container(
                width: 132,
                height: 132,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SalamatColors.g4,
                  shape: BoxShape.circle,
                ),
                child: const Text('👍', style: TextStyle(fontSize: 76)),
              ),
              const SizedBox(height: 28),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: -0.4,
                  color: SalamatColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: SalamatColors.g4,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  loc.celebrationStat,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.g1,
                    height: 1.35,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
          buttonLabel: loc.buttonContinue,
          onContinue: () => context.go('/onboarding/long-term'),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 12,
            minBlastForce: 6,
            gravity: 0.25,
            colors: const [
              SalamatColors.g1,
              SalamatColors.g2,
              SalamatColors.g3,
              SalamatColors.warn,
            ],
          ),
        ),
      ],
    );
  }
}
