import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../providers/subscription_provider.dart';
import '../screens/manual_entry/photo_limit_sheet.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/salamat_dark.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({super.key, required this.navigationShell});

  /// The four tab branches, kept alive in an IndexedStack by
  /// `StatefulShellRoute.indexedStack`. Switching tabs goes through
  /// [StatefulNavigationShell.goBranch], which swaps the visible index instead
  /// of pushing a route — no rebuild, no transition, no two headers at once.
  final StatefulNavigationShell navigationShell;

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
      icon: PhosphorIcons.forkKnife(),
      path: '/meals',
      labelKey: _NavLabel.meals,
    ),
    _TabItem(
      icon: PhosphorIcons.chartLineUp(),
      path: '/progress',
      labelKey: _NavLabel.progress,
    ),
    _TabItem(
      icon: PhosphorIcons.user(),
      path: '/profile',
      labelKey: _NavLabel.profile,
    ),
  ];

  void _onCameraPressed(BuildContext context, WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    if (sub.canTakePhoto) {
      context.push('/camera');
    } else {
      // Lifetime free allowance spent: offer manual logging first, Pro second.
      showPhotoLimitSheet(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final loc = AppLocalizations.of(context)!;
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: sc.bg,
      body: navigationShell,
      bottomNavigationBar: _TabBar(
        index: index,
        tabs: _tabs,
        // `initialLocation: true` on a re-tap pops that branch back to its
        // root, which is the behaviour people expect from a tab bar.
        onTab: (i) => navigationShell.goBranch(i, initialLocation: i == index),
        // Remaining free scans, readable from the very first screen. Null for
        // Pro, and until the server has answered once.
        counter:
            (sub.loaded && !sub.isPro)
                ? loc.scansLeftOf(sub.scansLeft, sub.allowance)
                : null,
        counterSpent: sub.scansLeft == 0,
        onCamera: () => _onCameraPressed(context, ref),
      ),
    );
  }
}

enum _NavLabel { home, meals, progress, profile }

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
        _NavLabel.meals => loc.navMeals,
        _NavLabel.progress => loc.navProgress,
        _NavLabel.profile => loc.navProfile,
      };
}

/// Bottom navigation, repainted to the prototype: a flat `--surface` strip
/// 94px tall with a 1px `--line` top border and a `0 -8px 30px` lift, four
/// 62px-wide tabs (21px icon over a 10/500 label) and the camera FAB
/// overhanging the strip by 18px.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.tabs,
    required this.onTab,
    required this.onCamera,
    this.counter,
    this.counterSpent = false,
  });

  final int index;
  final List<_TabItem> tabs;
  final void Function(int) onTab;
  final VoidCallback onCamera;

  /// "2 of 3 left", or null when there is nothing to count.
  final String? counter;
  final bool counterSpent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: SalamatDarkDims.navHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left: SalamatDarkDims.gap8,
              right: SalamatDarkDims.gap8,
              top: SalamatDarkDims.gap10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tabButton(context, 0),
                _tabButton(context, 1),
                // Camera is an ACTION slot, not a tab: geometrically centered,
                // opens over the current tab and never becomes "selected".
                _CameraFab(
                  onTap: onCamera,
                  counter: counter,
                  counterSpent: counterSpent,
                ),
                _tabButton(context, 2),
                _tabButton(context, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, int i) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final tab = tabs[i];
    final selected = i == index;
    final color = selected ? c.primary : c.text3;
    return SizedBox(
      width: SalamatDarkDims.navTabWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTab(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(tab.icon, color: color, size: SalamatDarkDims.navIcon),
            const SizedBox(height: SalamatDarkDims.gap4),
            Text(
              tab.label(loc),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SalamatDarkType.tab.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// 58px circular FAB on a `primary -> accent` gradient, lifted 18px above the
/// nav strip, carrying `--shadow-2`.
class _CameraFab extends StatelessWidget {
  const _CameraFab({
    required this.onTap,
    this.counter,
    this.counterSpent = false,
  });

  final VoidCallback onTap;

  /// "2 of 3 left" — rendered where the other tabs put their label, so the
  /// remaining scans read from the first screen without covering any content
  /// and without colliding with the button itself.
  final String? counter;
  final bool counterSpent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final button = Transform.translate(
      offset: const Offset(0, -SalamatDarkDims.fabOverlap),
      child: Semantics(
        button: true,
        label: loc.navCameraAction,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: SalamatDarkDims.fabSize,
            height: SalamatDarkDims.fabSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                // CSS 150deg.
                begin: const Alignment(-0.5, -1),
                end: const Alignment(0.5, 1),
                colors: [c.primary, c.accent],
              ),
              boxShadow: c.shadow2,
            ),
            child: PhosphorIcon(
              PhosphorIcons.camera(),
              size: SalamatDarkDims.fabIcon,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );

    if (counter == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        // Pulled up by the same overlap the button was pushed by, so the label
        // lands on the tab-label baseline instead of below the strip.
        Transform.translate(
          offset: const Offset(0, -SalamatDarkDims.fabOverlap + 2),
          child: Text(
            counter!,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: SalamatDarkType.style(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: counterSpent ? c.err : c.text3,
            ),
          ),
        ),
      ],
    );
  }
}
