import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/bootstrap_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show OnboardingPrimaryButton;

String authFailureText(AuthFailure f, AppLocalizations loc) => switch (f) {
      AuthFailure.badCredentials => loc.authErrBadCredentials,
      AuthFailure.emailTaken => loc.authErrEmailTaken,
      AuthFailure.emailNotConfirmed => loc.authErrEmailNotConfirmed,
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
  const _Done({
    required this.outcome,
    required this.email,
    this.linkedTitle,
    this.linkedBody,
  });

  final LinkOutcome outcome;
  final String email;

  /// Registration says "account created" where attaching says "email
  /// attached"; the pending-confirmation half is word for word the same.
  final String? linkedTitle;
  final String? linkedBody;

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
          linked
              ? (linkedTitle ?? loc.authLinkedTitle)
              : loc.authConfirmSentTitle,
          style: SalamatDarkType.h3.copyWith(color: c.text),
        ),
        const SizedBox(height: 6),
        Text(
          linked
              ? (linkedBody ?? loc.authLinkedBody(email))
              : loc.authConfirmSentBody(email),
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
    // Nothing to invalidate by hand any more. The session change fires an
    // auth event, `currentUidProvider` sees a different uid, and every
    // provider that hangs off it — profile, diary, weight, water, pantry,
    // subscription, RevenueCat's own app_user_id — rebuilds on its own. The
    // old three-line list was the bug: `profileProvider` was missing from it,
    // and a list like that is missing a line again the day somebody adds a
    // provider.
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
            const SizedBox(height: SalamatDarkDims.gap16),
            // Both ways out of a failed sign-in, next to the failure itself:
            // a forgotten password used to mean a lost account, and somebody
            // who has no account at all had nowhere to go from here.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LinkText(
                  label: loc.authForgotLink,
                  onTap: () => context.push('/forgot-password'),
                ),
                _LinkText(
                  label: loc.authRegisterLink,
                  onTap: () => context.push('/register'),
                ),
              ],
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


/// A quiet inline link. Same weight as the body around it, primary colour.
class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: SalamatDarkType.style(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.c.primary,
          ),
        ),
      ),
    );
  }
}

/// The shell the three account screens share: back arrow, title, scrolling
/// body. Kept local so their layout cannot drift apart.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: c.text, size: 20),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/onboarding/welcome'),
        ),
        title: Text(
          title,
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
          children: children,
        ),
      ),
    );
  }
}

