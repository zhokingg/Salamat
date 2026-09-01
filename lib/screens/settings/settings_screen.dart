import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/salamat_dark.dart';
import '../../widgets/update_weight_dialog.dart';
import '../onboarding/widgets.dart' show SalamatEyebrow;
import '../../services/auth_service.dart';
import '../auth/auth_forms.dart';

/// Settings, built to the prototype's `scSettings`: back button + 22/600
/// title, a segmented control, then cards of rows with a trailing value.
///
/// Two blocks of the prototype are deliberately absent because nothing in the
/// app backs them, and a control that does not control anything is worse than
/// no control:
///
///   * the light/dark segmented switcher — the skin is `kAppSkin`, a
///     compile-time constant that doubles as the redesign rollback flag, so
///     there is nothing to flip at runtime;
///   * the card of four toggles — the only booleans the app persists are the
///     onboarding-completed flag and, indirectly, the locale. No
///     notification/vibration/units preference exists to bind to.
///
/// The prototype's segmented control is reused for the one preference that IS
/// real and already persisted: language.
///
/// Sign out and Delete account stay on Profile rather than being mirrored
/// here — duplicating a destructive, irreversible flow in two places doubles
/// the surface for an accidental tap and buys nothing.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final user = ref.watch(userProvider);
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SalamatDarkDims.screenPadH,
            SalamatDarkDims.gap8,
            SalamatDarkDims.screenPadH,
            40,
          ),
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go('/profile'),
                  child: Container(
                    width: SalamatDarkDims.iconBtn36,
                    height: SalamatDarkDims.iconBtn36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius:
                          BorderRadius.circular(SalamatDarkDims.rIcon36),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.arrowLeft(),
                      size: 15,
                      color: c.text,
                    ),
                  ),
                ),
                const SizedBox(width: SalamatDarkDims.gap12),
                Text(
                  loc.settingsTitle,
                  style: SalamatDarkType.h3.copyWith(color: c.text),
                ),
              ],
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── language ──
            SalamatEyebrow(loc.languageSelectTitle),
            const SizedBox(height: SalamatDarkDims.gap10),
            _Segmented(
              options: [
                (
                  label: loc.languageRu,
                  icon: PhosphorIcons.translate(),
                  selected: locale.languageCode == 'ru',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('ru')),
                ),
                (
                  label: loc.languageEn,
                  icon: PhosphorIcons.translate(),
                  selected: locale.languageCode == 'en',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('en')),
                ),
              ],
            ),
            const SizedBox(height: SalamatDarkDims.gap8),
            Text(
              loc.settingsAppearanceUnavailable,
              style: SalamatDarkType.micro.copyWith(color: c.text3),
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── plan and goals ──
            SalamatEyebrow(loc.settingsSectionPlan),
            const SizedBox(height: SalamatDarkDims.gap10),
            _RowCard(
              rows: [
                (
                  icon: PhosphorIcons.target(),
                  label: loc.profileSettingMyGoal,
                  value: user.goal?.label(loc) ?? loc.valueDash,
                  danger: false,
                  onTap: () => context.push('/goal-edit'),
                ),
                (
                  icon: PhosphorIcons.scales(),
                  label: loc.profileSettingUpdateWeight,
                  value: user.weight == null
                      ? loc.valueDash
                      : '${user.weight!.round()} ${loc.profileKgShort}',
                  danger: false,
                  onTap: () => showUpdateWeightDialog(context, ref),
                ),
                (
                  icon: PhosphorIcons.crownSimple(),
                  label: loc.profileSettingPro,
                  value: sub.isPro ? loc.profileBadgePro : loc.profileBadgeFree,
                  danger: false,
                  onTap: () => context.push('/paywall'),
                ),
                (
                  icon: PhosphorIcons.bell(),
                  // Rendered as unavailable rather than as a dead toggle: the
                  // app has no notification plumbing yet.
                  label: loc.profileSoonSuffix(
                    loc.profileSettingNotifications,
                  ),
                  value: '',
                  danger: false,
                  onTap: null,
                ),
              ],
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── account ──
            // A permanent row, not a prompt that appears once and is gone.
            // Whether the account can be recovered is a standing fact about
            // it, so it lives where standing facts live.
            SalamatEyebrow(loc.authAccountRow),
            const SizedBox(height: SalamatDarkDims.gap10),
            _RowCard(
              rows: [
                (
                  icon: AuthService.isAnonymous
                      ? PhosphorIcons.warningCircle()
                      : PhosphorIcons.envelopeSimple(),
                  label: loc.authAccountRow,
                  value: AuthService.email ??
                      AuthService.pendingEmail ??
                      loc.authAccountAnonymous,
                  danger: false,
                  onTap: AuthService.isAnonymous
                      ? () => showAttachEmailSheet(context)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: SalamatDarkDims.gap20),

            // ── about ──
            SalamatEyebrow(loc.settingsSectionAbout),
            const SizedBox(height: SalamatDarkDims.gap10),
            _RowCard(
              rows: [
                (
                  icon: PhosphorIcons.shieldCheck(),
                  label: loc.paywallFinePrintPrivacy,
                  value: '',
                  danger: false,
                  onTap: () => _open(LegalUrls.privacyPolicy),
                ),
                (
                  icon: PhosphorIcons.info(),
                  label: loc.paywallFinePrintTerms,
                  value: '',
                  danger: false,
                  onTap: () => _open(LegalUrls.termsOfService),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

typedef _SegOption = ({
  String label,
  PhosphorIconData icon,
  bool selected,
  VoidCallback onTap,
});

/// Prototype segmented control: `padding: 4`, radius 16 on `--surface-2`, the
/// active pill on `--surface` with `--shadow-1`.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.options});

  final List<_SegOption> options;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(SalamatDarkDims.gap4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: SalamatDarkDims.gap4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: options[i].onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color:
                        options[i].selected ? c.surface : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rIcon36),
                    boxShadow: options[i].selected ? c.shadow1 : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        options[i].icon,
                        size: 15,
                        color: options[i].selected ? c.text : c.text3,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          options[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SalamatDarkType.captionL.copyWith(
                            color: options[i].selected ? c.text : c.text3,
                            height: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

typedef _Row = ({
  PhosphorIconData icon,
  String label,
  String value,
  bool danger,
  VoidCallback? onTap,
});

/// Prototype row card: radius 22 on `--surface`, rows separated by a `--line`
/// hairline, icon + label + trailing value.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: rows[i].onTap,
              child: Opacity(
                // A row with nothing behind it reads as unavailable.
                opacity: rows[i].onTap == null ? 0.45 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SalamatDarkDims.padCardSmall,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(top: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        rows[i].icon,
                        size: 17,
                        color: rows[i].danger ? c.err : c.text2,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          rows[i].label,
                          style: SalamatDarkType.bodyM.copyWith(
                            color: rows[i].danger ? c.err : c.text,
                          ),
                        ),
                      ),
                      if (rows[i].value.isNotEmpty)
                        Text(
                          rows[i].value,
                          style: SalamatDarkType.captionS
                              .copyWith(color: c.text3),
                        ),
                      if (rows[i].onTap != null) ...[
                        const SizedBox(width: SalamatDarkDims.gap8),
                        PhosphorIcon(
                          PhosphorIcons.caretRight(),
                          size: 13,
                          color: c.text3,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
