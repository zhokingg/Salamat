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
  String get manualTitle => 'Add meal manually';

  @override
  String get manualNameLabel => 'Dish name';

  @override
  String get manualKcalLabel => 'Calories (kcal)';

  @override
  String get manualKcalError => 'Enter 1–5000 kcal';

  @override
  String get manualAddDetails => 'Add details';

  @override
  String get manualProtein => 'Protein, g';

  @override
  String get manualFat => 'Fat, g';

  @override
  String get manualCarbs => 'Carbs, g';

  @override
  String get manualPortion => 'Portion, g';

  @override
  String manualAddToMeal(String meal) {
    return 'Add to $meal';
  }

  @override
  String manualAddedSnack(String meal) {
    return 'Added to $meal ✓';
  }

  @override
  String get manualAddButton => 'Add manually';

  @override
  String scansLeftOf(int left, int total) {
    return '$left of $total left';
  }

  @override
  String get scansUnlimited => 'Unlimited';

  @override
  String get scansExhaustedTitle => 'That was your last free scan';

  @override
  String get scansExhaustedBody =>
      'Manual entry stays free and unlimited. Subscribe to keep scanning by photo.';

  @override
  String get scansLater => 'Not now';

  @override
  String get limitTitle => 'You\'ve used all 3 free scans';

  @override
  String get limitGoPro => 'Go Pro';

  @override
  String get welcomeFreeLine =>
      'Free · 3 photo scans in total · unlimited manual logging';

  @override
  String get welcomeHeadline =>
      'Photograph your food,\nsee what the day adds up to';

  @override
  String get welcomeSubtitle =>
      'Let\'s start with a few questions\nfor your personal plan';

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
  String get bmiBandUnder => 'Slightly below normal';

  @override
  String get bmiBandNormal => 'Normal';

  @override
  String get bmiBandOver => 'Slightly above normal';

  @override
  String get bmiBandObese => 'Well above normal';

  @override
  String get bmiScaleTitle => 'Where your BMI sits';

  @override
  String get bmiScaleZoneUnder => 'Under';

  @override
  String get bmiScaleZoneNormal => 'Normal';

  @override
  String get bmiScaleZoneOver => 'Over';

  @override
  String get bmiScaleZoneHigh => 'Well over';

  @override
  String get bmiScaleNote =>
      'A rough reference, not a diagnosis — BMI knows nothing about muscle or build.';

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
  String targetConflictLose(int current) {
    return 'Your goal is to lose weight, so the target has to be below your current $current kg.';
  }

  @override
  String targetConflictGain(int current) {
    return 'Your goal is to gain weight, so the target has to be above your current $current kg.';
  }

  @override
  String get targetDeltaMaintain => 'Maintain weight';

  @override
  String get underweightWarningTitle => 'Weight loss may be unsafe';

  @override
  String get underweightWarningBody =>
      'Your body mass index is below normal. Losing weight at this level can harm your health. We recommend consulting a doctor before starting.';

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
  String get celebrationStatLose =>
      'A general medical finding: losing about 5%\nof your weight already improves health';

  @override
  String get celebrationStatGain =>
      'A general medical finding: gaining 0.25–0.5 kg\na week builds muscle rather than fat';

  @override
  String get celebrationStatMaintain =>
      'A general medical finding: a stable weight\nlowers heart and metabolic risks';

  @override
  String get longTermTitle => 'Salamat builds\nlong-term results';

  @override
  String get longTermLegendSalamat => 'Gradual changes';

  @override
  String get longTermLegendOthers => 'Strict diets';

  @override
  String get longTermApproach =>
      'Salamat is built on gradual changes\nyou can actually keep, not strict diets';

  @override
  String get familiarityTitle => 'How familiar are you\nwith weight loss?';

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
  String get summaryStatNow => 'Now';

  @override
  String get summaryStatTarget => 'Target weight';

  @override
  String get summaryStatLevel => 'Level';

  @override
  String get summaryStatActivity => 'Activity';

  @override
  String get yesLoseQuestion => 'Want to lose weight?';

  @override
  String get yesGainQuestion => 'Want to gain weight\nthe healthy way?';

  @override
  String get yesMaintainQuestion => 'Want to hold\na comfortable weight?';

  @override
  String get yesOrderQuestion => 'Want to clean up\nyour eating?';

  @override
  String get yesHealthQuestion => 'Want to say goodbye\nto health problems?';

  @override
  String get yesCaptionBefore => 'Now';

  @override
  String get yesCaptionAfter => 'With Salamat';

  @override
  String get comparisonTitle => 'What you get\nwith Salamat';

  @override
  String get comparisonFeaturePhoto => 'Log your meals from a photo in seconds';

  @override
  String get comparisonFeatureNumbers => 'See your habits in clear numbers';

  @override
  String get comparisonFeatureOneScreen =>
      'Everything on one screen — no manual database search';

  @override
  String get socialTitle => 'Salamat is built\nfor people\nlike you!';

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
    return 'Plan length — about $weeks weeks';
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
  String planPaceLine(String pace) {
    return 'The plan works to about $pace kg a week';
  }

  @override
  String planPaceShort(String pace) {
    return '$pace kg/week';
  }

  @override
  String get planStartTracking => 'Start tracking';

  @override
  String dashboardGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get dashboardGreetingNoName => 'Hi!';

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
  String get dashboardLeftLabel => 'left';

  @override
  String get dashboardOverflowLabel => 'over';

  @override
  String get dashboardLastMeal => 'LAST MEAL';

  @override
  String get dashboardCaloriesBudget => 'Calories budget';

  @override
  String get dashboardWater => 'Water';

  @override
  String dashboardWaterLiters(String n) {
    return '$n L';
  }

  @override
  String get dashboardSnapFirstMeal => 'Snap your first meal';

  @override
  String get mealsNothingYet => 'Nothing yet';

  @override
  String get dashboardWeightTitle => 'WEIGHT';

  @override
  String dashboardWeightSinceStart(String delta) {
    return '$delta kg since start';
  }

  @override
  String get snackIdeaTitle => 'Snack idea';

  @override
  String get dashboardWeightFirstLog => 'Log your first weigh-in';

  @override
  String get snackIdeaHearty =>
      'There’s room for a proper snack — yogurt with fruit or a sandwich fits.';

  @override
  String get snackIdeaLight =>
      'You have room for 120–240 kcal — a handful of almonds or an apple fits nicely.';

  @override
  String get snackIdeaTiny =>
      'Day’s almost complete — water or tea closes it gently.';

  @override
  String mealsMacros(int p, int f, int c) {
    return 'P$p F$f C$c';
  }

  @override
  String get mealsMacrosUnknown => '—';

  @override
  String get dashboardOffline => 'Offline — showing local data';

  @override
  String get retryButton => 'Retry';

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
  String get navMeals => 'Meals';

  @override
  String get navCameraAction => 'Scan a meal';

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
  String get cameraPermissionTitle => 'Camera access needed';

  @override
  String get cameraPermissionBody =>
      'Allow camera access in Settings to recognise dishes from photos.';

  @override
  String get cameraOpenSettings => 'Open Settings';

  @override
  String get cameraUnavailable => 'Camera not available on the simulator';

  @override
  String get cameraUnavailableDevice =>
      'Camera is not available on this device';

  @override
  String get cameraSimulate => 'Simulate recognition';

  @override
  String get barcodeModePhoto => 'Photo';

  @override
  String get barcodeModeCode => 'Barcode';

  @override
  String get barcodeHint => 'POINT AT THE BARCODE';

  @override
  String get barcodeSearching => 'Looking up the product…';

  @override
  String get barcodeFreeNote => 'Barcode scans are free';

  @override
  String get barcodeNotFoundTitle => 'Not in the database';

  @override
  String get barcodeNotFoundBody =>
      'Open Food Facts doesn\'t have this product yet. You can add it by hand in a few seconds.';

  @override
  String get barcodeNoNutritionTitle => 'No nutrition data';

  @override
  String get barcodeNoNutritionBody =>
      'This product is listed but carries no calories, so it can\'t be logged from the label.';

  @override
  String get barcodeOfflineTitle => 'No connection';

  @override
  String get barcodeOfflineBody =>
      'Couldn\'t reach the product database. Check your connection and try again.';

  @override
  String get barcodeInvalidTitle => 'Couldn\'t read the code';

  @override
  String get barcodeInvalidBody =>
      'Hold the phone steady so the whole barcode is inside the frame.';

  @override
  String get voiceModeVoice => 'Voice';

  @override
  String get voiceTapToSpeak => 'Tap and say what you ate';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceHint => 'SAY WHAT YOU ATE';

  @override
  String get voiceExample => '“I ate a shawarma and a coke”';

  @override
  String get voiceCheckText =>
      'Check the text before sending — speech gets words wrong.';

  @override
  String get voiceParsing => 'Working out what that was…';

  @override
  String get voiceSend => 'Find these dishes';

  @override
  String get voiceFreeNote => 'Voice entry is free';

  @override
  String get voiceItemsTitle => 'Add these dishes?';

  @override
  String voiceAddAll(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Add $n dishes',
      one: 'Add 1 dish',
    );
    return '$_temp0';
  }

  @override
  String get voiceMicDeniedTitle => 'Microphone is off';

  @override
  String get voiceMicDeniedBody =>
      'Allow microphone access in Settings to log meals by voice.';

  @override
  String get voiceUnavailableTitle => 'Voice input unavailable';

  @override
  String get voiceUnavailableBody =>
      'This device has no speech recogniser available.';

  @override
  String get voiceNotUnderstoodTitle => 'Didn\'t catch that';

  @override
  String get voiceNotUnderstoodBody =>
      'Say the dishes again, or type them in by hand.';

  @override
  String get voiceOfflineTitle => 'No connection';

  @override
  String get voiceOfflineBody =>
      'Couldn\'t reach the service to work out the dishes. Check your connection and try again.';

  @override
  String get cameraTitlePhoto => 'Scan a meal';

  @override
  String get cameraTitleBarcode => 'Scan a barcode';

  @override
  String get cameraTitleVoice => 'Say what you ate';

  @override
  String get coachTitle => 'Coach';

  @override
  String get coachCardTitle => 'Ask the coach';

  @override
  String get coachCardBody =>
      'Why the weight stalls, what fits the calories you have left — answered from your own diary.';

  @override
  String get coachCardBadge => 'PRO';

  @override
  String get coachIntro =>
      'Ask about your food — what to cook, whether today adds up, how to hit your protein.';

  @override
  String get coachPlaceholder => 'Ask about your food…';

  @override
  String get coachSendLabel => 'Send message';

  @override
  String get coachThinking => 'Thinking…';

  @override
  String coachRemaining(int left, int total) {
    return '$left of $total messages left this month';
  }

  @override
  String get coachDisclaimer =>
      'Not medical advice. For anything health-related, see a doctor.';

  @override
  String get coachSuggest1 => 'Is today on track?';

  @override
  String get coachSuggest2 => 'What should I cook tonight?';

  @override
  String get coachSuggest3 => 'How do I hit my protein?';

  @override
  String get coachNotSubscribedTitle => 'Coach is part of Pro';

  @override
  String get coachNotSubscribedBody =>
      'Unlimited scans, weight forecast and the coach come together in one subscription.';

  @override
  String get coachLimitTitle => 'That\'s this month\'s messages';

  @override
  String get coachLimitBody =>
      'Your coach messages reset at the start of next month. Logging and everything else keeps working.';

  @override
  String get coachOfflineTitle => 'No connection';

  @override
  String get coachOfflineBody =>
      'Couldn\'t reach the coach. Check your connection and try again.';

  @override
  String get coachUnavailableTitle => 'Coach isn\'t switched on yet';

  @override
  String get coachUnavailableBody =>
      'This feature isn\'t available in your build yet. Everything else keeps working.';

  @override
  String get cameraHint => 'POINT AT THE DISH';

  @override
  String get cameraLoading => 'Recognising dish...';

  @override
  String get scanStagePrepare => 'Preparing the photo';

  @override
  String get scanStageRecognise => 'Recognising the dish';

  @override
  String get scanStageCalculate => 'Working out the calories';

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
  String get cameraAddButton => 'Add to diary';

  @override
  String get cameraRetake => 'Retake';

  @override
  String get cameraOutOfPhotos => 'You\'ve used all 3 free scans';

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
  String get paywallSubtitle =>
      'That\'s the whole free allowance.\nWith Pro — unlimited scans + forecast + analysis.';

  @override
  String get paywallLimitBadge => 'Photo limit reached';

  @override
  String get paywallFeature1Title => 'Unlimited photo scans';

  @override
  String get paywallFeature1Sub => 'Snap every meal';

  @override
  String get paywallFeature2Title => 'Weight forecast';

  @override
  String get paywallFeature2Sub => 'Your trend and pace, week by week';

  @override
  String get paywallFeature3Title => 'Full history & trends';

  @override
  String get paywallFeature3Sub => 'Your whole food diary';

  @override
  String get paywallPopular => 'Best value';

  @override
  String get paywallCancelAnytime => 'Cancel anytime';

  @override
  String get paywallRestore => 'Restore';

  @override
  String get paywallWelcomePro => 'Welcome to Pro';

  @override
  String get paywallPurchaseError => 'Purchase failed — please try again';

  @override
  String get paywallRestoreFound => 'Pro restored';

  @override
  String get paywallRestoreNotFound => 'No purchases found';

  @override
  String get paywallOfferingsError =>
      'Couldn’t load subscription prices.\nCheck your connection and retry.';

  @override
  String get paywallHeroHeadlineLose =>
      'Get full access to\nyour weight-loss plan';

  @override
  String get paywallHeroHeadlineGain =>
      'Get full access to\nyour weight-gain plan';

  @override
  String get paywallHeroHeadlineMaintain =>
      'Get full access to\nyour balance plan';

  @override
  String paywallGoalPaceLine(int weight, String pace) {
    return 'Goal $weight kg. The plan assumes about $pace kg a week.';
  }

  @override
  String paywallGoalHoldLine(int weight) {
    return 'Goal: hold steady at $weight kg.';
  }

  @override
  String get paywallGoalGenericLine => 'Built around your goal and your day.';

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
  String get paywallTier12mo => '12 MONTHS';

  @override
  String get paywallPerMonthUnit => '/mo';

  @override
  String paywallPerMonthValue(String price) {
    return '$price/mo';
  }

  @override
  String paywallSaveBadge(int percent) {
    return '−$percent%';
  }

  @override
  String get paywallFinePrint =>
      'Subscription renews automatically at the end of each period. Cancel anytime in your store account. Terms and Privacy apply.';

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
  String get profileDeleteDialogBody =>
      'All your data — profile, food history and weight — will be permanently deleted. This cannot be undone.';

  @override
  String get profileDeleteConfirm => 'Delete';

  @override
  String get profileDeleteError =>
      'Couldn\'t delete account. Please try again later.';

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
  String get progressHistoryEmpty =>
      'No data yet. Add meals and your history will appear here.';

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

  @override
  String get splashTagline => 'AI nutrition coach';

  @override
  String get welcomeChipSnap => 'Snap';

  @override
  String get welcomeChipConfirm => 'Confirm';

  @override
  String get welcomeChipDone => 'Done';

  @override
  String get dashboardTodaysMeals => 'Today\'s meals';

  @override
  String get dashboardScanAction => 'Scan';

  @override
  String get cameraConfirmTitle => 'Confirm your plate';

  @override
  String cameraLogKcal(int kcal) {
    return 'Log $kcal kcal';
  }

  @override
  String get cameraDetectedOne => '1 item detected';

  @override
  String get cameraMealSlotHint => 'Add to';

  @override
  String cameraDetectedBoxLabel(String name, int percent) {
    return '$name $percent%';
  }

  @override
  String get progressRangeDay => 'Day';

  @override
  String get progressRangeWeek => 'Week';

  @override
  String get progressRangeMonth => 'Month';

  @override
  String get progressRangeYear => 'Year';

  @override
  String get progressCalorieTrend => 'Calorie trend';

  @override
  String progressDailyAvg(int kcal) {
    return 'daily avg $kcal';
  }

  @override
  String progressGoalLine(int kcal) {
    return '$kcal goal';
  }

  @override
  String get progressProteinScore => 'Protein score';

  @override
  String progressProteinScoreSub(int hit, int total) {
    return '$hit of $total days on target';
  }

  @override
  String get progressConsistencyLabel => 'Consistency';

  @override
  String get progressConsistencySub => 'days logged in a row';

  @override
  String get progressNoRangeData => 'Nothing logged in this period yet';

  @override
  String get progressWeeklyMilestones => 'Weekly milestones';

  @override
  String progressMilestoneWeek(int n) {
    return 'W$n';
  }

  @override
  String get cookTitle => 'What to cook';

  @override
  String get cookSubtitle => 'From what you have, within what\'s left of today';

  @override
  String get cookPantryHeader => 'Your ingredients';

  @override
  String get cookAddHint => 'Add an ingredient';

  @override
  String get cookAddButton => 'Add';

  @override
  String get cookClearAll => 'Clear all';

  @override
  String cookRemoveItem(String item) {
    return 'Remove $item';
  }

  @override
  String cookPantryFull(int max) {
    return 'Up to $max ingredients';
  }

  @override
  String get cookSuggestButton => 'Suggest 3 dishes';

  @override
  String get cookRemainingLabel => 'Left today';

  @override
  String get cookEmptyPantryTitle => 'Add what you have';

  @override
  String get cookEmptyPantryBody =>
      'List the products in your fridge and Salamat will pick three dishes that fit the rest of your day.';

  @override
  String get cookNoBudgetTitle => 'Today\'s target is used up';

  @override
  String get cookNoBudgetBody =>
      'Nothing fits the remainder right now. Come back tomorrow, or adjust your goal.';

  @override
  String get cookFailedTitle => 'Couldn\'t pick a dish';

  @override
  String get cookFailedBody =>
      'The service didn\'t respond. Check your connection and try again.';

  @override
  String get cookLoading => 'Picking dishes…';

  @override
  String cookRangeKcal(int min, int max) {
    return '$min–$max kcal';
  }

  @override
  String cookRangeG(int min, int max) {
    return '$min–$max g';
  }

  @override
  String cookTimeMinutes(int n) {
    return '$n min';
  }

  @override
  String get cookFits => 'Fits';

  @override
  String get cookBorderline => 'Might not fit';

  @override
  String get cookOver => 'Over the remainder';

  @override
  String get cookWhyRange =>
      'Estimate — the range widens when portion or cooking method is unclear';

  @override
  String get cookIngredientsHeader => 'Ingredients';

  @override
  String get cookStepsHeader => 'How to cook';

  @override
  String get cookAddToDiary => 'Add to diary';

  @override
  String cookAddedToDiary(String dish, int kcal) {
    return '$dish added — $kcal kcal';
  }

  @override
  String get cookMidpointNote => 'Logged at the middle of the range';

  @override
  String get cookRetry => 'Try again';

  @override
  String paywallTrialCta(String period) {
    return 'Start $period free';
  }

  @override
  String paywallTrialThen(String price, String date) {
    return 'Then $price, charged $date';
  }

  @override
  String get paywallSubscribeCta => 'Subscribe';

  @override
  String paywallPeriodDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String paywallPerMonthShort(String price) {
    return '$price / mo';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionPlan => 'Plan and goals';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAppearanceUnavailable => 'Theme follows the app build';

  @override
  String get detailTitle => 'Meal';

  @override
  String detailLoggedAt(String time) {
    return 'Logged at $time';
  }

  @override
  String detailServing(int grams) {
    return '$grams g serving';
  }

  @override
  String get detailSourceBarcode => 'From the barcode';

  @override
  String get detailSourceVoice => 'Said out loud';

  @override
  String get detailSourcePhoto => 'Recognised from a photo';

  @override
  String get detailSourceManual => 'Entered by hand';

  @override
  String get detailSourceSuggested => 'From a suggestion';

  @override
  String get detailDuplicate => 'Duplicate';

  @override
  String get detailSave => 'Save';

  @override
  String detailDeleted(String dish) {
    return '$dish removed';
  }

  @override
  String detailDuplicated(String dish) {
    return '$dish logged again';
  }

  @override
  String get detailDeleteTitle => 'Remove this meal?';

  @override
  String get detailDeleteBody => 'It will be taken out of today\'s diary.';

  @override
  String detailShareOfDay(int percent) {
    return '$percent% of target';
  }

  @override
  String detailSharePercent(int percent) {
    return '$percent%';
  }

  @override
  String waterAdd(int ml) {
    return '+$ml';
  }

  @override
  String get waterUndo => 'Undo';

  @override
  String waterOfGoal(String liters) {
    return 'of $liters L';
  }

  @override
  String get waterNotSynced => 'Saved on this device only';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignInSubtitle =>
      'Your food log, weight history and subscription are on the account, not on the phone.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'At least 8 characters';

  @override
  String get authSignInCta => 'Sign in';

  @override
  String get authSignInWarnTitle => 'This will replace what is on this phone';

  @override
  String get authSignInWarnBody =>
      'Anything logged here without an email belongs to the current account and stays with it. Attach an email first if you want to keep it.';

  @override
  String get authSignInWarnLink => 'Attach an email instead';

  @override
  String get authLinkTitle => 'Attach an email';

  @override
  String get authLinkSubtitle =>
      'Keeps everything you have logged and lets you sign back in after reinstalling. Nothing you have already entered is lost.';

  @override
  String get authLinkCta => 'Attach';

  @override
  String get authLinkedTitle => 'Email attached';

  @override
  String authLinkedBody(String email) {
    return 'You can sign back in with $email from any phone.';
  }

  @override
  String get authConfirmSentTitle => 'Check your email';

  @override
  String authConfirmSentBody(String email) {
    return 'A confirmation link is on its way to $email. Open it and the account is yours — until then nothing changes and nothing is lost.';
  }

  @override
  String get authAccountRow => 'Account';

  @override
  String get authAccountAnonymous => 'No email';

  @override
  String authSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get authSignOutTitle => 'Sign out?';

  @override
  String get authSignOutAnonBody =>
      'This account has no email, so there is no way back into it. Your food log, weight history and subscription will be gone for good.';

  @override
  String get authSignOutAnonAttach => 'Attach an email first';

  @override
  String authSignOutBody(String email) {
    return 'You can sign back in with $email at any time.';
  }

  @override
  String get authSignOutCta => 'Sign out';

  @override
  String get authErrBadCredentials => 'Wrong email or password.';

  @override
  String get authErrEmailTaken =>
      'That email already has an account. Sign in instead.';

  @override
  String get authErrInvalidEmail => 'That doesn\'t look like an email address.';

  @override
  String get authErrWeakPassword => 'Use at least 8 characters.';

  @override
  String get authErrRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get authErrOffline =>
      'Couldn\'t reach the service. Check your connection and try again.';

  @override
  String get paywallSecureTitle => 'Attach an email before you subscribe';

  @override
  String get paywallSecureBody =>
      'A subscription lives on the account. Without an email there is no way back into this one.';

  @override
  String get paywallSecureCta => 'Attach';

  @override
  String get paywallSecureSkip => 'Later';

  @override
  String get welcomeHeroCaption => 'Photograph · Check · Done';
}