/// Creates a new account from scratch.
///
/// The delicate part is not the form. Somebody who has been using the app
/// anonymously already has a diary, a weight history and possibly a
/// subscription sitting on the account they are in right now — and `signUp`
/// makes a DIFFERENT account, leaving all of that behind on one nobody can
/// ever sign into again. So when there is anything to lose, the screen leads
/// with attaching an email to the current account and keeps registration as
/// the second option.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  LinkOutcome? _done;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      AuthService.looksLikeEmail(_email.text) &&
      _password.text.length >= AuthService.kMinPasswordLength &&
      _confirm.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    final loc = AppLocalizations.of(context)!;
    if (_password.text != _confirm.text) {
      setState(() => _error = loc.authErrPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (outcome, failure) = await AuthService.signUp(
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

  /// True when the account the person is sitting in has something worth
  /// keeping. Onboarding alone counts: name, height, weight and the calorie
  /// norm are twenty taps of work.
  bool get _hasSomethingToLose {
    if (isProfileOnboarded(ref.watch(profileProvider).valueOrNull)) return true;
    if (ref.watch(userProvider).name.trim().isNotEmpty) return true;
    final meals = ref.watch(mealsProvider).valueOrNull;
    if (meals == null) return false;
    return MealType.values.any((t) => meals.forType(t).isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;

    if (_done != null) {
      return _AuthScaffold(
        title: loc.authRegisterTitle,
        children: [
          _Done(
            outcome: _done!,
            email: _email.text.trim(),
            linkedTitle: loc.authRegisteredTitle,
            linkedBody: loc.authRegisteredBody(_email.text.trim()),
          ),
          const SizedBox(height: SalamatDarkDims.gap24),
          OnboardingPrimaryButton(
            label: loc.buttonContinue,
            enabled: true,
            onTap: () => context.canPop()
                ? context.pop()
                : context.go('/onboarding/welcome'),
          ),
        ],
      );
    }

    return _AuthScaffold(
      title: loc.authRegisterTitle,
      children: [
        Text(
          loc.authRegisterSubtitle,
          style: SalamatDarkType.bodyM.copyWith(color: c.text2, height: 1.45),
        ),
        if (_hasSomethingToLose) ...[
          const SizedBox(height: SalamatDarkDims.gap20),
          Container(
            padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.authKeepDataTitle,
                  style: SalamatDarkType.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.authKeepDataBody,
                  style: SalamatDarkType.caption
                      .copyWith(color: c.text2, height: 1.4),
                ),
                const SizedBox(height: SalamatDarkDims.gap12),
                _LinkText(
                  label: loc.authKeepDataCta,
                  onTap: () async {
                    final ok = await showAttachEmailSheet(context);
                    if (ok && context.mounted) context.pop();
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: SalamatDarkDims.gap24),
        AuthFields(
          email: _email,
          password: _password,
          enabled: !_busy,
          onChanged: () => setState(() {}),
          onSubmit: () {},
        ),
        const SizedBox(height: SalamatDarkDims.gap12),
        _Field(
          controller: _confirm,
          enabled: !_busy,
          label: loc.authPasswordConfirmLabel,
          hint: loc.authPasswordConfirmHint,
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          icon: PhosphorIcons.lockSimple(),
          onChanged: () => setState(() {}),
          onSubmit: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: SalamatDarkDims.gap12),
          _ErrorLine(text: _error!),
        ],
        const SizedBox(height: SalamatDarkDims.gap24),
        OnboardingPrimaryButton(
          label: loc.authRegisterCta,
          enabled: _valid && !_busy,
          onTap: _submit,
        ),
      ],
    );
  }
}

/// Asks Supabase to mail a reset link.
///
/// Reports success whether or not the address has an account: answering
/// honestly would turn this screen into a way of finding out who is a user.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => AuthService.looksLikeEmail(_email.text);

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final loc = AppLocalizations.of(context)!;
    final failure = await AuthService.sendPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure == null ? null : authFailureText(failure, loc);
      _sent = failure == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;

    if (_sent) {
      return _AuthScaffold(
        title: loc.authForgotTitle,
        children: [
          PhosphorIcon(
            PhosphorIcons.envelopeSimple(PhosphorIconsStyle.duotone),
            size: 34,
            color: c.primary,
          ),
          const SizedBox(height: SalamatDarkDims.gap12),
          Text(
            loc.authForgotSentTitle,
            style: SalamatDarkType.h3.copyWith(color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            loc.authForgotSentBody(_email.text.trim()),
            style: SalamatDarkType.bodyM.copyWith(color: c.text2, height: 1.4),
          ),
          const SizedBox(height: SalamatDarkDims.gap24),
          OnboardingPrimaryButton(
            label: loc.buttonContinue,
            enabled: true,
            onTap: () => context.canPop() ? context.pop() : context.go('/sign-in'),
          ),
        ],
      );
    }

    return _AuthScaffold(
      title: loc.authForgotTitle,
      children: [
        Text(
          loc.authForgotSubtitle,
          style: SalamatDarkType.bodyM.copyWith(color: c.text2, height: 1.45),
        ),
        const SizedBox(height: SalamatDarkDims.gap24),
        _Field(
          controller: _email,
          enabled: !_busy,
          label: loc.authEmailLabel,
          hint: loc.authEmailHint,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          icon: PhosphorIcons.envelopeSimple(),
          onChanged: () => setState(() {}),
          onSubmit: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: SalamatDarkDims.gap12),
          _ErrorLine(text: _error!),
        ],
        const SizedBox(height: SalamatDarkDims.gap24),
        OnboardingPrimaryButton(
          label: loc.authForgotCta,
          enabled: _valid && !_busy,
          onTap: _submit,
        ),
      ],
    );
  }
}

/// Sets a new password on the current session.
///
/// Two doors lead here and they are the same room: the recovery link (which
/// signs the person in with a short-lived recovery session) and the settings
/// row for somebody who is already signed in and just wants a different
/// password.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _password.text.length >= AuthService.kMinPasswordLength &&
      _confirm.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    final loc = AppLocalizations.of(context)!;
    if (_password.text != _confirm.text) {
      setState(() => _error = loc.authErrPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await AuthService.updatePassword(_password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure == null ? null : authFailureText(failure, loc);
      _done = failure == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    return _AuthScaffold(
      title: loc.authNewPasswordTitle,
      children: [
        Text(
          _done ? loc.authNewPasswordDone : loc.authNewPasswordSubtitle,
          style: SalamatDarkType.bodyM.copyWith(
            color: _done ? c.primary : c.text2,
            height: 1.45,
          ),
        ),
        if (!_done) ...[
          const SizedBox(height: SalamatDarkDims.gap24),
          _Field(
            controller: _password,
            enabled: !_busy,
            label: loc.authPasswordLabel,
            hint: loc.authPasswordHint,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            icon: PhosphorIcons.lockSimple(),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: SalamatDarkDims.gap12),
          _Field(
            controller: _confirm,
            enabled: !_busy,
            label: loc.authPasswordConfirmLabel,
            hint: loc.authPasswordConfirmHint,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            icon: PhosphorIcons.lockSimple(),
            onChanged: () => setState(() {}),
            onSubmit: _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: SalamatDarkDims.gap12),
            _ErrorLine(text: _error!),
          ],
        ],
        const SizedBox(height: SalamatDarkDims.gap24),
        OnboardingPrimaryButton(
          label: _done ? loc.buttonContinue : loc.authNewPasswordCta,
          enabled: _done || (_valid && !_busy),
          onTap: _done
              ? () => context.canPop() ? context.pop() : context.go('/dashboard')
              : _submit,
        ),
      ],
    );
  }
}
