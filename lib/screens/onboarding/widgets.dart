import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../providers/user_provider.dart';
import '../../theme/salamat_dark.dart';

const int kOnboardingTotalSteps = 17;

/// Common scaffold for onboarding screens, repainted to the prototype's
/// onboarding frame: `padding: 60px 24px 34px`, a single continuous progress
/// bar with the step counter on the right, and the flat neon CTA at the
/// bottom with an optional muted skip link underneath.
///
/// Logic is untouched — same constructor, same callbacks.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    this.step,
    required this.body,
    required this.buttonLabel,
    required this.onContinue,
    this.buttonEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
  });

  final int? step;
  final Widget body;
  final String buttonLabel;
  final VoidCallback onContinue;
  final bool buttonEnabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          // Prototype: 60px top absorbs the status bar, which SafeArea already
          // handles here, so the remaining inset is applied below it.
          padding: const EdgeInsets.only(
            left: SalamatDarkDims.gap24,
            right: SalamatDarkDims.gap24,
            top: SalamatDarkDims.gap16,
            bottom: SalamatDarkDims.gap16,
          ),
          child: Column(
            children: [
              if (step != null)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: SalamatDarkDims.gap26,
                  ),
                  child: OnboardingProgressBar(
                    step: step!,
                    total: kOnboardingTotalSteps,
                  ),
                )
              else
                const SizedBox(height: SalamatDarkDims.gap16),
              // The body fills the viewport when there is room and scrolls when
              // there is not.
              //
              // It must NOT be pinned to `maxHeight + inset`: that rebuilds the
              // no-keyboard height inside a box the keyboard already shrank,
              // while the progress bar and the CTA below keep theirs, so the
              // step body overflowed by ~34px whenever the keyboard was up.
              //
              // `minHeight` + `IntrinsicHeight` is the standard recipe for a
              // scrollable column that still contains `Spacer`/`Expanded`: a
              // Spacer contributes nothing to the intrinsic height, so short
              // steps stretch to fill and tall ones scroll instead of overflow.
              // The prototype's own onboarding body scrolls too
              // (`overflow-y: auto` on the plan step).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(child: body),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: SalamatDarkDims.gap20),
                child: Column(
                  children: [
                    OnboardingPrimaryButton(
                      label: buttonLabel,
                      enabled: buttonEnabled,
                      onTap: onContinue,
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: SalamatDarkDims.gap10),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSecondary,
                        child: Padding(
                          padding: const EdgeInsets.all(SalamatDarkDims.gap6),
                          child: Text(
                            secondaryLabel!,
                            textAlign: TextAlign.center,
                            style: SalamatDarkType.captionL
                                .copyWith(color: c.text3, height: null),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prototype onboarding header: a 36x36 back button on `--surface-2`, one
/// continuous 4px pill track (`--surface-3`) with a neon fill that animates
/// its width over 420 ms, and a tabular `n/total` counter.
///
/// The funnel now navigates with `context.push`, so the back button pops the
/// previous step and each step re-reads its own answer from `userProvider` in
/// `initState`. It hides itself when there is nothing to pop — the first step,
/// and the goal step after the underweight bounce resets the stack.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.step,
    required this.total,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final canGoBack = context.canPop();
    return Row(
      children: [
        if (canGoBack) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pop(),
            child: Container(
              width: SalamatDarkDims.iconBtn36,
              height: SalamatDarkDims.iconBtn36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon36),
              ),
              child: PhosphorIcon(
                PhosphorIcons.arrowLeft(),
                size: 15,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(width: SalamatDarkDims.gap14),
        ],
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
            child: Container(
              height: SalamatDarkDims.onbProgressBar,
              color: c.surface3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (step / total).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 420),
                  curve: SalamatDarkDims.ease,
                  builder: (_, f, __) => FractionallySizedBox(
                    widthFactor: f == 0 ? 0.001 : f,
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius:
                            BorderRadius.circular(SalamatDarkDims.rPill),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: SalamatDarkDims.gap14),
        Text(
          '$step/$total',
          style: SalamatDarkType.captionXs.copyWith(
            color: c.text3,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Flat neon CTA: `padding: 17px`, radius 18, `--primary` fill, `#04140A` ink,
/// 16/600, `--shadow-1`. Keeps the existing press-scale affordance.
class OnboardingPrimaryButton extends StatefulWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<OnboardingPrimaryButton> createState() =>
      _OnboardingPrimaryButtonState();
}

class _OnboardingPrimaryButtonState extends State<OnboardingPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: SalamatDarkDims.ease,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1.0 : 0.45,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SalamatDarkDims.ctaPad),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
              boxShadow: c.shadow1,
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: SalamatDarkType.btn.copyWith(color: c.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step headline: 30/600/1.1/−0.035em, with an optional 14.5 muted subtitle.
class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: SalamatDarkType.h1.copyWith(color: c.text),
        ).animate().fadeIn(duration: 320.ms).moveY(
              begin: 16,
              end: 0,
              duration: 360.ms,
              curve: SalamatDarkDims.ease,
            ),
        if (subtitle != null) ...[
          const SizedBox(height: SalamatDarkDims.gap10),
          Text(
            subtitle!,
            style: SalamatDarkType.bodyM.copyWith(color: c.text2),
          ).animate().fadeIn(delay: 120.ms, duration: 320.ms),
        ],
      ],
    );
  }
}

/// Option row: `padding: 16`, radius 20, `--surface` fill, 1.5px border that
/// turns `--primary` when selected, 42×42 icon tile, 16/500 label, and a
/// trailing check-circle / dashed-circle indicator.
class OnboardingSelectCard extends StatefulWidget {
  const OnboardingSelectCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<OnboardingSelectCard> createState() => _OnboardingSelectCardState();
}

class _OnboardingSelectCardState extends State<OnboardingSelectCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selected = widget.selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: SalamatDarkDims.ease,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
            border: Border.all(
              color: selected ? c.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected ? c.shadow1 : null,
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: SalamatDarkDims.gap14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: SalamatDarkType.bodyL.copyWith(color: c.text),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: SalamatDarkDims.gap2),
                      Text(
                        widget.subtitle!,
                        style: SalamatDarkType.micro.copyWith(color: c.text3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SalamatDarkDims.gap8),
              PhosphorIcon(
                selected
                    ? PhosphorIcons.checkCircle()
                    : PhosphorIcons.circleDashed(),
                size: 19,
                color: selected ? c.primary : c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 42×42 icon tile, radius 14. Fills with `--primary-soft` and tints the glyph
/// `--primary` when selected; otherwise `--surface-2` on `--text-3`.
class OnboardingLeadingIcon extends StatelessWidget {
  const OnboardingLeadingIcon({
    super.key,
    required this.icon,
    required this.selected,
  });

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: SalamatDarkDims.iconTile42,
      height: SalamatDarkDims.iconTile42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.primarySoft : c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rIcon42),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? c.primary : c.text3,
      ),
    );
  }
}

