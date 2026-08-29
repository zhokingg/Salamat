# Paywall — source dump

The paywall screen itself **does render** on the emulator (see `33_paywall_offerings_error.png` / `43_paywall_ru.png`), but the
price/plan block cannot: RevenueCat returns no offerings on this device, so `_loadOfferings()`
lands in `_loadError = true` and the tier cards are replaced by the error box.
Per the task brief, the full widget source and every string/price it can show are dumped here.

Route: `/paywall` · File: `lib/screens/paywall/paywall_screen.dart` (1143 lines)
Entry points: Profile → "Salamat Pro"; Camera → out-of-photos stub → "Upgrade"; `photo_limit_sheet.dart`.

## Why prices are empty

```
RevenueCatConfig.androidKey = 'goog_MjXDCzsmgjILoXATHgzTkXLsCmX'   (lib/config/revenuecat.dart)
proEntitlement              = 'pro'
```

Prices are **never hardcoded** — `_TierData.main` comes from
`package.storeProduct.priceString`, `sub` from `NumberFormat.simpleCurrency(annualPrice / 12)`,
and the discount badge from `100 - annual / (monthly * 12) * 100`. With no Google Play
products wired up, all three are unavailable and the UI shows `paywallOfferingsError`.

## Strings the paywall can display

| key | EN | RU |
|---|---|---|
| `cameraOutOfPhotos` | Your free scan for today is used | Бесплатный скан на сегодня использован |
| `paywallCancelAnytime` | Cancel anytime | Отменить в любой момент |
| `paywallFeature1Sub` | Snap every meal | Фотай каждый приём пищи |
| `paywallFeature1Title` | 10 photo scans a day | 10 фото-сканов в день |
| `paywallFeature2Sub` | See when you reach your goal | Видишь когда достигнешь цели |
| `paywallFeature2Title` | Weight forecast | Прогноз веса |
| `paywallFeature3Sub` | Your whole food diary | Весь дневник питания |
| `paywallFeature3Title` | Full history & trends | Полная история и тренды |
| `paywallFinePrint` | Subscription renews automatically at the end of each period. Cancel anytime in your store account. Terms and Privacy apply. | Подписка продлевается автоматически в конце каждого периода. Отмените в любой момент в аккаунте магазина. Действуют Условия и Политика конфиденциальности. |
| `paywallFinePrintPrivacy` | Privacy Policy | Политика конфиденциальности |
| `paywallFinePrintTerms` | Terms | Условия |
| `paywallHeroHeadlineGain` | Get full access to ⏎ your weight-gain plan | Полный доступ к вашему ⏎ плану набора веса |
| `paywallHeroHeadlineLose` | Get full access to ⏎ your weight-loss plan | Полный доступ к вашему ⏎ плану похудения |
| `paywallHeroHeadlineMaintain` | Get full access to ⏎ your balance plan | Полный доступ к вашему ⏎ плану баланса |
| `paywallLimitBadge` | Photo limit reached | Лимит фото исчерпан |
| `paywallNoPaymentNow` | No payment now | Без оплаты сейчас |
| `paywallOfferingsError` | Couldn’t load prices from Google Play. ⏎ Check your connection and retry. | Не удалось загрузить цены из Google Play. ⏎ Проверьте связь и повторите. |
| `paywallPerMonthUnit` | /mo | /мес |
| `paywallPerMonthValue` | $price/mo | $price/мес |
| `paywallPopular` | Best value | Выгоднее всего |
| `paywallPurchaseError` | Purchase failed — please try again | Оплата не прошла — попробуйте ещё раз |
| `paywallRestore` | Restore | Восстановить |
| `paywallRestoreFound` | Pro restored | Pro восстановлен |
| `paywallRestoreNotFound` | No purchases found | Покупки не найдены |
| `paywallSaveBadge` | −$percent% | −$percent% |
| `paywallScanEyebrow` | Recognized | Распознано |
| `paywallScanKcal` | $kcal kcal | $kcal ккал |
| `paywallScanMeal` | Pilaf | Плов |
| `paywallSubtitle` | 1 free scan a day. ⏎ With Pro — 10 scans a day + forecast + analysis. | 1 бесплатный скан в день. ⏎ С Pro — 10 сканов в день + прогноз + анализ. |
| `paywallTier12mo` | 12 MONTHS | 12 МЕСЯЦЕВ |
| `paywallTier1mo` | 1 MONTH | 1 МЕСЯЦ |
| `paywallTitleLine1` | Eat smarter | Питайся умнее |
| `paywallTitleLine2` | with Salamat Pro | с Salamat Pro |
| `paywallTrialButton` | Try free — 7 days | Попробовать бесплатно — 7 дней |
| `paywallUrgencyLine` | Reach $weight kg by $date | Достигнете $weight кг к $date |
| `paywallWelcomePro` | Welcome to Pro | Добро пожаловать в Pro |
| `retryButton` | Retry | Повторить |

