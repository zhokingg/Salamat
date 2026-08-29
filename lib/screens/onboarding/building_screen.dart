import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../theme/salamat_icons.dart';
import '../../theme/salamat_dark.dart';

class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key});

  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();
    _advance = Timer(const Duration(milliseconds: 4200), () {
      // Replaces itself: this screen auto-advances on a timer, so leaving
      // it in the back stack would strand anyone who pops back into it.
      if (mounted) context.pushReplacement('/onboarding/plan');
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final steps = [loc.buildingStep1, loc.buildingStep2, loc.buildingStep3];
    return Scaffold(
      backgroundColor: sc.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              Center(
                child: SalamatIcon(
                  PhosphorIcons.gear(),
                  size: 64,
                  color: sc.text3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.buildingTitle,
                textAlign: TextAlign.center,
                style: SalamatDarkType.style(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.4,
                  color: sc.text,
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) {
                  final v = _ctl.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: sc.surface3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v,
                          child: Container(
                            decoration: BoxDecoration(
                              color: sc.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(v * 100).round()}%',
                          style: SalamatDarkType.style(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sc.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (var i = 0; i < steps.length; i++) ...[
                        _ChecklistRow(
                          label: steps[i],
                          done: v >= (i + 1) / steps.length,
                        ),
                        if (i != steps.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: done ? sc.primarySoft : sc.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done ? sc.primarySoft : sc.surface3,
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: done
                ?  Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey('done'),
                    color: sc.primary,
                    size: 22,
                  )
                :  SizedBox(
                    key: ValueKey('pending'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: sc.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: SalamatDarkType.style(
              fontSize: 14,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: sc.text,
            ),
          ),
        ],
      ),
    );
  }
}
