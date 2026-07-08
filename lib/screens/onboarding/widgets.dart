import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/dimensions.dart';
import '../../theme/salamat_theme.dart';

const int kOnboardingTotalSteps = 17;

/// Common scaffold for onboarding screens. Adds a subtle page gradient, a
/// thicker progress bar with animated fill, generous spacing, and the
/// premium primary button.
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
    return Scaffold(
      backgroundColor: SalamatTokens.background,
      body: SafeArea(
          child: Column(
            children: [
              if (step != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SalamatDims.screenPadding,
                    24,
                    SalamatDims.screenPadding,
                    8,
                  ),
                  child: OnboardingProgressBar(
                    step: step!,
                    total: kOnboardingTotalSteps,
                  ),
                )
              else
                const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SalamatDims.screenPadding,
                  ),
                  child: body,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SalamatDims.screenPadding,
                  12,
                  SalamatDims.screenPadding,
                  16,
                ),
                child: Column(
                  children: [
                    OnboardingPrimaryButton(
                      label: buttonLabel,
                      enabled: buttonEnabled,
                      onTap: onContinue,
                    ),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(
                          secondaryLabel!,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SalamatTokens.textMuted,
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
    );
  }
}

/// Segmented progress: accentDeep segments on a ringTrack base, with a
/// muted step counter on the right.
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
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < step
                          ? SalamatTokens.accentDeep
                          : SalamatTokens.ringTrack,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i != total - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$step/$total',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SalamatTokens.textMuted,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Gradient primary button with a press-down scale animation.
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: widget.enabled ? 1.0 : 0.45,
          child: Container(
            width: double.infinity,
            height: SalamatDims.buttonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SalamatTokens.accentDeep,
              borderRadius: BorderRadius.circular(SalamatTokens.radiusCta),
            ),
            child: Text(widget.label, style: SalamatType.btn),
          ),
        ),
      ),
    );
  }
}

/// Big bold question headline.
class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: SalamatType.h2,
        ).animate().fadeIn(duration: 320.ms).moveY(
              begin: 8,
              end: 0,
              duration: 360.ms,
              curve: Curves.easeOutCubic,
            ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: SalamatType.caption.copyWith(fontSize: 15),
          ).animate().fadeIn(delay: 120.ms, duration: 320.ms),
        ],
      ],
    );
  }
}

/// Selectable card with a refined selected state — soft tinted fill,
/// elevated shadow, and a press-scale animation.
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: SalamatTokens.surfaceAlt,
            borderRadius: BorderRadius.circular(SalamatTokens.radiusCard),
            border: Border.all(
              color: selected ? SalamatTokens.accentDeep : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: SalamatTokens.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SalamatTokens.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft circular icon container used as the leading element on select
/// cards. Tints itself green when selected.
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? SalamatTokens.pillBg : SalamatTokens.bubbleMint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color:
            selected ? SalamatTokens.accentDeep : SalamatTokens.textMuted,
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? SalamatTokens.accentDeep : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color:
              selected ? SalamatTokens.accentDeep : SalamatTokens.iconQuiet,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded,
              size: 14, color: SalamatTokens.onAccent)
          : null,
    );
  }
}

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
    return Stack(
      alignment: Alignment.center,
      children: [
        ListWheelScrollView.useDelegate(
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
              final label = suffix == null
                  ? '${min + i}'
                  : '${min + i} $suffix';
              return Center(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: selected ? 44 : 22,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? SalamatTokens.textPrimary
                        : SalamatTokens.iconQuiet,
                    height: 1.0,
                    letterSpacing: selected ? -0.6 : 0,
                  ),
                ),
              );
            },
          ),
        ),
        IgnorePointer(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 1,
                color: SalamatTokens.ringTrack,
              ),
              const SizedBox(height: _itemExtent),
              Container(
                width: double.infinity,
                height: 1,
                color: SalamatTokens.ringTrack,
              ),
            ],
          ),
        ),
      ],
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
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        return Text('${v.round()}', style: style, textAlign: textAlign);
      },
    );
  }
}
