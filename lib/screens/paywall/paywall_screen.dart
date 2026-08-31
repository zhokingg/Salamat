import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/user_provider.dart';
import '../../services/purchases_service.dart';
import '../../theme/salamat_dark.dart';

enum _Tier { month1, year }

/// What the primary button is currently for.
///
/// Split out so the error case is a first-class state rather than a disabled
/// button: prices failing to load must not strand the user on a screen whose
/// only action is greyed out.
enum _PaywallCtaState { trial, plain, error }

/// A free trial actually offered by the store product.
///
/// Never inferred and never assumed: if the store does not report an
/// introductory free phase, there is no trial and the UI must not imply one.
class _Trial {
  const _Trial({
    required this.unit,
    required this.count,
    required this.firstChargePrice,
  });

  final PeriodUnit unit;
  final int count;

  /// The recurring price the user pays once the trial ends, formatted by the
  /// store in the local currency.
  final String firstChargePrice;

  /// When the first charge lands, counted from now with the trial length.
  DateTime get firstChargeDate {
    final now = DateTime.now();
    return switch (unit) {
      PeriodUnit.day => now.add(Duration(days: count)),
      PeriodUnit.week => now.add(Duration(days: 7 * count)),
      PeriodUnit.month => DateTime(now.year, now.month + count, now.day),
      PeriodUnit.year => DateTime(now.year + count, now.month, now.day),
      PeriodUnit.unknown => now,
    };
  }

  String label(AppLocalizations loc) => switch (unit) {
        PeriodUnit.day => loc.paywallPeriodDays(count),
        PeriodUnit.week => loc.paywallPeriodWeeks(count),
        PeriodUnit.month => loc.paywallPeriodMonths(count),
        PeriodUnit.year => loc.paywallPeriodYears(count),
        // An unrecognised unit is not describable, so it is not a trial we
        // are willing to advertise.
        PeriodUnit.unknown => '',
      };

  bool get isDescribable => unit != PeriodUnit.unknown && count > 0;
}

/// Reads a free trial off a store product.
///
/// Android exposes it as the `freePhase` of the default subscription option;
/// iOS as an `introductoryPrice` whose price is zero. Anything else — a
/// discounted intro, a paid upfront phase — is deliberately NOT treated as a
/// free trial.
_Trial? _trialOf(StoreProduct product) {
  final free = product.defaultOption?.freePhase;
  if (free != null) {
    final period = free.billingPeriod;
    // Guard the price too: a "free phase" that costs money is not free.
    if (period != null && free.price.amountMicros == 0) {
      return _Trial(
        unit: period.unit,
        count: period.value,
        firstChargePrice: product.priceString,
      );
    }
  }
  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0) {
    return _Trial(
      unit: intro.periodUnit,
      count: intro.periodNumberOfUnits,
      firstChargePrice: product.priceString,
    );
  }
  return null;
}

/// Card content resolved from a store package — prices, currency and trial
/// come from the store via RevenueCat, never from hardcoded tables.
class _TierData {
  const _TierData({
    required this.price,
    required this.perMonth,
    required this.discount,
    required this.trial,
    required this.package,
  });

  /// Store-formatted recurring price, e.g. "3 490 сом".
  final String price;

  /// Per-month equivalent, annual tier only. Null when not applicable.
  final String? perMonth;

  final int? discount;
  final _Trial? trial;
  final Package package;
}

