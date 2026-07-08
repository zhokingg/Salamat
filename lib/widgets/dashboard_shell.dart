import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../providers/subscription_provider.dart';
import '../screens/manual_entry/photo_limit_sheet.dart';
import '../theme/dimensions.dart';
import '../theme/salamat_icons.dart';
import '../theme/salamat_theme.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  // Tabs carry the icon + path as data; the label is resolved per-locale
  // from AppLocalizations at render time (was previously hardcoded English).
  // Navigation icons use the Regular Phosphor weight per the icon system.
  static final List<_TabItem> _tabs = [
    _TabItem(
      icon: PhosphorIcons.house(),
      path: '/dashboard',
      labelKey: _NavLabel.home,
    ),
    _TabItem(
      icon: PhosphorIcons.chartBar(),
      path: '/progress',
      labelKey: _NavLabel.progress,
    ),
    _TabItem(
      icon: PhosphorIcons.user(),
      path: '/profile',
      labelKey: _NavLabel.profile,
    ),
  ];

  int _currentIndex(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _onCameraPressed(BuildContext context, WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    if (sub.canTakePhoto) {
      context.push('/camera');
    } else {
      // Free daily scan spent: offer manual logging first, Pro second.
      showPhotoLimitSheet(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _currentIndex(location);

    return Scaffold(
      backgroundColor: SalamatTokens.background,
      body: child,
      bottomNavigationBar: _TabBar(
        index: index,
        tabs: _tabs,
        onCamera: () => _onCameraPressed(context, ref),
      ),
    );
  }
}

enum _NavLabel { home, progress, profile }

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.path,
    required this.labelKey,
  });
  final PhosphorIconData icon;
  final String path;
  final _NavLabel labelKey;

  String label(AppLocalizations loc) => switch (labelKey) {
        _NavLabel.home => loc.navHome,
        _NavLabel.progress => loc.navProgress,
        _NavLabel.profile => loc.navProfile,
      };
}

/// Floating pill navigation: transparent strip hosting a borderless cream
/// pill — depth comes from the color layer on the sage canvas.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.tabs,
    required this.onCamera,
  });

  final int index;
  final List<_TabItem> tabs;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SalamatDims.tabBarHeight,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: SalamatTokens.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _tabButton(context, 0),
              // Camera is an ACTION slot, not a tab: it opens the camera on
              // top of the current tab and never becomes "selected".
              Expanded(child: _CameraButton(onTap: onCamera)),
              _tabButton(context, 1),
              _tabButton(context, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, int i) {
    final loc = AppLocalizations.of(context)!;
    final tab = tabs[i];
    final selected = i == index;
    final color =
        selected ? SalamatTokens.accentDeep : SalamatTokens.iconQuiet;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(tab.path),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SalamatIcon(tab.icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              tab.label(loc),
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Round accentDeep camera action in the nav pill — ~20% larger than the
/// neighbouring tab icons to read as the primary action.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SalamatTokens.accentDeep,
            shape: BoxShape.circle,
          ),
          child: SalamatIcon(
            PhosphorIcons.camera(PhosphorIconsStyle.duotone),
            size: 24,
            color: SalamatTokens.onAccent,
          ),
        ),
      ),
    );
  }
}
