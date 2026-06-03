import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../providers/subscription_provider.dart';
import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/text_styles.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  // Tabs carry the icon + path as data; the label is resolved per-locale
  // from AppLocalizations at render time (was previously hardcoded English).
  static const List<_TabItem> _tabs = [
    _TabItem(icon: Icons.home_rounded, path: '/dashboard', labelKey: _NavLabel.home),
    _TabItem(icon: Icons.search_rounded, path: '/search', labelKey: _NavLabel.search),
    _TabItem(icon: Icons.bar_chart_rounded, path: '/progress', labelKey: _NavLabel.progress),
    _TabItem(icon: Icons.person_rounded, path: '/profile', labelKey: _NavLabel.profile),
  ];

  int _currentIndex(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  void _onFabPressed(BuildContext context, WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    if (sub.canTakePhoto) {
      context.push('/camera');
    } else {
      context.push('/paywall');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _currentIndex(location);

    return Scaffold(
      backgroundColor: SalamatColors.bg,
      body: child,
      floatingActionButton: SizedBox(
        width: SalamatDims.fabSize,
        height: SalamatDims.fabSize,
        child: FloatingActionButton(
          backgroundColor: SalamatColors.g1,
          elevation: 0,
          shape: const CircleBorder(),
          onPressed: () => _onFabPressed(context, ref),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: SalamatColors.surf,
            size: 26,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _TabBar(index: index, tabs: _tabs),
    );
  }
}

enum _NavLabel { home, search, progress, profile }

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.path,
    required this.labelKey,
  });
  final IconData icon;
  final String path;
  final _NavLabel labelKey;

  String label(AppLocalizations loc) => switch (labelKey) {
        _NavLabel.home => loc.navHome,
        _NavLabel.search => loc.navSearch,
        _NavLabel.progress => loc.navProgress,
        _NavLabel.profile => loc.navProfile,
      };
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.tabs});

  final int index;
  final List<_TabItem> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SalamatDims.tabBarHeight,
      decoration: const BoxDecoration(
        color: SalamatColors.surf,
        border: Border(top: BorderSide(color: SalamatColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _tabButton(context, 0),
            _tabButton(context, 1),
            const SizedBox(width: 72),
            _tabButton(context, 2),
            _tabButton(context, 3),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, int i) {
    final loc = AppLocalizations.of(context)!;
    final tab = tabs[i];
    final selected = i == index;
    final color = selected ? SalamatColors.g1 : SalamatColors.i3;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(tab.path),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              tab.label(loc),
              style: SalamatText.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
