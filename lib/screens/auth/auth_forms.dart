import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show OnboardingPrimaryButton;

String authFailureText(AuthFailure f, AppLocalizations loc) => switch (f) {
      AuthFailure.badCredentials => loc.authErrBadCredentials,
      AuthFailure.emailTaken => loc.authErrEmailTaken,
      AuthFailure.invalidEmail => loc.authErrInvalidEmail,
      AuthFailure.weakPassword => loc.authErrWeakPassword,
      AuthFailure.rateLimited => loc.authErrRateLimited,
      AuthFailure.offline => loc.authErrOffline,
    };

/// Email + password, shared by the sign-in screen and the attach sheet.
class AuthFields extends StatelessWidget {
  const AuthFields({
    super.key,
    required this.email,
    required this.password,
    required this.onChanged,
    required this.onSubmit,
    this.enabled = true,
  });

  final TextEditingController email;
  final TextEditingController password;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        _Field(
          controller: email,
          enabled: enabled,
          label: loc.authEmailLabel,
          hint: loc.authEmailHint,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          icon: PhosphorIcons.envelopeSimple(),
          onChanged: onChanged,
        ),
        const SizedBox(height: SalamatDarkDims.gap12),
        _Field(
          controller: password,
          enabled: enabled,
          label: loc.authPasswordLabel,
          hint: loc.authPasswordHint,
          obscure: true,
          autofillHints: const [AutofillHints.password],
          icon: PhosphorIcons.lockSimple(),
          onChanged: onChanged,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.onSubmit,
    this.keyboardType,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final PhosphorIconData icon;
  final VoidCallback onChanged;
  final VoidCallback? onSubmit;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: SalamatDarkType.style(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: c.text3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: !obscure,
          textInputAction:
              onSubmit == null ? TextInputAction.next : TextInputAction.done,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmit?.call(),
          style: SalamatDarkType.bodyL.copyWith(color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: SalamatDarkType.bodyM.copyWith(color: c.text3),
            prefixIcon: PhosphorIcon(icon, size: 18, color: c.text3),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Attaches an email to the account that is already signed in.
///
/// Deliberately a sheet and not a screen: it is offered mid-flow — from
/// settings, from the paywall, from the sign-out warning — and none of those
/// should lose their place.
Future<bool> showAttachEmailSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AttachEmailSheet(),
  );
  return ok ?? false;
}

class _AttachEmailSheet extends ConsumerStatefulWidget {
  const _AttachEmailSheet();

  @override
  ConsumerState<_AttachEmailSheet> createState() => _AttachEmailSheetState();
}

class _AttachEmailSheetState extends ConsumerState<_AttachEmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  LinkOutcome? _done;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      AuthService.looksLikeEmail(_email.text) &&
      _password.text.length >= AuthService.kMinPasswordLength;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final loc = AppLocalizations.of(context)!;
    final (outcome, failure) = await AuthService.linkEmail(
      address: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure == null ? null : authFailureText(failure, loc);
      _done = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SalamatDarkDims.rHero),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line2,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rPill),
                  ),
                ),
              ),
              const SizedBox(height: SalamatDarkDims.gap20),
              if (_done != null) ...[
                _Done(outcome: _done!, email: _email.text.trim()),
                const SizedBox(height: SalamatDarkDims.gap20),
                OnboardingPrimaryButton(
                  label: loc.buttonContinue,
                  enabled: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ] else ...[
                Text(
                  loc.authLinkTitle,
                  style: SalamatDarkType.h3.copyWith(color: c.text),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.authLinkSubtitle,
                  style: SalamatDarkType.bodyM
                      .copyWith(color: c.text2, height: 1.4),
                ),
                const SizedBox(height: SalamatDarkDims.gap20),
                AuthFields(
                  email: _email,
                  password: _password,
                  enabled: !_busy,
                  onChanged: () => setState(() {}),
                  onSubmit: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: SalamatDarkDims.gap12),
                  _ErrorLine(text: _error!),
                ],
                const SizedBox(height: SalamatDarkDims.gap20),
                OnboardingPrimaryButton(
                  label: loc.authLinkCta,
                  enabled: _valid && !_busy,
                  onTap: _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.outcome, required this.email});

  final LinkOutcome outcome;
  final String email;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    final linked = outcome == LinkOutcome.linked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhosphorIcon(
          linked
              ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
              : PhosphorIcons.envelopeSimple(PhosphorIconsStyle.duotone),
          size: 34,
          color: c.primary,
        ),
        const SizedBox(height: SalamatDarkDims.gap12),
        Text(
          linked ? loc.authLinkedTitle : loc.authConfirmSentTitle,
          style: SalamatDarkType.h3.copyWith(color: c.text),
        ),
        const SizedBox(height: 6),
        Text(
          linked ? loc.authLinkedBody(email) : loc.authConfirmSentBody(email),
          style: SalamatDarkType.bodyM.copyWith(color: c.text2, height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhosphorIcon(PhosphorIcons.warningCircle(), size: 16, color: c.err),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: SalamatDarkType.caption.copyWith(color: c.err, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Sign in to an account that already has an email.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      AuthService.looksLikeEmail(_email.text) && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final loc = AppLocalizations.of(context)!;
    final failure = await AuthService.signIn(
      address: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = authFailureText(failure, loc);
      });
      return;
    }
    // The account changed underneath everything that caches per-user state.
    ref.invalidate(userProvider);
    ref.invalidate(mealsProvider);
    ref.invalidate(subscriptionProvider);
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    // Only worth warning about when there is something here to lose.
    final anonymous = AuthService.isAnonymous;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: c.text, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/onboarding/welcome'),
        ),
        title: Text(
          loc.authSignInTitle,
          style: SalamatDarkType.style(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              loc.authSignInSubtitle,
              style:
                  SalamatDarkType.bodyM.copyWith(color: c.text2, height: 1.45),
            ),
            const SizedBox(height: SalamatDarkDims.gap24),
            AuthFields(
              email: _email,
              password: _password,
              enabled: !_busy,
              onChanged: () => setState(() {}),
              onSubmit: _submit,
            ),
            if (_error != null) ...[
              const SizedBox(height: SalamatDarkDims.gap12),
              _ErrorLine(text: _error!),
            ],
            const SizedBox(height: SalamatDarkDims.gap24),
            OnboardingPrimaryButton(
              label: loc.authSignInCta,
              enabled: _valid && !_busy,
              onTap: _submit,
            ),
            if (anonymous) ...[
              const SizedBox(height: SalamatDarkDims.gap24),
              // Said before they sign in, not after: signing in swaps accounts
              // and whatever was logged anonymously stays behind.
              Container(
                padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius:
                      BorderRadius.circular(SalamatDarkDims.rCard),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.authSignInWarnTitle,
                      style: SalamatDarkType.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.authSignInWarnBody,
                      style: SalamatDarkType.caption
                          .copyWith(color: c.text2, height: 1.4),
                    ),
                    const SizedBox(height: SalamatDarkDims.gap12),
                    GestureDetector(
                      onTap: () => showAttachEmailSheet(context),
                      child: Text(
                        loc.authSignInWarnLink,
                        style: SalamatDarkType.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