/// Number picker. The prototype states the numeric step as a hero numeral
/// (82/600/−0.05em, tabular) surrounded by smaller tappable neighbours; the
/// wheel keeps that visual hierarchy — big centred value, smaller dimmer
/// siblings — while preserving the existing scroll interaction and callback,
/// so no picker logic changes.
class OnboardingWheelPicker extends StatelessWidget {
  const OnboardingWheelPicker({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
  });

  final FixedExtentScrollController controller;
  final int selectedIndex;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? suffix;

  static const double _itemExtent = 58;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _itemExtent,
      magnification: 1.2,
      useMagnifier: true,
      diameterRatio: 1.8,
      perspective: 0.003,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: max - min + 1,
        builder: (context, i) {
          final selected = i == selectedIndex;
          if (selected) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${min + i}',
                    style: SalamatDarkType.numXl.copyWith(color: c.text),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: SalamatDarkDims.gap8),
                    Text(
                      suffix!,
                      style: SalamatDarkType.captionL
                          .copyWith(color: c.text2, height: null),
                    ),
                  ],
                ],
              ),
            );
          }
          return Center(
            child: Text(
              suffix == null ? '${min + i}' : '${min + i} $suffix',
              style: SalamatDarkType.bodyL.copyWith(
                color: c.text3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
  }
}

int calculateDailyCalories({
  required double weight,
  required double height,
  required int age,
  required Gender? gender,
  required ActivityLevel? activityLevel,
  required Goal? goal,
}) {
  final isFemale = gender == Gender.female;
  final bmr = isFemale
      ? 10 * weight + 6.25 * height - 5 * age - 161
      : 10 * weight + 6.25 * height - 5 * age + 5;
  final mult = (activityLevel ?? ActivityLevel.light).multiplier;
  var kcal = bmr * mult;
  switch (goal) {
    case Goal.lose:
      kcal -= 500;
      break;
    case Goal.gain:
      kcal += 500;
      break;
    case Goal.maintain:
    case Goal.healthy:
    case null:
      break;
  }
  final floor = isFemale ? 1200 : 1500;
  return kcal.round().clamp(floor, 5000);
}

/// Animated integer that counts up from 0 to [value]. Used for hero numbers
/// (calorie ring, plan calories, BMI). Uses TweenAnimationBuilder so it
/// only re-animates when [value] changes.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 850),
    this.textAlign,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: SalamatDarkDims.ease,
      builder: (_, v, __) {
        return Text('${v.round()}', style: style, textAlign: textAlign);
      },
    );
  }
}

/// Eyebrow + card + row helpers shared by the repainted screens.
///
/// `SalamatCard` is the prototype's default surface: `--surface` fill, no
/// border, `--shadow-1`, radius 22 (or 24 for hero cards).
class SalamatCard extends StatelessWidget {
  const SalamatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SalamatDarkDims.padCard),
    this.radius = SalamatDarkDims.rCard,
    this.color,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? c.shadow1 : null,
      ),
      child: child,
    );
  }
}

/// Uppercase eyebrow label: 11/600/+0.12em.
class SalamatEyebrow extends StatelessWidget {
  const SalamatEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: SalamatDarkType.eyebrow.copyWith(color: color ?? context.c.text3),
    );
  }
}
