/// Primary sources for every number the app derives about a person.
///
/// App Store guideline 1.4.1 asks that medical-style calculations cite where
/// they come from. These are the citations behind the calorie target and the
/// BMI bands, checked live on 16 Sep 2026 — each URL answered 200 and the
/// record behind it matched the paper named here.
///
/// One rule, applied throughout: link the paper or the WHO/FAO document, never
/// a page of ours. Where a number has no primary source — the activity
/// multipliers, the ±500 kcal shift, the 1200/1500 floors — the UI says so in
/// words rather than pinning a citation on it that does not actually contain
/// the number. See [MethodologyCard] for how these are shown.
class Sources {
  Sources._();

  /// The BMR equation itself. Mifflin MD, St Jeor ST, Hill LA, Scott BJ,
  /// Daugherty SA, Koh YO. A new predictive equation for resting energy
  /// expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241-7.
  static const String mifflin1990 = 'https://doi.org/10.1093/ajcn/51.2.241';

  /// Why that equation: the Academy's systematic review found it most often
  /// within ±10 % of measured RMR — and named the individual error that
  /// remains. Frankenfield D, Roth-Yousey L, Compher C. J Am Diet Assoc.
  /// 2005;105(5):775-89.
  static const String frankenfield2005 =
      'https://doi.org/10.1016/j.jada.2005.02.005';

  /// The concept of a physical activity level (PAL) multiplying BMR.
  /// FAO/WHO/UNU. Human energy requirements. Report of a Joint Expert
  /// Consultation, Rome 2001 (publ. 2004), chapter 5. NOTE: its PAL bands
  /// (1.40–1.69 / 1.70–1.99 / 2.00–2.40) are not the multipliers this app
  /// uses; the UI says so explicitly.
  static const String faoEnergy2004 =
      'https://www.fao.org/4/y5686e/y5686e07.htm';

  /// Where the ±500 kcal/day convention comes from, and why it overstates
  /// the pace: Hall KD. What is the required energy deficit per unit weight
  /// loss? Int J Obes. 2008;32(3):573-6.
  static const String hall2008 = 'https://doi.org/10.1038/sj.ijo.0803720';

  /// A review giving the customary low-calorie ranges (1200–1500 kcal for
  /// women, 1500–1800 for men) that the app's floors sit at the bottom of.
  /// Koliaki C et al. Healthcare (Basel). 2018;6(3):73.
  static const String koliaki2018 =
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC6163457/';

  /// WHO's adult BMI table with all four cut-offs (18.5 / 25 / 30), citing
  /// TRS 854 as its source. Nutrition Landscape Information System.
  static const String whoBmiTable =
      'https://apps.who.int/nutrition/landscape/help.aspx?menu=0&helpid=420';

  /// The primary document for those cut-offs. WHO. Physical status: the use
  /// and interpretation of anthropometry. Technical Report Series 854, 1995.
  static const String whoTrs854 = 'https://iris.who.int/handle/10665/37003';

  /// WHO calling BMI a surrogate marker that needs other measurements
  /// alongside it. Fact sheet: Obesity and overweight.
  static const String whoObesityFactSheet =
      'https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight';

  /// Lower cut-offs WHO allows for Asian populations. WHO Expert
  /// Consultation. Lancet. 2004;363(9403):157-63.
  static const String whoAsianBmi2004 =
      'https://doi.org/10.1016/S0140-6736(03)15268-3';
}
