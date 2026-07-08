import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/user_provider.dart';
import '../../theme/colors.dart';
import '../../theme/elevation.dart';
import 'widgets.dart';

/// S2 — name entry. The dashboard greeting reads this value back.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _ctl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(userProvider).name;
    _ctl = TextEditingController(text: existing);
    _hasText = existing.trim().isNotEmpty;
    _ctl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctl.removeListener(_onChanged);
    _ctl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final v = _ctl.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
  }

  void _next() {
    final name = _ctl.text.trim();
    if (name.isEmpty) return;
    ref.read(userProvider.notifier).setName(name: name, lastName: '');
    context.go('/onboarding/goal');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.nameTitle, subtitle: loc.nameSubtitle),
          const SizedBox(height: 28),
          _PremiumTextField(
            controller: _ctl,
            hint: loc.nameFieldHint,
            onSubmitted: (_) => _next(),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      buttonEnabled: _hasText,
      onContinue: _next,
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.hint,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatElevation.tileRadius),
        boxShadow: SalamatElevation.card,
        border: Border.all(color: SalamatElevation.hairline),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        cursorColor: SalamatColors.g1,
        style: GoogleFonts.manrope(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: SalamatColors.ink,
          letterSpacing: -0.1,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: SalamatColors.i3,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

}
