// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Salamat';

  @override
  String get buttonContinue => 'Continue';

  @override
  String get buttonNext => 'Next';

  @override
  String get buttonStart => 'Start';

  @override
  String get buttonYes => 'Yes';

  @override
  String get buttonNo => 'No';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonSave => 'Save';

  @override
  String get valueDash => '—';

  @override
  String get welcomeHeadline => 'Your weight WILL be reached\nin our app';

  @override
  String get welcomeSubtitle => 'Let\'s start with a few questions\nfor your personal plan';

  @override
  String get nameTitle => 'What\'s your name?';

  @override
  String get nameSubtitle => 'So we can greet you';

  @override
  String get nameFieldHint => 'Your name';

  @override
  String get countryTitle => 'Where are you from?';

  @override
  String get countrySubtitle => 'To show prices in your currency';

  @override
  String get countryKZ => 'Kazakhstan';

  @override
  String get countryKG => 'Kyrgyzstan';

  @override
  String get countryUZ => 'Uzbekistan';

  @override
  String get countryTJ => 'Tajikistan';

  @override
  String get countryTM => 'Turkmenistan';

  @override
  String get countryRU => 'Russia';

  @override
  String get countryOther => 'Other';

  @override
  String get goalTitle => 'What is your\nmain goal?';

  @override
  String get goalSubtitle => 'Pick one — we\'ll tailor your plan to it';

  @override
  String get goalLose => 'Lose weight';

  @override
  String get goalLoseSub => 'Weight loss, calorie deficit';

  @override
  String get goalGain => 'Gain weight';

  @override
  String get goalGainSub => 'Mass gain, calorie surplus';

  @override
  String get goalMaintain => 'Maintain';

  @override
  String get goalMaintainSub => 'Keep your current weight';

  @override
  String get goalHealthy => 'Healthy eating';

  @override
  String get goalHealthySub => 'Macro control, mindful eating';

  @override
  String get genderTitle => 'Your sex?';

  @override
  String get genderSubtitle => 'Needed for accurate calorie targets';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderMale => 'Male';

  @override
  String get yearTitle => 'What year were\nyou born?';

  @override
  String get yearSubtitle => 'Age affects your calorie target';

  @override
  String yearAgeLabel(int age) {
    return 'You are $age';
  }

  @override
  String yearMinAgeWarning(int min) {
    return 'Salamat is available from age $min';
  }

  @override
  String get weightTitle => 'Your height and\ncurrent weight?';

  @override
  String get weightSubtitle => 'These drive plan accuracy';

  @override
  String get weightHeightLabel => 'Height';

  @override
  String get weightWeightLabel => 'Weight';

  @override
  String weightHeightValue(int cm) {
    return '$cm cm';
  }

  @override
  String weightWeightValue(int kg) {
    return '$kg kg';
  }

  @override
  String get bmiLabel => 'BMI';

  @override
  String get bmiBandUnder => 'Underweight';

  @override
  String get bmiBandNormal => 'Normal';

  @override
  String get bmiBandOver => 'Overweight';

  @override
  String get bmiBandObese => 'Obese';

  @override
  String get targetTitle => 'What is your\ntarget weight?';

  @override
  String get targetSubtitle => 'A realistic goal is the #1 success factor';

  @override
  String targetDeltaLose(int kg) {
    return 'Lose $kg kg';
  }

  @override
  String targetDeltaGain(int kg) {
    return 'Gain $kg kg';
  }

  @override
  String get targetDeltaMaintain => 'Maintain weight';

  @override
  String get underweightWarningTitle => 'Weight loss may be unsafe';

  @override
  String get underweightWarningBody => 'Your body mass index is below normal. Losing weight at this level can harm your health. We recommend consulting a doctor before starting.';

  @override
  String get underweightWarningChangeGoal => 'Choose another goal';

  @override
  String get underweightWarningProceed => 'I understand, continue';

  @override
  String celebrationLose(int kg) {
    return 'Losing $kg kg is a realistic goal.\nNot that hard at all!';
  }

  @override
  String celebrationGain(int kg) {
    return 'Gaining $kg kg is a realistic goal.\nNot that hard at all!';
  }

  @override
  String get celebrationMaintain => 'Great choice —\nholding a healthy weight';

  @override
  String get celebrationStat => 'Losing just 5% of your weight\nalready improves health';

  @override
  String get longTermTitle => 'Salamat builds\nlong-term results';

  @override
  String get longTermLegendSalamat => 'Salamat plan';

  @override
  String get longTermLegendOthers => 'Typical diets';

  @override
  String get longTermStat => '76% of Salamat users keep their weight\noff for 6+ months';

  @override
  String get familiarityTitle => 'How familiar are you\nwith weight loss?';

  @override
  String get familiarityHint => '75% answered the same way.\nSalamat will guide you through it.';

  @override
  String get familiarityNovice => 'Beginner';

  @override
  String get familiarityNoviceSub => 'Just starting to figure it out';

  @override
  String get familiarityIntermediate => 'Intermediate';

  @override
  String get familiarityIntermediateSub => 'Know a bit and have tried things';

  @override
  String get familiarityExpert => 'Expert';

  @override
  String get familiarityExpertSub => 'Well-versed in the topic';

  @override
  String get activityTitle => 'What is your\nactivity level?';

  @override
  String get activitySubtitle => 'More activity, more food you can eat';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activitySedentarySub => 'Desk work, little movement';

  @override
  String get activityLight => 'Lightly active';

  @override
  String get activityLightSub => '1–3 workouts per week';

  @override
  String get activityModerate => 'Moderately active';

  @override
  String get activityModerateSub => '3–5 workouts per week';

  @override
  String get activityVery => 'Very active';

  @override
  String get activityVerySub => '6–7 workouts per week';

  @override
  String get summaryTitle => 'Personal plan\nbased on your answers';

  @override
  String get summaryStatBmi => 'BMI';

  @override
  String get summaryStatTarget => 'Target weight';

  @override
  String get summaryStatLevel => 'Level';

  @override
  String get summaryStatActivity => 'Activity';

  @override
  String get yesLoseQuestion => 'Want to lose weight?';

  @override
  String get yesOrderQuestion => 'Want to clean up\nyour eating?';

  @override
  String get yesHealthQuestion => 'Want to say goodbye\nto health problems?';

  @override
  String get yesCaptionBefore => 'Now';

  @override
  String get yesCaptionAfter => 'With Salamat';

  @override
  String get comparisonTitle => 'Lose weight 2× faster\nwith Salamat than\non your own';

  @override
  String get comparisonWithout => 'Without Salamat';

  @override
  String get comparisonWith => 'With Salamat';

  @override
  String get comparisonStat => '78% of users reach lasting results\nwith Salamat';

  @override
  String get socialTitle => 'Salamat is built\nfor people\nlike you!';

  @override
  String get socialUsersCount => '1,000,000';

  @override
  String get socialUsersLabel => 'Salamat users';

  @override
  String get socialStatPercent => '83%';

  @override
  String get socialStatText => 'of users say our plan\nis easy to follow';

  @override
  String get buildingTitle => 'Building your\nprogram...';

  @override
  String get buildingStep1 => 'Profile analysis';

  @override
  String get buildingStep2 => 'Metabolism calculation';

  @override
  String get buildingStep3 => 'Meal plan creation';

  @override
  String get planTitle => 'Your personal\nplan is ready';

  @override
  String get planNow => 'Now';

  @override
  String get planTarget => 'Goal';

  @override
  String planWeeksToTarget(int weeks) {
    return 'About $weeks weeks to goal';
  }

  @override
  String get planMaintain => 'Maintain weight';

  @override
  String get planCaloriesLabel => 'Your calorie target';

  @override
  String planCaloriesValue(int kcal) {
    return '$kcal kcal / day';
  }

  @override
  String dashboardGreeting(String name) {
    return 'Hi, $name 👋';
  }

  @override
  String get dashboardGuestName => 'friend';

  @override
  String get dashboardCaloriesLabel => 'CALORIES';

  @override
  String dashboardConsumedOfNorm(int norm) {
    return 'of $norm kcal';
  }

  @override
  String dashboardLeft(int left) {
    return '$left left';
  }

  @override
  String dashboardOverflow(int over) {
    return 'over by $over';
  }

  @override
  String get dashboardMacroProtein => 'PROTEIN';

  @override
  String get dashboardMacroFat => 'FAT';

  @override
  String get dashboardMacroCarbs => 'CARBS';

  @override
  String get dashboardMeals => 'Meals';

  @override
  String get dashboardKcalUnit => 'kcal';

  @override
  String dashboardKcalWithValue(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get dashboardEmptyMeal => 'Tap + to add';

  @override
  String get dashboardStreakDays => 'days';

  @override
  String dashboardStreakLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navProgress => 'Progress';

  @override
  String get navProfile => 'Profile';

  @override
  String dashboardStreakValue(int n) {
    return '$n';
  }

  @override
  String gramsSuffix(int g) {
    return '$g g';
  }

  @override
  String get gramsUnit => 'g';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get mealBreakfastLower => 'breakfast';

  @override
  String get mealLunchLower => 'lunch';

  @override
  String get mealDinnerLower => 'dinner';

  @override
  String get mealSnackLower => 'snack';

  @override
  String get searchTitle => 'Add food';

  @override
  String get searchHint => 'Search dishes...';

  @override
  String searchPer100(int kcal) {
    return '$kcal kcal · per 100g';
  }

  @override
  String get searchAddTo => 'Add to';

  @override
  String get searchEmpty => 'Nothing found';

  @override
  String get searchOffline => 'No connection — showing core list';

  @override
  String get portionPer100 => 'per 100g';

  @override
  String get portionPresetSmall => 'S';

  @override
  String get portionPresetMedium => 'M';

  @override
  String get portionPresetLarge => 'L';

  @override
  String get portionPresetCustom => 'Custom';

  @override
  String get portionCustomHint => 'Grams';

  @override
  String portionGramsShort(int g) {
    return '$g g';
  }

  @override
  String portionKcalWithGrams(int g) {
    return 'kcal · $g g';
  }

  @override
  String portionAddToMeal(String meal) {
    return 'Add to $meal';
  }

  @override
  String portionAddedSnack(String meal) {
    return 'Added to $meal ✓';
  }

  @override
  String get cameraPermissionTitle => 'Camera access needed';

  @override
  String get cameraPermissionBody => 'Allow camera access in Settings to recognise dishes from photos.';

  @override
  String get cameraOpenSettings => 'Open Settings';

  @override
  String get cameraUnavailable => 'Camera not available on the simulator';

  @override
  String get cameraUnavailableDevice => 'Camera is not available on this device';

  @override
  String get cameraSimulate => 'Simulate recognition';

  @override
  String get cameraHint => 'POINT AT THE DISH';

  @override
  String get cameraLoading => 'Recognising dish...';

  @override
  String get cameraNotRecognized => 'Could not recognise the dish';

  @override
  String get cameraErrorNoNetwork => 'No internet connection';

  @override
  String get cameraErrorServer => 'Service is temporarily unavailable';

  @override
  String cameraConfidence(int percent) {
    return '$percent% match';
  }

  @override
  String cameraKcalPerPortion(int g) {
    return 'kcal per $g g';
  }

  @override
  String get cameraMacroProtein => 'Protein';

  @override
  String get cameraMacroFat => 'Fat';

  @override
  String get cameraMacroCarbs => 'Carbs';

  @override
  String get cameraAddButton => '✓ Add to diary';

  @override
  String get cameraRetake => '↺ Retake';

  @override
  String get cameraOutOfPhotos => 'You\'ve used all 3 free photos.\nUpgrade to Pro — 10 photos a day. 📸';

  @override
  String get cameraTryPro => 'Try Pro';

  @override
  String get cameraAddedSnack => 'Added ✓';

  @override
  String cameraCounter(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String get cameraDialogCancel => 'Cancel';

  @override
  String get paywallTitleLine1 => 'Eat smarter';

  @override
  String get paywallTitleLine2 => 'with Salamat Pro';

  @override
  String get paywallSubtitle => '3 free photos.\nWith Pro — 10 photos a day + forecast + analysis.';

  @override
  String get paywallLimitBadge => 'Photo limit reached';

  @override
  String get paywallFeature1Title => '10 photos a day';

  @override
  String get paywallFeature1Sub => 'Snap every meal';

  @override
  String get paywallFeature2Title => 'Weight forecast';

  @override
  String get paywallFeature2Sub => 'See when you reach your goal';

  @override
  String get paywallFeature3Title => 'Unlimited history';

  @override
  String get paywallFeature3Sub => 'Your whole food diary';

  @override
  String get paywallTierWeekLabel => 'WEEK';

  @override
  String get paywallTierMonthLabel => 'MONTH';

  @override
  String get paywallTierYearLabel => 'YEAR';

  @override
  String get paywallPopular => 'Popular';

  @override
  String get paywallTrialButton => 'Try free — 7 days';

  @override
  String get paywallCancelAnytime => 'Cancel anytime';

  @override
  String get paywallStub => 'Payments coming soon!';

  @override
  String get paywallRestore => 'Restore';

  @override
  String get paywallHeroHeadline => 'Get full access to\nyour weight-loss plan';

  @override
  String paywallUrgencyLine(int weight, String date) {
    return 'Reach $weight kg by $date';
  }

  @override
  String get paywallScanEyebrow => 'Recognized';

  @override
  String get paywallScanMeal => 'Pilaf';

  @override
  String paywallScanKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get paywallTier1mo => '1 MONTH';

  @override
  String get paywallTier3mo => '3 MONTHS';

  @override
  String get paywallTier12mo => '12 MONTHS';

  @override
  String get paywallPerMonthUnit => '/mo';

  @override
  String paywallPerMonthValue(String price) {
    return '$price/mo';
  }

  @override
  String paywallTotal(String price) {
    return '$price total';
  }

  @override
  String paywallSaveBadge(int percent) {
    return '−$percent%';
  }

  @override
  String get paywallNoPaymentNow => 'No payment now';

  @override
  String get paywallTrustLine => '1,000,000 users · 83% reach their goal';

  @override
  String get paywallFinePrint => 'Subscription renews automatically at the end of each period. Cancel anytime in your store account. Terms and Privacy apply.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuest => 'Guest';

  @override
  String get profileBadgePro => 'Pro';

  @override
  String get profileBadgeFree => 'Free';

  @override
  String get profileStatDaysInApp => 'days in Salamat';

  @override
  String get profileStatEntries => 'dishes added';

  @override
  String get profileStatStreak => 'day streak';

  @override
  String get profileDataTitle => 'My data';

  @override
  String get profileDataAge => 'Age';

  @override
  String profileDataAgeValue(int age) {
    return '$age y';
  }

  @override
  String get profileDataHeight => 'Height';

  @override
  String get profileDataWeight => 'Weight';

  @override
  String get profileDataGoal => 'Goal';

  @override
  String get profileDataCalorieNorm => 'Calorie target';

  @override
  String get profileDataKcalUnit => 'kcal';

  @override
  String get profileDataCmUnit => 'cm';

  @override
  String get profileDataKgUnit => 'kg';

  @override
  String get profileReferralTitle => '🎁 Invite a friend — get 7 days of Pro';

  @override
  String get profileReferralSubtitle => '5 friends = one Pro week free';

  @override
  String get profileReferralCopy => 'Copy link';

  @override
  String get profileReferralCopied => 'Link copied!';

  @override
  String get profileSettingNotifications => 'Notifications';

  @override
  String get profileSettingMyGoal => 'My goal';

  @override
  String get profileSettingUpdateWeight => 'Update weight';

  @override
  String get profileSettingPro => 'Salamat Pro';

  @override
  String get profileSettingLogout => 'Sign out';

  @override
  String get profileSettingPrivacy => 'Privacy Policy';

  @override
  String get profileSettingTerms => 'Terms of Service';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteDialogTitle => 'Delete account?';

  @override
  String get profileDeleteDialogBody => 'All your data — profile, food history and weight — will be permanently deleted. This cannot be undone.';

  @override
  String get profileDeleteConfirm => 'Delete';

  @override
  String get profileDeleteError => 'Couldn\'t delete account. Please try again later.';

  @override
  String get paywallFinePrintPrivacy => 'Privacy Policy';

  @override
  String get paywallFinePrintTerms => 'Terms';

  @override
  String get profileSettingLanguage => 'Language';

  @override
  String profileSoonSuffix(String label) {
    return '$label — soon';
  }

  @override
  String get profileUpdateWeightDialog => 'Update weight';

  @override
  String get profileWeightHint => 'Weight (kg)';

  @override
  String profileWeightRangeError(int min, int max) {
    return 'Enter a weight between $min and $max kg';
  }

  @override
  String get profileKgShort => 'kg';

  @override
  String get progressTitle => 'Progress';

  @override
  String progressStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String get progressNextGoal => 'Keep going — next goal is 7 days';

  @override
  String get progressStreakStart => 'Start today';

  @override
  String get progressStreakStartHint => 'Log your first meal to start a streak';

  @override
  String get progressHistoryEmpty => 'No data yet. Add meals and your history will appear here.';

  @override
  String get progressToday => 'Today';

  @override
  String get progressHistory => 'History';

  @override
  String progressOfNormKcal(int norm) {
    return 'of $norm kcal';
  }

  @override
  String get progressMacroProtein => 'g protein';

  @override
  String get progressMacroFat => 'g fat';

  @override
  String get progressMacroCarbs => 'g carbs';

  @override
  String get progressDayMon => 'Mon';

  @override
  String get progressDayTue => 'Tue';

  @override
  String get progressDayWed => 'Wed';

  @override
  String get progressDayThu => 'Thu';

  @override
  String get progressDayFri => 'Fri';

  @override
  String get progressDaySat => 'Sat';

  @override
  String get progressDayToday => 'Today';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageSelectTitle => 'Language';
}
