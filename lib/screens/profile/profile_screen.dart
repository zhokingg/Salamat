import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/locale_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/onboarding_flag.dart';
import '../../services/supabase_service.dart';
import '../../widgets/update_weight_dialog.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_dark.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final meals = ref.watch(mealsProvider).valueOrNull ?? const MealsState();
    final sub = ref.watch(subscriptionProvider);

    final fullName = '${user.name} ${user.lastName}'.trim().isEmpty
        ? loc.profileGuest
        : '${user.name} ${user.lastName}'.trim();

    final entriesCount =
        MealType.values.expand((t) => meals.forType(t)).length;

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDarkDims.navHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          // Prototype: title with the gear on the trailing edge.
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.profileTitle,
                  style: SalamatDarkType.h2.copyWith(color: sc.text),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/settings'),
                child: Semantics(
                  button: true,
                  label: loc.settingsTitle,
                  child: Container(
                    width: SalamatDarkDims.iconBtn36,
                    height: SalamatDarkDims.iconBtn36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sc.surface2,
                      borderRadius:
                          BorderRadius.circular(SalamatDarkDims.rIcon36),
                    ),
                    child: PhosphorIcon(
                      PhosphorIcons.gear(),
                      size: 16,
                      color: sc.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fullName,
                      style: SalamatDarkType.style(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: sc.text,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PlanBadge(
                    label:
                        sub.isPro ? loc.profileBadgePro : loc.profileBadgeFree,
                    isPro: sub.isPro,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (user.goal != null) user.goal!.label(loc),
                  if (user.calorieNorm != null)
                    loc.dashboardKcalWithValue(user.calorieNorm!),
                ].join(' · '),
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sc.text2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(value: '1', label: loc.profileStatDaysInApp),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: '$entriesCount',
                  label: loc.profileStatEntries,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(value: '1', label: loc.profileStatStreak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DataCard(user: user),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _LanguageRow(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SettingsCard(
            items: [
              // Reminders row intentionally absent until the feature ships
              // (v1.1); its ARB keys stay marked as unused.
              _SettingsItem(
                icon: PhosphorIcons.target(),
                label: loc.profileSettingMyGoal,
                onTap: () => context.push('/goal-edit'),
              ),
              _SettingsItem(
                icon: PhosphorIcons.scales(),
                label: loc.profileSettingUpdateWeight,
                onTap: () => showUpdateWeightDialog(context, ref),
              ),
              _SettingsItem(
                icon: PhosphorIcons.chatCircleDots(),
                label: loc.coachTitle,
                // Same rule as the Home card: free accounts get the paywall,
                // not the chat and not an error.
                onTap: () => context.push(
                  sub.loaded && sub.isPro ? '/coach' : '/paywall',
                ),
              ),
              _SettingsItem(
                icon: PhosphorIcons.crown(),
                label: loc.profileSettingPro,
                onTap: () => context.push('/paywall'),
              ),
              _SettingsItem(
                icon: PhosphorIcons.fileText(),
                label: loc.profileSettingPrivacy,
                onTap: () => _openUrl(LegalUrls.privacyPolicy),
              ),
              _SettingsItem(
                icon: PhosphorIcons.scroll(),
                label: loc.profileSettingTerms,
                onTap: () => _openUrl(LegalUrls.termsOfService),
              ),
              _SettingsItem(
                icon: PhosphorIcons.signOut(),
                label: loc.profileSettingLogout,
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextButton(
            onPressed: () => _confirmDeleteAccount(context, ref),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              loc.profileDeleteAccount,
              style: SalamatDarkType.style(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: sc.err,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          loc.profileDeleteDialogTitle,
          style: SalamatDarkType.style(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: sc.text,
          ),
        ),
        content: Text(
          loc.profileDeleteDialogBody,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: sc.text2,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              loc.buttonCancel,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sc.text2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              loc.profileDeleteConfirm,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: sc.err,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Block interaction while the server-side delete runs.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>  Center(
        child: CircularProgressIndicator(color: sc.primaryInk),
      ),
    );

    final ok = await SupabaseService.deleteAccount();
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss the progress spinner

    if (ok) {
      OnboardingFlag.clear();
      ref.invalidate(userProvider);
      ref.invalidate(mealsProvider);
      ref.invalidate(subscriptionProvider);
      context.go('/onboarding/welcome');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: sc.err,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            loc.profileDeleteError,
            style: SalamatDarkType.style(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: sc.surface,
            ),
          ),
        ),
      );
    }
  }


  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _logout(BuildContext context, WidgetRef ref) {
    // Clear the local flag too — otherwise the next launch would route a
    // logged-out user straight to an empty dashboard.
    OnboardingFlag.clear();
    ref.invalidate(userProvider);
    ref.invalidate(mealsProvider);
    ref.invalidate(subscriptionProvider);
    context.go('/onboarding/welcome');
  }
}

class _LanguageRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final isRu = locale.languageCode == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        border: Border.all(color: sc.line),
      ),
      child: Row(
        children: [
          SalamatIcon(
            PhosphorIcons.globe(),
            size: 20,
            color: sc.text3,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.profileSettingLanguage,
              style: SalamatDarkType.style(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: sc.text,
              ),
            ),
          ),
          _LangPill(
            label: loc.languageRu,
            selected: isRu,
            onTap: () =>
                ref.read(localeProvider.notifier).setLocale(const Locale('ru')),
          ),
          const SizedBox(width: 6),
          _LangPill(
            label: loc.languageEn,
            selected: !isRu,
            onTap: () =>
                ref.read(localeProvider.notifier).setLocale(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? sc.primaryInk : sc.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: SalamatDarkType.style(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? sc.surface : sc.primaryInk,
          ),
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label, required this.isPro});

  final String label;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final bg = isPro ? sc.surface2 : sc.bg;
    final fg = isPro ? sc.primaryInk : sc.text3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isPro ? null : Border.all(color: sc.line),
      ),
      child: Text(
        label,
        style: SalamatDarkType.style(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
        border: Border.all(color: sc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: SalamatDarkType.style(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: sc.text,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: SalamatDarkType.style(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: sc.text3,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.user});

  final UserState user;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    String num(int? v, String unit) =>
        v == null ? loc.valueDash : '$v $unit';
    final rows = <(String, String)>[
      (
        loc.profileDataAge,
        user.age == null ? loc.valueDash : loc.profileDataAgeValue(user.age!),
      ),
      (loc.profileDataHeight, num(user.height?.round(), loc.profileDataCmUnit)),
      (loc.profileDataWeight, num(user.weight?.round(), loc.profileDataKgUnit)),
      (loc.profileDataGoal, user.goal?.label(loc) ?? loc.valueDash),
      (
        loc.profileDataCalorieNorm,
        num(user.calorieNorm, loc.profileDataKcalUnit),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        border: Border.all(color: sc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.profileDataTitle,
            style: SalamatDarkType.style(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: sc.text,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].$1,
                  style: SalamatDarkType.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: sc.text3,
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: SalamatDarkType.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sc.text,
                  ),
                ),
              ],
            ),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        border: Border.all(color: sc.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: items[i].onTap,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(18) : Radius.zero,
                bottom: i == items.length - 1
                    ? const Radius.circular(18)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    SalamatIcon(
                      items[i].icon,
                      size: 20,
                      color: sc.text3,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: SalamatDarkType.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: sc.text,
                        ),
                      ),
                    ),
                     Icon(
                      Icons.chevron_right_rounded,
                      color: sc.text3,
                    ),
                  ],
                ),
              ),
            ),
            if (i != items.length - 1)
              Container(
                height: 1,
                color: sc.line,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
          ],
        ],
      ),
    );
  }
}
