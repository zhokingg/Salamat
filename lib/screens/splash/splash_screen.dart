import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/bootstrap_provider.dart';
import '../../services/onboarding_flag.dart';
import '../../theme/salamat_dark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final AnimationController _pulseCtl;
  late final Animation<double> _pulse;
  Timer? _minTimer;
  Timer? _maxTimer;
  bool _minElapsed = false;
  bool _navigated = false;

  /// Local onboarding flag, loaded at startup. Null until the prefs read
  /// completes (it's local storage — effectively instant).
  bool? _onboardedLocally;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    // vBreathe: 4s, ease-in-out, infinite alternate.
    _pulseCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtl, curve: Curves.easeInOut);

    // The local flag decides the route for returning users — a dead network
    // must never bounce them back into onboarding.
    OnboardingFlag.isCompleted().then((v) {
      if (!mounted) return;
      _onboardedLocally = v;
      _tryNavigate();
    }).catchError((_) {
      // Prefs threw (e.g. MissingPluginException on a broken plugin
      // registration) — treat as not-onboarded rather than trapping the
      // splash forever with a null flag.
      if (!mounted) return;
      _onboardedLocally = false;
      _tryNavigate();
    });

    // Hold the brand for a minimum, then proceed as soon as we can decide.
    _minTimer = Timer(const Duration(seconds: 2), () {
      _minElapsed = true;
      _tryNavigate();
    });
    // Safety net: never trap the user on splash if the network hangs.
    // The net itself must be flag-aware: on a slow cold start it can fire
    // before the prefs read resolves, and deciding with a null flag would
    // bounce a returning user into onboarding.
    _maxTimer = Timer(const Duration(seconds: 8), () async {
      // Escape hatch must survive ANYTHING: .timeout covers a hang, the
      // try/catch covers a throw (a thrown exception sails straight through
      // .timeout), and finally guarantees we always leave the splash.
      try {
        _onboardedLocally ??= await OnboardingFlag.isCompleted()
            .timeout(const Duration(seconds: 2), onTimeout: () => false);
      } catch (_) {
        _onboardedLocally ??= false;
      } finally {
        _goNext();
      }
    });
  }

  /// Navigate once the minimum splash time has elapsed AND we can decide:
  ///  - local flag says onboarded → dashboard immediately, no network wait
  ///    (profileProvider keeps syncing in the background and hydrates
  ///    [userProvider] whenever it lands);
  ///  - local flag says not onboarded → wait for the profile load to settle,
  ///    because a reinstall may still have a server-side profile.
  void _tryNavigate() {
    if (!_minElapsed || _onboardedLocally == null) return;
    if (_onboardedLocally == true) {
      _goNext();
      return;
    }
    final profile = ref.read(profileProvider);
    if (profile.hasValue || profile.hasError) _goNext();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    final row = ref.read(profileProvider).valueOrNull;
    if (_onboardedLocally == true || isProfileOnboarded(row)) {
      // Returning user. Hydration + local-flag backfill for the server-row
      // case happen inside profileProvider.
      context.go('/dashboard');
    } else {
      context.go('/onboarding/welcome');
    }
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _maxTimer?.cancel();
    _controller.dispose();
    _pulseCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kick off bootstrap (init + anonymous sign-in) then the profile load, and
    // react when it settles. profileProvider transitively starts bootstrap.
    ref.listen(profileProvider, (_, __) => _tryNavigate());
    ref.watch(profileProvider);
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prototype: 112x112 tile, radius 34, breathing
              // primary -> accent -> secondary gradient with a white leaf.
              _BrandTile(pulse: _pulse),
              const SizedBox(height: SalamatDarkDims.gap26),
              Text(
                loc.appName,
                style: SalamatDarkType.logo.copyWith(color: c.text),
              ),
              const SizedBox(height: SalamatDarkDims.gap8),
              Text(
                loc.splashTagline.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: SalamatDarkType.medium,
                  letterSpacing: 0.14 * 14,
                  color: c.text2,
                ),
              ),
              const SizedBox(height: SalamatDarkDims.gap26),
              // No prototype analog: the prototype's splash is a static brand
              // screen, this one waits on bootstrap and needs a busy hint.
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: c.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient brand tile from the prototype splash. `vBreathe`: opacity
/// 0.5 -> 1 and scale 1 -> 1.05 over 4s, ease-in-out, infinite.
class _BrandTile extends StatelessWidget {
  const _BrandTile({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: SalamatDarkDims.splashTile,
      height: SalamatDarkDims.splashTile,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Opacity(
              opacity: 0.5 + 0.5 * pulse.value,
              child: Transform.scale(
                scale: 1 + 0.05 * pulse.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rSplashTile),
                    gradient: LinearGradient(
                      // CSS 150deg.
                      begin: const Alignment(-0.5, -1),
                      end: const Alignment(0.5, 1),
                      colors: [c.primary, c.accent, c.secondary],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PhosphorIcon(
            PhosphorIcons.leaf(),
            size: SalamatDarkDims.splashIcon,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
