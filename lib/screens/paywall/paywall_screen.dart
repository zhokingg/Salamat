import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/user_provider.dart';
import '../../services/currency.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/elevation.dart';
import '../../theme/text_styles.dart';

enum _Tier { month1, month3, year }

String _tierLabel(AppLocalizations loc, _Tier t) => switch (t) {
      _Tier.month1 => loc.paywallTier1mo,
      _Tier.month3 => loc.paywallTier3mo,
      _Tier.year => loc.paywallTier12mo,
    };

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Tier _selected = _Tier.year;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  void _purchase() {
    // TODO(iap): wire real purchase flow once StoreKit/Play Billing is integrated.
    // For now the same stub snackbar the previous paywall used.
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SalamatColors.g1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.paywallStub,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
          ),
        ),
      ),
    );
  }

  void _restore() {
    // TODO(iap): call store restore-purchases API.
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SalamatColors.i2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          loc.paywallStub,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
          ),
        ),
      ),
    );
  }

  // Mirrors the date math in plan_ready_screen so the urgency line and the
  // plan screen agree on the target date.
  ({int weight, DateTime date}) _targetSnapshot(UserState u) {
    final delta = u.weightDelta.abs();
    final weeks = delta <= 0 ? 8 : (delta * 2).round().clamp(4, 52);
    final date = DateTime.now().add(Duration(days: weeks * 7));
    return (weight: u.targetWeight?.round() ?? 65, date: date);
  }

  String _formatDate(DateTime d, AppLocalizations loc) {
    const ru = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final isRu = loc.localeName.startsWith('ru');
    final m = (isRu ? ru : en)[d.month - 1];
    return '${d.day} $m';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final t = _targetSnapshot(user);
    final prices = pricesFor(user.country);

    return Scaffold(
      backgroundColor: SalamatColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SalamatElevation.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _HeaderRow(onClose: _close, onRestore: _restore),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const _Hero(),
                    const SizedBox(height: 28),
                    _Headline(text: loc.paywallHeroHeadline),
                    const SizedBox(height: 10),
                    _UrgencyLine(
                      text: loc.paywallUrgencyLine(
                        t.weight,
                        _formatDate(t.date, loc),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TierRow(
                      selected: _selected,
                      prices: prices,
                      onSelect: (t) => setState(() => _selected = t),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _BottomBar(
                onContinue: _purchase,
                trustLine: loc.paywallTrustLine,
                finePrint: loc.paywallFinePrint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.onClose, required this.onRestore});

  final VoidCallback onClose;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              LucideIcons.x,
              color: SalamatColors.i2,
              size: 22,
            ),
            splashRadius: 22,
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRestore,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              child: Text(
                loc.paywallRestore,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SalamatColors.i2,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — stylized "AI recognized your meal" card
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SalamatDims.screenPadding,
      ),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(SalamatElevation.cardRadius + 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft on-brand background gradient.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [SalamatColors.g3, SalamatColors.g4],
                  ),
                ),
              ),
              // Decorative blur circle top-right.
              const Positioned(
                top: -40,
                right: -30,
                child: _Blob(size: 160, color: Color(0x33C9E4D4)),
              ),
              const Positioned(
                bottom: -50,
                left: -30,
                child: _Blob(size: 140, color: Color(0x22A1C9B0)),
              ),
              // Centered mock card.
              Center(
                child: _RecognizedMealCard(
                  eyebrow: loc.paywallScanEyebrow,
                  name: loc.paywallScanMeal,
                  kcal: loc.paywallScanKcal(490),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _RecognizedMealCard extends StatelessWidget {
  const _RecognizedMealCard({
    required this.eyebrow,
    required this.name,
    required this.kcal,
  });

  final String eyebrow;
  final String name;
  final String kcal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(20),
        boxShadow: SalamatElevation.selectedCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: SalamatColors.g1,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: SalamatColors.surf,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: SalamatColors.g1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Food puck — solid tint with a lucide utensils glyph instead of
          // an emoji. Keeps the "premium UI affordance" feel.
          Center(
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SalamatColors.g4, Color(0xFFD8E8DC)],
                ),
                shape: BoxShape.circle,
                boxShadow: SalamatElevation.card,
              ),
              child: const Icon(
                LucideIcons.utensils,
                size: 30,
                color: SalamatColors.g1,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.04, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: SalamatColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kcal,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SalamatColors.g1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Headline + urgency
// ---------------------------------------------------------------------------

class _Headline extends StatelessWidget {
  const _Headline({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SalamatDims.screenPadding,
      ),
      child: Text(
        text,
        style: SalamatText.h2,
      ).animate().fadeIn(delay: 150.ms, duration: 380.ms).moveY(
            begin: 6,
            end: 0,
            duration: 380.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _UrgencyLine extends StatelessWidget {
  const _UrgencyLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SalamatDims.screenPadding,
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SalamatColors.g1.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.target,
              size: 11,
              color: SalamatColors.g1,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SalamatColors.i2,
                height: 1.35,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 220.ms, duration: 380.ms),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier row
// ---------------------------------------------------------------------------

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.selected,
    required this.prices,
    required this.onSelect,
  });

  final _Tier selected;
  final PaywallPrices prices;
  final ValueChanged<_Tier> onSelect;

  // Display order: 1 month / 12 months (popular, centered) / 3 months
  static const _order = [_Tier.month1, _Tier.year, _Tier.month3];

  /// Build one card's content for the given tier from the active price set.
  ({
    String main,
    String sub,
    bool popular,
    int? discount,
  }) _spec(_Tier t) {
    switch (t) {
      case _Tier.month1:
        return (
          main: prices.oneMonth,
          sub: '',
          popular: false,
          discount: null,
        );
      case _Tier.year:
        // Annual: total big, per-month equivalent small (per spec).
        return (
          main: prices.twelveMonths,
          sub: prices.twelveMonthsPerMo,
          popular: true,
          discount: 58,
        );
      case _Tier.month3:
        // 3-month: total big, per-month equivalent small (matches annual).
        return (
          main: prices.threeMonths,
          sub: prices.threeMonthsPerMo,
          popular: false,
          discount: 38,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SalamatDims.screenPadding,
        16,
        SalamatDims.screenPadding,
        0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _order.length; i++) ...[
              Expanded(
                child: _TierCard(
                  tier: _order[i],
                  spec: _spec(_order[i]),
                  selected: selected == _order[i],
                  onTap: () => onSelect(_order[i]),
                ).animate().fadeIn(
                      delay: (260 + i * 80).ms,
                      duration: 320.ms,
                    ).moveY(
                      begin: 6,
                      end: 0,
                      delay: (260 + i * 80).ms,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              if (i != _order.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fixed-height region that holds the Popular pill OR an empty placeholder
/// so all three cards line up at the same top edge.
const double _kPopularSlotHeight = 22;

/// Fixed-height region that holds the savings pill OR an empty placeholder.
const double _kSavingsSlotHeight = 22;

class _TierCard extends StatefulWidget {
  const _TierCard({
    required this.tier,
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _Tier tier;
  final ({String main, String sub, bool popular, int? discount}) spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final selected = widget.selected;
    final spec = widget.spec;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : (selected ? 1.0 : 0.995),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          decoration: BoxDecoration(
            color: selected ? SalamatColors.g4 : SalamatColors.surf,
            borderRadius: BorderRadius.circular(SalamatElevation.tileRadius),
            border: Border.all(
              color:
                  selected ? SalamatColors.g1 : SalamatElevation.hairline,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? SalamatElevation.selectedCard
                : SalamatElevation.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Popular slot — same height on every card so eyebrow / price
              // baselines line up across the row.
              SizedBox(
                height: _kPopularSlotHeight,
                child: spec.popular
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: SalamatElevation.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: SalamatElevation.primaryButton,
                          ),
                          child: Text(
                            loc.paywallPopular.toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: SalamatColors.surf,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              Text(
                _tierLabel(loc, widget.tier),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: selected ? SalamatColors.g1 : SalamatColors.i3,
                ),
              ),
              const SizedBox(height: 8),
              // Main price (big). Annual: total. Others: per-mo.
              // Manrope doesn't include U+20B8 (₸) or every Cyrillic-script
              // currency abbreviation, so price text falls back to Roboto /
              // Noto Sans for missing glyphs — otherwise users see tofu (▯)
              // where the symbol should be.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.main,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.4,
                    height: 1.0,
                  ).copyWith(
                    fontFamilyFallback: const ['Roboto', 'Noto Sans', 'sans-serif'],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 14,
                child: spec.sub.isEmpty
                    ? Text(
                        loc.paywallPerMonthUnit,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SalamatColors.i3,
                          height: 1.0,
                        ).copyWith(
                          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'sans-serif'],
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          // Every multi-month card: big = period total,
                          // small = per-month equivalent for comparison.
                          loc.paywallPerMonthValue(spec.sub),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: SalamatColors.i3,
                            height: 1.0,
                          ).copyWith(
                            fontFamilyFallback: const ['Roboto', 'Noto Sans', 'sans-serif'],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              // Savings slot — fixed height so all card bottoms line up.
              SizedBox(
                height: _kSavingsSlotHeight,
                child: spec.discount != null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? SalamatColors.g1
                                : SalamatColors.g3,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            loc.paywallSaveBadge(spec.discount!),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? SalamatColors.surf
                                  : SalamatColors.g1,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Risk reversal row
// ---------------------------------------------------------------------------

class _NoPaymentRow extends StatelessWidget {
  const _NoPaymentRow();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SalamatColors.g1.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.check,
              size: 13,
              color: SalamatColors.g1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            loc.paywallNoPaymentNow,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar: CTA + trust + fine print
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onContinue,
    required this.trustLine,
    required this.finePrint,
  });

  final VoidCallback onContinue;
  final String trustLine;
  final String finePrint;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SalamatDims.screenPadding,
        12,
        SalamatDims.screenPadding,
        16,
      ),
      decoration: BoxDecoration(
        color: SalamatColors.bg.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: SalamatElevation.hairline.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Risk-reversal sits directly above the CTA — closest visual link
          // to the action it reassures.
          const _NoPaymentRow(),
          const SizedBox(height: 10),
          _PrimaryCta(label: loc.buttonContinue, onTap: onContinue),
          const SizedBox(height: 10),
          _TrustLine(text: trustLine),
          const SizedBox(height: 8),
          Text(
            finePrint,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: SalamatColors.i3,
            ),
          ),
          const SizedBox(height: 6),
          // Explicit clickable legal links — Play requires the Privacy
          // Policy to be reachable from within the app, not just from the
          // store listing.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegalLink(
                label: loc.paywallFinePrintPrivacy,
                url: LegalUrls.privacyPolicy,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: SalamatColors.i3,
                  ),
                ),
              ),
              _LegalLink(
                label: loc.paywallFinePrintTerms,
                url: LegalUrls.termsOfService,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SalamatColors.i2,
          decoration: TextDecoration.underline,
          decorationColor: SalamatColors.i3,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: SalamatDims.buttonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: SalamatElevation.primaryGradient,
            borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
            boxShadow: SalamatElevation.primaryButton,
          ),
          child: Text(widget.label, style: SalamatText.btn),
        ),
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          LucideIcons.users,
          size: 12,
          color: SalamatColors.i3,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: SalamatColors.i3,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