## Full widget source — `lib/screens/paywall/paywall_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/legal.dart';
import '../../providers/user_provider.dart';
import '../../services/purchases_service.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/elevation.dart';
import '../../theme/text_styles.dart';

enum _Tier { month1, year }

/// Card content resolved from a store package — prices and currency come
/// from Google Play via RevenueCat, never from hardcoded tables.
class _TierData {
  const _TierData({
    required this.main,
    required this.sub,
    required this.discount,
    required this.package,
  });

  final String main;
  final String sub;
  final int? discount;
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
            main: annual.storeProduct.priceString,
            sub: perMonth,
            discount: (discount != null && discount > 0) ? discount : null,
            package: annual,
          ),
          _Tier.month1: _TierData(
            main: monthly.storeProduct.priceString,
            sub: '',
            discount: null,
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
      }
    }
  }

  void _snack(String text, {Color? bg, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bg ?? SalamatColors.g1,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        content: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SalamatColors.surf,
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
          bg: SalamatColors.danger,
          action: SnackBarAction(
            label: loc.retryButton,
            textColor: SalamatColors.surf,
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
      _snack(loc.paywallRestoreNotFound, bg: SalamatColors.i2);
      return;
    }
    try {
      final info = await Purchases.restorePurchases();
      if (!mounted) return;
      if (PurchasesService.hasPro(info)) {
        _snack(loc.paywallRestoreFound);
        _close();
      } else {
        _snack(loc.paywallRestoreNotFound, bg: SalamatColors.i2);
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      _snack(
        loc.paywallPurchaseError,
        bg: SalamatColors.danger,
        action: SnackBarAction(
          label: loc.retryButton,
          textColor: SalamatColors.surf,
          onPressed: _restore,
        ),
      );
    }
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
                    _UrgencyLine(
                      text: loc.paywallUrgencyLine(
                        t.weight,
                        _formatDate(t.date, loc),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: SalamatColors.g1,
                          ),
                        ),
                      )
                    else if (_loadError)
                      _OfferingsError(onRetry: _loadOfferings)
                    else
                      _TierRow(
                        selected: _selected,
                        tiers: _tiers,
                        onSelect: (t) => setState(() => _selected = t),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _BottomBar(
                onContinue:
                    (_loading || _loadError || _purchasing) ? null : _purchase,
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
    required this.tiers,
    required this.onSelect,
  });

  final _Tier selected;
  final Map<_Tier, _TierData> tiers;
  final ValueChanged<_Tier> onSelect;

  // Two tiers, stacked: Annual (best value, default) on top, Monthly below.
  static const _order = [_Tier.year, _Tier.month1];

  /// Card content for the given tier, straight from the store package.
  ({
    String main,
    String sub,
    bool popular,
    int? discount,
  }) _spec(_Tier t) {
    final d = tiers[t]!;
    return (
      main: d.main,
      sub: d.sub,
      popular: t == _Tier.year,
      discount: d.discount,
    );
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
      child: Column(
        children: [
          for (var i = 0; i < _order.length; i++) ...[
            _TierCard(
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
            if (i != _order.length - 1) const SizedBox(height: 10),
          ],
        ],
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
    required this.finePrint,
  });

  final VoidCallback? onContinue;
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
      ),
    );
  }
}



/// Store prices could not be loaded (offline / SDK not configured). No
/// hardcoded fallback prices — retry is the only way forward.
class _OfferingsError extends StatelessWidget {
  const _OfferingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SalamatDims.screenPadding,
        16,
        SalamatDims.screenPadding,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SalamatColors.surf,
          borderRadius: BorderRadius.circular(SalamatElevation.cardRadius),
          border: Border.all(color: SalamatElevation.hairline),
        ),
        child: Column(
          children: [
            Text(
              loc.paywallOfferingsError,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SalamatColors.i2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                loc.retryButton,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SalamatColors.g1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
