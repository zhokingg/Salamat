import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/bootstrap_provider.dart';
import '../../services/onboarding_flag.dart';
import '../../theme/salamat_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
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

    // The local flag decides the route for returning users — a dead network
    // must never bounce them back into onboarding.
    OnboardingFlag.isCompleted().then((v) {
      if (!mounted) return;
      _onboardedLocally = v;
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
      _onboardedLocally ??= await OnboardingFlag.isCompleted()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      _goNext();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kick off bootstrap (init + anonymous sign-in) then the profile load, and
    // react when it settles. profileProvider transitively starts bootstrap.
    ref.listen(profileProvider, (_, __) => _tryNavigate());
    ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: SalamatTokens.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LeafIcon(size: 88),
              const SizedBox(height: 20),
              Text(
                'Salamat',
                style: GoogleFonts.manrope(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: SalamatTokens.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: SalamatTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeafIcon extends StatelessWidget {
  const _LeafIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LeafPainter()),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SalamatTokens.accent
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.95, h * 0.25, w * 0.95, h * 0.75, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.05, h * 0.75, w * 0.05, h * 0.25, w * 0.5, h * 0.08)
      ..close();

    canvas.drawPath(path, paint);

    final vein = Paint()
      ..color = SalamatTokens.background
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.18),
      Offset(w * 0.5, h * 0.85),
      vein,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
