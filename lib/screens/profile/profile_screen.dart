import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/locale_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/onboarding_flag.dart';
import '../../services/supabase_service.dart';
import '../../widgets/update_weight_dialog.dart';
import '../../theme/colors.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import '../../theme/dimensions.dart';

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
    final initials = user.initials;

    final entriesCount =
        MealType.values.expand((t) => meals.forType(t)).length;

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDims.tabBarHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Text(
            loc.profileTitle,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: SalamatColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SalamatColors.g1,
              shape: BoxShape.circle,
            ),
            child: initials.isEmpty
                ? SalamatIcon(
                    PhosphorIcons.user(PhosphorIconsStyle.duotone),
                    size: 32,
                    color: SalamatColors.surf,
                  )
                : Text(
                    initials,
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: SalamatColors.surf,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                fullName,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: SalamatColors.ink,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _PlanBadge(
              label: sub.isPro ? loc.profileBadgePro : loc.profileBadgeFree,
              isPro: sub.isPro,
            ),
          ],
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
              _SettingsItem(
                icon: PhosphorIcons.bell(),
                label: loc.profileSettingNotifications,
                onTap: () =>
                    _showSoon(context, loc.profileSettingNotifications),
              ),
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
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: SalamatColors.danger,
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
        backgroundColor: SalamatColors.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          loc.profileDeleteDialogTitle,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SalamatColors.ink,
          ),
        ),
        content: Text(
          loc.profileDeleteDialogBody,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: SalamatColors.i2,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              loc.buttonCancel,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SalamatColors.i2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              loc.profileDeleteConfirm,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalamatColors.danger,
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
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: SalamatColors.g1),
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
          backgroundColor: SalamatColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            loc.profileDeleteError,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SalamatColors.surf,
            ),
          ),
        ),
      );
    }
  }

  void _showSoon(BuildContext context, String label) {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SalamatColors.g1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.profileSoonSuffix(label),
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
          ),
        ),
      ),
    );
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
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Row(
        children: [
          SalamatIcon(
            PhosphorIcons.globe(),
            size: 20,
            color: SalamatTokens.iconQuiet,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.profileSettingLanguage,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SalamatColors.ink,
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
          color: selected ? SalamatColors.g1 : SalamatColors.g4,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? SalamatColors.surf : SalamatColors.g1,
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
    final bg = isPro ? SalamatColors.g4 : SalamatColors.bg;
    final fg = isPro ? SalamatColors.g1 : SalamatColors.i3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isPro ? null : Border.all(color: SalamatColors.line),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
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
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SalamatColors.ink,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: SalamatColors.i3,
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
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.profileDataTitle,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].$1,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: SalamatColors.i3,
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.ink,
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
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatColors.line),
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
                      color: SalamatTokens.iconQuiet,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SalamatColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: SalamatColors.i3,
                    ),
                  ],
                ),
              ),
            ),
            if (i != items.length - 1)
              Container(
                height: 1,
                color: SalamatColors.line,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
          ],
        ],
      ),
    );
  }
}
