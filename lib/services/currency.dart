import '../providers/user_provider.dart';

/// Currencies we display in the paywall. The `symbol` is what appears
/// next to prices on cards; `iso` is the 3-letter store code for IAP
/// lookups once payments are wired.
enum Currency {
  kzt('₸', 'KZT'),
  kgs('сом', 'KGS'),
  uzs('сўм', 'UZS'),
  rub('₽', 'RUB'),
  usd('\$', 'USD');

  const Currency(this.symbol, this.iso);
  final String symbol;
  final String iso;
}

extension CountryCurrency on Country {
  /// Country → currency. Tajikistan / Turkmenistan fall back to USD
  /// pricing until we publish local-currency SKUs in the store.
  Currency get currency => switch (this) {
        Country.kz => Currency.kzt,
        Country.kg => Currency.kgs,
        Country.uz => Currency.uzs,
        Country.ru => Currency.rub,
        Country.tj => Currency.usd,
        Country.tm => Currency.usd,
        Country.other => Currency.usd,
      };
}

/// One paywall row of prices for a single currency. All values are display
/// strings (pre-formatted with thousands separators) because store-level IAP
/// products are fetched as strings too, and we want one consistent shape.
class PaywallPrices {
  const PaywallPrices({
    required this.oneMonth,
    required this.oneMonthPerMo,
    required this.threeMonths,
    required this.threeMonthsPerMo,
    required this.twelveMonths,
    required this.twelveMonthsPerMo,
  });

  final String oneMonth;
  final String oneMonthPerMo;
  final String threeMonths;
  final String threeMonthsPerMo;
  final String twelveMonths;
  final String twelveMonthsPerMo;
}

/// Display placeholder prices. The final values come from the App Store /
/// Play Billing once IAP is wired — these strings exist so the paywall
/// renders the right currency *shape* per region during onboarding.
const Map<Currency, PaywallPrices> kPaywallPrices = {
  Currency.kzt: PaywallPrices(
    oneMonth: '3 790 ₸',
    oneMonthPerMo: '3 790 ₸',
    threeMonths: '6 990 ₸',
    threeMonthsPerMo: '2 330 ₸',
    twelveMonths: '18 990 ₸',
    twelveMonthsPerMo: '1 583 ₸',
  ),
  Currency.kgs: PaywallPrices(
    oneMonth: '690 сом',
    oneMonthPerMo: '690 сом',
    threeMonths: '1 290 сом',
    threeMonthsPerMo: '430 сом',
    twelveMonths: '3 490 сом',
    twelveMonthsPerMo: '291 сом',
  ),
  Currency.uzs: PaywallPrices(
    oneMonth: '95 900 сўм',
    oneMonthPerMo: '95 900 сўм',
    threeMonths: '179 900 сўм',
    threeMonthsPerMo: '59 967 сўм',
    twelveMonths: '479 900 сўм',
    twelveMonthsPerMo: '39 992 сўм',
  ),
  Currency.rub: PaywallPrices(
    oneMonth: '599 ₽',
    oneMonthPerMo: '599 ₽',
    threeMonths: '1 099 ₽',
    threeMonthsPerMo: '366 ₽',
    twelveMonths: '2 990 ₽',
    twelveMonthsPerMo: '249 ₽',
  ),
  Currency.usd: PaywallPrices(
    oneMonth: '\$7.99',
    oneMonthPerMo: '\$7.99',
    threeMonths: '\$14.99',
    threeMonthsPerMo: '\$5.00',
    twelveMonths: '\$39.99',
    twelveMonthsPerMo: '\$3.33',
  ),
};

/// Lookup prices for a given country. Falls back to USD if a country
/// somehow has no entry (defensive — shouldn't happen with current map).
PaywallPrices pricesFor(Country? country) {
  final cur = (country ?? Country.other).currency;
  return kPaywallPrices[cur] ?? kPaywallPrices[Currency.usd]!;
}