String _tierLabel(AppLocalizations loc, _Tier t) => switch (t) {
      _Tier.month1 => loc.paywallTier1mo,
      _Tier.year => loc.paywallTier12mo,
    };

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Tier _selected = _Tier.year;

  bool _loading = true;
  bool _loadError = false;
  bool _purchasing = false;
  Map<_Tier, _TierData> _tiers = const {};

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  /// Anchors the offerings-error card so it can be scrolled into view.
  final GlobalKey _errorKey = GlobalKey();

  /// Scrolls the offerings-error card fully into view.
  ///
  /// The bottom bar does not overlap the list — they are siblings in a Column
  /// — but in the error state the content is a little taller than the viewport,
  /// so the card explaining WHY there are no prices lands half below the fold
  /// and reads as truncated. The one thing the user needs to read is the one
  /// thing they cannot see, so bring it to them.
  void _revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _errorKey.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _loading = true;
      _loadError = false;
    });
    if (!PurchasesService.isReady) {
      // No key configured or SDK failed to start (e.g. offline at boot).
      setState(() {
        _loading = false;
        _loadError = true;
      });
      _revealError();
      return;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      final annual = offering?.annual;
      final monthly = offering?.monthly;
      if (annual == null || monthly == null) {
        throw StateError('current offering is missing annual/monthly');
      }
      final annualPrice = annual.storeProduct.price;
      final monthlyPrice = monthly.storeProduct.price;
      final currency = annual.storeProduct.currencyCode;
      final perMonth = NumberFormat.simpleCurrency(name: currency)
          .format(annualPrice / 12);
      final discount = monthlyPrice > 0
          ? (100 - annualPrice / (monthlyPrice * 12) * 100).round()
          : null;
      setState(() {
        _tiers = {
          _Tier.year: _TierData(
            price: annual.storeProduct.priceString,
            perMonth: perMonth,
            discount: (discount != null && discount > 0) ? discount : null,
            trial: _trialOf(annual.storeProduct),
            package: annual,
          ),
          _Tier.month1: _TierData(
            price: monthly.storeProduct.priceString,
            perMonth: null,
            discount: null,
            trial: _trialOf(monthly.storeProduct),
            package: monthly,
          ),
        };
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
        _revealError();
      }
    }
  }

  void _snack(String text, {Color? bg, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg ?? sc.primaryInk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        content: Text(
          text,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sc.surface,
          ),
        ),
      ),
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  Future<void> _purchase() async {
    final loc = AppLocalizations.of(context)!;
    final tier = _tiers[_selected];
    if (tier == null || _purchasing) return;
    setState(() => _purchasing = true);
    try {
      // purchases_flutter 8.x returns CustomerInfo directly.
      final info = await Purchases.purchasePackage(tier.package);
      if (!mounted) return;
      if (PurchasesService.hasPro(info)) {
        _snack(loc.paywallWelcomePro);
        _close();
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _snack(
          loc.paywallPurchaseError,
          bg: sc.err,
          action: SnackBarAction(
            label: loc.retryButton,
            textColor: sc.surface,
            onPressed: _purchase,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    final loc = AppLocalizations.of(context)!;
    if (!PurchasesService.isReady) {
      _snack(loc.paywallRestoreNotFound, bg: sc.text2);
      return;
    }
    try {
      final info = await Purchases.restorePurchases();
      if (!mounted) return;
      if (PurchasesService.hasPro(info)) {
        _snack(loc.paywallRestoreFound);
        _close();
      } else {
        _snack(loc.paywallRestoreNotFound, bg: sc.text2);
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      _snack(
        loc.paywallPurchaseError,
        bg: sc.err,
        action: SnackBarAction(
          label: loc.retryButton,
          textColor: sc.surface,
          onPressed: _restore,
        ),
      );
    }
  }

  /// The goal line under the headline.
  ///
  /// Deliberately says nothing about WHEN. The app cannot know when somebody
  /// will reach a weight — that depends on the rest of their life — and a
  /// promised date at the moment of payment is the worst place to pretend
  /// otherwise. The coach's system prompt is forbidden from promising a result
  /// by a date; the interface should hold to the same rule.
  ///
  /// So: the target, and the rate the PLAN is built from, described as an
  /// assumption rather than an outcome.
  String _goalLine(UserState u, AppLocalizations loc) {
    final target = u.targetWeight;
    // No target set — say something true rather than inventing a number.
    if (target == null) return loc.paywallGoalGenericLine;

    final weight = target.round();
    final delta = u.weightDelta.abs();
    if (delta <= 0) return loc.paywallGoalHoldLine(weight);

    // Same arithmetic plan_ready_screen uses, read as a rate instead of a date.
    final weeks = (delta * 2).round().clamp(4, 52);
    final pace = delta / weeks;
    final paceText = NumberFormat('0.#', loc.localeName).format(pace);
    return loc.paywallGoalPaceLine(weight, paceText);
  }


  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);

    // The trial shown on the button is the one attached to the SELECTED tier —
    // annual and monthly can differ, and promising the wrong one would be a
    // misstatement of the charge.
    final selectedTrial = _tiers[_selected]?.trial;
    final activeTrial =
        (selectedTrial != null && selectedTrial.isDescribable)
            ? selectedTrial
            : null;
    final ctaState = _loadError
        ? _PaywallCtaState.error
        : (activeTrial != null
            ? _PaywallCtaState.trial
            : _PaywallCtaState.plain);

    return Scaffold(
      backgroundColor: c.bg,
      // The prototype's paywall sits flat on `--bg`; the legacy page gradient
      // is dropped rather than re-tinted.
      body: SafeArea(
          child: Column(
            children: [
              _HeaderRow(onClose: _close, onRestore: _restore),
              Expanded(
                child: ListView(
                  // Real bottom padding rather than a trailing SizedBox: the
                  // last card must be able to scroll clear of the CTA bar.
                  padding: const EdgeInsets.only(
                    bottom: SalamatDarkDims.gap24,
                  ),
                  children: [
                    const _Hero(),
                    const SizedBox(height: 28),
                    _Headline(
                      text: switch (user.goal) {
                        Goal.gain => loc.paywallHeroHeadlineGain,
                        Goal.maintain ||
                        Goal.healthy =>
                          loc.paywallHeroHeadlineMaintain,
                        _ => loc.paywallHeroHeadlineLose,
                      },
                    ),
                    const SizedBox(height: 10),
                    _UrgencyLine(text: _goalLine(user, loc)),
                    const SizedBox(height: SalamatDarkDims.gap24),
                    // Benefits are the argument for paying, so they render in
                    // every state — including when prices failed to load.
                    const _Benefits(),
                    const SizedBox(height: SalamatDarkDims.gap16),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: c.primary),
                        ),
                      )
                    else if (_loadError)
                      _OfferingsError(key: _errorKey)
                    else
                      _TierList(
                        selected: _selected,
                        tiers: _tiers,
                        onSelect: (t) => setState(() => _selected = t),
                      ),
                  ],
                ),
              ),
              _BottomBar(
                state: ctaState,
                trial: activeTrial,
                onPrimary: _purchasing
                    ? null
                    : (_loadError
                        ? _loadOfferings
                        : (_loading ? null : _purchase)),
                finePrint: loc.paywallFinePrint,
              ),
            ],
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
            icon:  Icon(
              LucideIcons.x,
              color: sc.text2,
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
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sc.text2,
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
        horizontal: SalamatDarkDims.screenPadH,
      ),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(SalamatDarkDims.rCard + 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft on-brand background gradient.
              Container(
                decoration:  BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [sc.surface3, sc.surface2],
                  ),
                ),
              ),
              // Decorative blur circle top-right.
              const Positioned(
                top: -40,
                right: -30,
                child: _Blob(size: 160, color: Color(0x333AE07E)),
              ),
              const Positioned(
                bottom: -50,
                left: -30,
                child: _Blob(size: 140, color: Color(0x222DD4BF)),
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
        color: sc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sc.shadow2,
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
                decoration:  BoxDecoration(
                  color: sc.primaryInk,
                  shape: BoxShape.circle,
                ),
                child:  Icon(
                  LucideIcons.check,
                  size: 14,
                  color: sc.surface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                eyebrow.toUpperCase(),
                style: SalamatDarkType.style(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: sc.primaryInk,
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
                gradient:  LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [sc.surface2, sc.surface3],
                ),
                shape: BoxShape.circle,
                boxShadow: sc.shadow1,
              ),
              child: Icon(
                LucideIcons.utensils,
                size: 30,
                color: sc.primary,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.04, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(height: 12),
          Text(
            name,
            style: SalamatDarkType.style(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: sc.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kcal,
            style: SalamatDarkType.style(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: sc.primaryInk,
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
        horizontal: SalamatDarkDims.screenPadH,
      ),
      child: Text(
        text,
        style: SalamatDarkType.h1,
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
        horizontal: SalamatDarkDims.screenPadH,
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sc.primaryInk.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child:  Icon(
              LucideIcons.target,
              size: 11,
              color: sc.primaryInk,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sc.text2,
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
// Benefits — three rows from the localisation that was never rendered
// ---------------------------------------------------------------------------

/// The three value props. These strings have existed in both ARBs since the
/// paywall was written and were never put on screen; they carry the actual
/// argument for paying, so they stay visible in every state including the
/// price-load failure.
class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final rows = <({IconData icon, String title, String sub})>[
      (
        icon: LucideIcons.camera,
        title: loc.paywallFeature1Title,
        sub: loc.paywallFeature1Sub,
      ),
      (
        icon: LucideIcons.trendingUp,
        title: loc.paywallFeature2Title,
        sub: loc.paywallFeature2Sub,
      ),
      (
        icon: LucideIcons.history,
        title: loc.paywallFeature3Title,
        sub: loc.paywallFeature3Sub,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SalamatDarkDims.screenPadH,
      ),
      child: Container(
        padding: const EdgeInsets.all(SalamatDarkDims.padCardTight),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: SalamatDarkDims.gap14),
              Row(
                children: [
                  Container(
                    width: SalamatDarkDims.iconTile42,
                    height: SalamatDarkDims.iconTile42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius:
                          BorderRadius.circular(SalamatDarkDims.rIcon42),
                    ),
                    child: Icon(rows[i].icon, size: 19, color: c.primary),
                  ),
                  const SizedBox(width: SalamatDarkDims.gap14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].title,
                          style: SalamatDarkType.bodyM.copyWith(
                            color: c.text,
                            fontWeight: SalamatDarkType.semi,
                          ),
                        ),
                        const SizedBox(height: SalamatDarkDims.gap2),
                        Text(
                          rows[i].sub,
                          style:
                              SalamatDarkType.micro.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(
                    delay: (200 + i * 70).ms,
                    duration: 320.ms,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tiers — full-width rows
// ---------------------------------------------------------------------------

/// Tier selector.
///
/// Rows, not columns: `priceString` comes back store-formatted in the local
/// currency, and Central Asian amounts are long ("18 990 ₸", "479 900 сўм").
/// Side-by-side columns collapsed those to two lines or ellipsised them, so
/// each tier now owns a full-width row with the price on the trailing edge.
class _TierList extends StatelessWidget {
  const _TierList({
    required this.selected,
    required this.tiers,
    required this.onSelect,
  });

  final _Tier selected;
  final Map<_Tier, _TierData> tiers;
  final ValueChanged<_Tier> onSelect;

  // Annual first: it is the default and the better value.
  static const _order = [_Tier.year, _Tier.month1];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SalamatDarkDims.screenPadH,
        0,
        SalamatDarkDims.screenPadH,
        0,
      ),
      child: Column(
        children: [
          for (var i = 0; i < _order.length; i++) ...[
            if (i > 0) const SizedBox(height: SalamatDarkDims.gap10),
            _TierRowCard(
              tier: _order[i],
              data: tiers[_order[i]]!,
              selected: selected == _order[i],
              popular: _order[i] == _Tier.year,
              onTap: () => onSelect(_order[i]),
            ).animate().fadeIn(
                  delay: (260 + i * 80).ms,
                  duration: 320.ms,
                ),
          ],
        ],
      ),
    );
  }
}

/// One tier as a full-width row: radio, label + sub-line, price on the right.
/// Follows the prototype's plan row — radius 22, 2px border, `--surface` fill.
class _TierRowCard extends StatelessWidget {
  const _TierRowCard({
    required this.tier,
    required this.data,
    required this.selected,
    required this.popular,
    required this.onTap,
  });

  final _Tier tier;
  final _TierData data;
  final bool selected;
  final bool popular;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final trial = data.trial;
    // Sub-line priority: a real trial outranks the per-month equivalent.
    final sub = (trial != null && trial.isDescribable)
        ? loc.paywallTrialCta(trial.label(loc))
        : (data.perMonth != null
            ? loc.paywallPerMonthShort(data.perMonth!)
            : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
          border: Border.all(
            color: selected ? c.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? c.shadow1 : null,
        ),
        child: Row(
          children: [
            _Radio(selected: selected),
            const SizedBox(width: SalamatDarkDims.gap14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _tierLabel(loc, tier),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SalamatDarkType.btnS.copyWith(color: c.text),
                        ),
                      ),
                      if (popular) ...[
                        const SizedBox(width: SalamatDarkDims.gap8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(
                              SalamatDarkDims.rPill,
                            ),
                          ),
                          child: Text(
                            loc.paywallPopular.toUpperCase(),
                            style: SalamatDarkType.eyebrowS.copyWith(
                              color: c.primaryInk,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: SalamatDarkDims.gap2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SalamatDarkType.micro.copyWith(color: c.text3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: SalamatDarkDims.gap10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.price,
                  style: SalamatDarkType.numStat.copyWith(color: c.text),
                ),
                if (data.discount != null) ...[
                  const SizedBox(height: SalamatDarkDims.gap2),
                  Text(
                    loc.paywallSaveBadge(data.discount!),
                    style: SalamatDarkType.micro.copyWith(color: c.primaryInk),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.primary : c.line2,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar: CTA + fine print
// ---------------------------------------------------------------------------

/// The action area.
///
/// The CTA wording is decided by the store, not by us: a product with a free
/// phase gets the trial CTA plus the exact first charge and its date; a
/// product without one gets a plain "Subscribe". When prices failed to load
/// the same button becomes Retry, so the screen is never a dead end — and no
/// price is ever invented to fill the gap.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.trial,
    required this.onPrimary,
    required this.finePrint,
  });

  final _PaywallCtaState state;
  final _Trial? trial;
  final VoidCallback? onPrimary;
  final String finePrint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;

    final label = switch (state) {
      _PaywallCtaState.error => loc.retryButton,
      _PaywallCtaState.trial => loc.paywallTrialCta(trial!.label(loc)),
      _PaywallCtaState.plain => loc.paywallSubscribeCta,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
        SalamatDarkDims.screenPadH,
        12,
        SalamatDarkDims.screenPadH,
        16,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryCta(label: label, onTap: onPrimary),
          if (state == _PaywallCtaState.trial) ...[
            const SizedBox(height: SalamatDarkDims.gap6),
            Text(
              '${loc.paywallTrialThen(
                trial!.firstChargePrice,
                _shortDate(context, trial!.firstChargeDate),
              )} · ${loc.paywallCancelAnytime}',
              textAlign: TextAlign.center,
              style: SalamatDarkType.micro.copyWith(color: c.text2),
            ),
          ],
          const SizedBox(height: SalamatDarkDims.gap8),
          Text(
            finePrint,
            textAlign: TextAlign.center,
            style: SalamatDarkType.style(
              fontSize: 10.5,
              height: 1.4,
              color: c.text3,
            ),
          ),
          const SizedBox(height: SalamatDarkDims.gap6),
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
                  style: SalamatDarkType.style(fontSize: 11, color: c.text3),
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

  static String _shortDate(BuildContext context, DateTime d) =>
      MaterialLocalizations.of(context).formatShortMonthDay(d);
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
        style: SalamatDarkType.style(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: sc.text2,
          decoration: TextDecoration.underline,
          decorationColor: sc.text3,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatefulWidget {
  const _PrimaryCta({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<_PrimaryCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            height: SalamatDarkDims.buttonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [sc.primary, sc.accent],
      ),
              borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
              boxShadow: sc.shadow1,
            ),
            child: Text(widget.label, style: SalamatDarkType.btn),
          ),
        ),
      ),
    );
  }
}



/// Store prices could not be loaded (offline / SDK not configured). No
/// hardcoded fallback prices — retry is the only way forward.
/// Prices could not be loaded.
///
/// An explanatory note only — no inline retry button, because the primary CTA
/// at the bottom already becomes Retry, and no placeholder price, because
/// showing a number we do not have would misstate what the user would be
/// charged.
class _OfferingsError extends StatelessWidget {
  const _OfferingsError({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SalamatDarkDims.screenPadH,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SalamatDarkDims.padCard),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 18, color: c.text3),
            const SizedBox(width: SalamatDarkDims.gap12),
            Expanded(
              child: Text(
                loc.paywallOfferingsError,
                style: SalamatDarkType.caption
                    .copyWith(color: c.text2, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
