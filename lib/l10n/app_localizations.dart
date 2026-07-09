import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// App name shown on splash and in stores.
  ///
  /// In en, this message translates to:
  /// **'Salamat'**
  String get appName;

  /// No description provided for @buttonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get buttonContinue;

  /// No description provided for @buttonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get buttonNext;

  /// No description provided for @buttonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get buttonStart;

  /// No description provided for @buttonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get buttonYes;

  /// No description provided for @buttonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get buttonNo;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// Placeholder for unset values.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get valueDash;

  /// No description provided for @manualTitle.
  ///
  /// In en, this message translates to:
  /// **'Add meal manually'**
  String get manualTitle;

  /// No description provided for @manualNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Dish name'**
  String get manualNameLabel;

  /// No description provided for @manualKcalLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get manualKcalLabel;

  /// No description provided for @manualKcalError.
  ///
  /// In en, this message translates to:
  /// **'Enter 1–5000 kcal'**
  String get manualKcalError;

  /// No description provided for @manualAddDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get manualAddDetails;

  /// No description provided for @manualProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein, g'**
  String get manualProtein;

  /// No description provided for @manualFat.
  ///
  /// In en, this message translates to:
  /// **'Fat, g'**
  String get manualFat;

  /// No description provided for @manualCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs, g'**
  String get manualCarbs;

  /// No description provided for @manualPortion.
  ///
  /// In en, this message translates to:
  /// **'Portion, g'**
  String get manualPortion;

  /// No description provided for @manualAddToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add to {meal}'**
  String manualAddToMeal(String meal);

  /// No description provided for @manualAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Added to {meal} ✓'**
  String manualAddedSnack(String meal);

  /// No description provided for @manualAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get manualAddButton;

  /// No description provided for @limitTitle.
  ///
  /// In en, this message translates to:
  /// **'Your free scan for today is used'**
  String get limitTitle;

  /// No description provided for @limitGoPro.
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get limitGoPro;

  /// No description provided for @welcomeFreeLine.
  ///
  /// In en, this message translates to:
  /// **'Free · 1 photo scan a day · unlimited manual logging'**
  String get welcomeFreeLine;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your weight WILL be reached\nin our app'**
  String get welcomeHeadline;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start with a few questions\nfor your personal plan'**
  String get welcomeSubtitle;

  /// No description provided for @nameTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get nameTitle;

  /// No description provided for @nameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'So we can greet you'**
  String get nameSubtitle;

  /// No description provided for @nameFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameFieldHint;

  /// No description provided for @countryTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you from?'**
  String get countryTitle;

  /// No description provided for @countrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'To show prices in your currency'**
  String get countrySubtitle;

  /// No description provided for @countryKZ.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstan'**
  String get countryKZ;

  /// No description provided for @countryKG.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyzstan'**
  String get countryKG;

  /// No description provided for @countryUZ.
  ///
  /// In en, this message translates to:
  /// **'Uzbekistan'**
  String get countryUZ;

  /// No description provided for @countryTJ.
  ///
  /// In en, this message translates to:
  /// **'Tajikistan'**
  String get countryTJ;

  /// No description provided for @countryTM.
  ///
  /// In en, this message translates to:
  /// **'Turkmenistan'**
  String get countryTM;

  /// No description provided for @countryRU.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get countryRU;

  /// No description provided for @countryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get countryOther;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your\nmain goal?'**
  String get goalTitle;

  /// No description provided for @goalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick one — we\'ll tailor your plan to it'**
  String get goalSubtitle;

  /// No description provided for @goalLose.
  ///
  /// In en, this message translates to:
  /// **'Lose weight'**
  String get goalLose;

  /// No description provided for @goalLoseSub.
  ///
  /// In en, this message translates to:
  /// **'Weight loss, calorie deficit'**
  String get goalLoseSub;

  /// No description provided for @goalGain.
  ///
  /// In en, this message translates to:
  /// **'Gain weight'**
  String get goalGain;

  /// No description provided for @goalGainSub.
  ///
  /// In en, this message translates to:
  /// **'Mass gain, calorie surplus'**
  String get goalGainSub;

  /// No description provided for @goalMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get goalMaintain;

  /// No description provided for @goalMaintainSub.
  ///
  /// In en, this message translates to:
  /// **'Keep your current weight'**
  String get goalMaintainSub;

  /// No description provided for @goalHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy eating'**
  String get goalHealthy;

  /// No description provided for @goalHealthySub.
  ///
  /// In en, this message translates to:
  /// **'Macro control, mindful eating'**
  String get goalHealthySub;

  /// No description provided for @genderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sex?'**
  String get genderTitle;

  /// No description provided for @genderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Needed for accurate calorie targets'**
  String get genderSubtitle;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @yearTitle.
  ///
  /// In en, this message translates to:
  /// **'What year were\nyou born?'**
  String get yearTitle;

  /// No description provided for @yearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Age affects your calorie target'**
  String get yearSubtitle;

  /// No description provided for @yearAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'You are {age}'**
  String yearAgeLabel(int age);

  /// No description provided for @yearMinAgeWarning.
  ///
  /// In en, this message translates to:
  /// **'Salamat is available from age {min}'**
  String yearMinAgeWarning(int min);

  /// No description provided for @weightTitle.
  ///
  /// In en, this message translates to:
  /// **'Your height and\ncurrent weight?'**
  String get weightTitle;

  /// No description provided for @weightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These drive plan accuracy'**
  String get weightSubtitle;

  /// No description provided for @weightHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get weightHeightLabel;

  /// No description provided for @weightWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightWeightLabel;

  /// No description provided for @weightHeightValue.
  ///
  /// In en, this message translates to:
  /// **'{cm} cm'**
  String weightHeightValue(int cm);

  /// No description provided for @weightWeightValue.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg'**
  String weightWeightValue(int kg);

  /// No description provided for @bmiLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmiLabel;

  /// No description provided for @bmiBandUnder.
  ///
  /// In en, this message translates to:
  /// **'Slightly below normal'**
  String get bmiBandUnder;

  /// No description provided for @bmiBandNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get bmiBandNormal;

  /// No description provided for @bmiBandOver.
  ///
  /// In en, this message translates to:
  /// **'Slightly above normal'**
  String get bmiBandOver;

  /// No description provided for @bmiBandObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get bmiBandObese;

  /// No description provided for @targetTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your\ntarget weight?'**
  String get targetTitle;

  /// No description provided for @targetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A realistic goal is the #1 success factor'**
  String get targetSubtitle;

  /// No description provided for @targetDeltaLose.
  ///
  /// In en, this message translates to:
  /// **'Lose {kg} kg'**
  String targetDeltaLose(int kg);

  /// No description provided for @targetDeltaGain.
  ///
  /// In en, this message translates to:
  /// **'Gain {kg} kg'**
  String targetDeltaGain(int kg);

  /// No description provided for @targetDeltaMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain weight'**
  String get targetDeltaMaintain;

  /// No description provided for @underweightWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight loss may be unsafe'**
  String get underweightWarningTitle;

  /// No description provided for @underweightWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Your body mass index is below normal. Losing weight at this level can harm your health. We recommend consulting a doctor before starting.'**
  String get underweightWarningBody;

  /// No description provided for @underweightWarningChangeGoal.
  ///
  /// In en, this message translates to:
  /// **'Choose another goal'**
  String get underweightWarningChangeGoal;

  /// No description provided for @underweightWarningProceed.
  ///
  /// In en, this message translates to:
  /// **'I understand, continue'**
  String get underweightWarningProceed;

  /// No description provided for @celebrationLose.
  ///
  /// In en, this message translates to:
  /// **'Losing {kg} kg is a realistic goal.\nNot that hard at all!'**
  String celebrationLose(int kg);

  /// No description provided for @celebrationGain.
  ///
  /// In en, this message translates to:
  /// **'Gaining {kg} kg is a realistic goal.\nNot that hard at all!'**
  String celebrationGain(int kg);

  /// No description provided for @celebrationMaintain.
  ///
  /// In en, this message translates to:
  /// **'Great choice —\nholding a healthy weight'**
  String get celebrationMaintain;

  /// No description provided for @celebrationStatLose.
  ///
  /// In en, this message translates to:
  /// **'Losing just 5% of your weight\nalready improves health'**
  String get celebrationStatLose;

  /// No description provided for @celebrationStatGain.
  ///
  /// In en, this message translates to:
  /// **'Gaining 0.25–0.5 kg a week\nbuilds muscle, not fat'**
  String get celebrationStatGain;

  /// No description provided for @celebrationStatMaintain.
  ///
  /// In en, this message translates to:
  /// **'A stable weight lowers heart\nand metabolic risks'**
  String get celebrationStatMaintain;

  /// No description provided for @longTermTitle.
  ///
  /// In en, this message translates to:
  /// **'Salamat builds\nlong-term results'**
  String get longTermTitle;

  /// No description provided for @longTermLegendSalamat.
  ///
  /// In en, this message translates to:
  /// **'Salamat plan'**
  String get longTermLegendSalamat;

  /// No description provided for @longTermLegendOthers.
  ///
  /// In en, this message translates to:
  /// **'Typical diets'**
  String get longTermLegendOthers;

  /// No description provided for @longTermStat.
  ///
  /// In en, this message translates to:
  /// **'76% of Salamat users keep their weight\noff for 6+ months'**
  String get longTermStat;

  /// No description provided for @familiarityTitle.
  ///
  /// In en, this message translates to:
  /// **'How familiar are you\nwith weight loss?'**
  String get familiarityTitle;

  /// No description provided for @familiarityHint.
  ///
  /// In en, this message translates to:
  /// **'75% answered the same way.\nSalamat will guide you through it.'**
  String get familiarityHint;

  /// No description provided for @familiarityNovice.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get familiarityNovice;

  /// No description provided for @familiarityNoviceSub.
  ///
  /// In en, this message translates to:
  /// **'Just starting to figure it out'**
  String get familiarityNoviceSub;

  /// No description provided for @familiarityIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get familiarityIntermediate;

  /// No description provided for @familiarityIntermediateSub.
  ///
  /// In en, this message translates to:
  /// **'Know a bit and have tried things'**
  String get familiarityIntermediateSub;

  /// No description provided for @familiarityExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get familiarityExpert;

  /// No description provided for @familiarityExpertSub.
  ///
  /// In en, this message translates to:
  /// **'Well-versed in the topic'**
  String get familiarityExpertSub;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your\nactivity level?'**
  String get activityTitle;

  /// No description provided for @activitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'More activity, more food you can eat'**
  String get activitySubtitle;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activitySedentary;

  /// No description provided for @activitySedentarySub.
  ///
  /// In en, this message translates to:
  /// **'Desk work, little movement'**
  String get activitySedentarySub;

  /// No description provided for @activityLight.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get activityLight;

  /// No description provided for @activityLightSub.
  ///
  /// In en, this message translates to:
  /// **'1–3 workouts per week'**
  String get activityLightSub;

  /// No description provided for @activityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderately active'**
  String get activityModerate;

  /// No description provided for @activityModerateSub.
  ///
  /// In en, this message translates to:
  /// **'3–5 workouts per week'**
  String get activityModerateSub;

  /// No description provided for @activityVery.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get activityVery;

  /// No description provided for @activityVerySub.
  ///
  /// In en, this message translates to:
  /// **'6–7 workouts per week'**
  String get activityVerySub;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal plan\nbased on your answers'**
  String get summaryTitle;

  /// No description provided for @summaryStatBmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get summaryStatBmi;

  /// No description provided for @summaryStatTarget.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get summaryStatTarget;

  /// No description provided for @summaryStatLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get summaryStatLevel;

  /// No description provided for @summaryStatActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get summaryStatActivity;

  /// No description provided for @yesLoseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Want to lose weight?'**
  String get yesLoseQuestion;

  /// No description provided for @yesGainQuestion.
  ///
  /// In en, this message translates to:
  /// **'Want to gain weight\nthe healthy way?'**
  String get yesGainQuestion;

  /// No description provided for @yesMaintainQuestion.
  ///
  /// In en, this message translates to:
  /// **'Want to hold\na comfortable weight?'**
  String get yesMaintainQuestion;

  /// No description provided for @yesOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Want to clean up\nyour eating?'**
  String get yesOrderQuestion;

  /// No description provided for @yesHealthQuestion.
  ///
  /// In en, this message translates to:
  /// **'Want to say goodbye\nto health problems?'**
  String get yesHealthQuestion;

  /// No description provided for @yesCaptionBefore.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get yesCaptionBefore;

  /// No description provided for @yesCaptionAfter.
  ///
  /// In en, this message translates to:
  /// **'With Salamat'**
  String get yesCaptionAfter;

  /// No description provided for @comparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lose weight 2× faster\nwith Salamat than\non your own'**
  String get comparisonTitle;

  /// No description provided for @comparisonWithout.
  ///
  /// In en, this message translates to:
  /// **'Without Salamat'**
  String get comparisonWithout;

  /// No description provided for @comparisonWith.
  ///
  /// In en, this message translates to:
  /// **'With Salamat'**
  String get comparisonWith;

  /// No description provided for @comparisonStat.
  ///
  /// In en, this message translates to:
  /// **'78% of users reach lasting results\nwith Salamat'**
  String get comparisonStat;

  /// No description provided for @socialTitle.
  ///
  /// In en, this message translates to:
  /// **'Salamat is built\nfor people\nlike you!'**
  String get socialTitle;

  /// No description provided for @socialUsersCount.
  ///
  /// In en, this message translates to:
  /// **'1,000,000'**
  String get socialUsersCount;

  /// No description provided for @socialUsersLabel.
  ///
  /// In en, this message translates to:
  /// **'Salamat users'**
  String get socialUsersLabel;

  /// No description provided for @socialStatPercent.
  ///
  /// In en, this message translates to:
  /// **'83%'**
  String get socialStatPercent;

  /// No description provided for @socialStatText.
  ///
  /// In en, this message translates to:
  /// **'of users say our plan\nis easy to follow'**
  String get socialStatText;

  /// No description provided for @buildingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building your\nprogram...'**
  String get buildingTitle;

  /// No description provided for @buildingStep1.
  ///
  /// In en, this message translates to:
  /// **'Profile analysis'**
  String get buildingStep1;

  /// No description provided for @buildingStep2.
  ///
  /// In en, this message translates to:
  /// **'Metabolism calculation'**
  String get buildingStep2;

  /// No description provided for @buildingStep3.
  ///
  /// In en, this message translates to:
  /// **'Meal plan creation'**
  String get buildingStep3;

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal\nplan is ready'**
  String get planTitle;

  /// No description provided for @planNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get planNow;

  /// No description provided for @planTarget.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get planTarget;

  /// No description provided for @planWeeksToTarget.
  ///
  /// In en, this message translates to:
  /// **'About {weeks} weeks to goal'**
  String planWeeksToTarget(int weeks);

  /// No description provided for @planMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain weight'**
  String get planMaintain;

  /// No description provided for @planCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Your calorie target'**
  String get planCaloriesLabel;

  /// No description provided for @planCaloriesValue.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal / day'**
  String planCaloriesValue(int kcal);

  /// No description provided for @planReachLine.
  ///
  /// In en, this message translates to:
  /// **'You’ll reach {kg} kg around {month}'**
  String planReachLine(int kg, String month);

  /// No description provided for @planStartTracking.
  ///
  /// In en, this message translates to:
  /// **'Start tracking'**
  String get planStartTracking;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String dashboardGreeting(String name);

  /// No description provided for @dashboardGreetingNoName.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get dashboardGreetingNoName;

  /// No description provided for @dashboardGuestName.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get dashboardGuestName;

  /// No description provided for @dashboardCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'CALORIES'**
  String get dashboardCaloriesLabel;

  /// No description provided for @dashboardConsumedOfNorm.
  ///
  /// In en, this message translates to:
  /// **'of {norm} kcal'**
  String dashboardConsumedOfNorm(int norm);

  /// No description provided for @dashboardLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} left'**
  String dashboardLeft(int left);

  /// No description provided for @dashboardOverflow.
  ///
  /// In en, this message translates to:
  /// **'over by {over}'**
  String dashboardOverflow(int over);

  /// No description provided for @dashboardLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get dashboardLeftLabel;

  /// No description provided for @dashboardOverflowLabel.
  ///
  /// In en, this message translates to:
  /// **'over'**
  String get dashboardOverflowLabel;

  /// No description provided for @dashboardLastMeal.
  ///
  /// In en, this message translates to:
  /// **'LAST MEAL'**
  String get dashboardLastMeal;

  /// No description provided for @dashboardCaloriesBudget.
  ///
  /// In en, this message translates to:
  /// **'Calories budget'**
  String get dashboardCaloriesBudget;

  /// No description provided for @dashboardWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get dashboardWater;

  /// No description provided for @dashboardWaterLiters.
  ///
  /// In en, this message translates to:
  /// **'{n} L'**
  String dashboardWaterLiters(String n);

  /// No description provided for @dashboardSnapFirstMeal.
  ///
  /// In en, this message translates to:
  /// **'Snap your first meal'**
  String get dashboardSnapFirstMeal;

  /// No description provided for @mealsNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get mealsNothingYet;

  /// No description provided for @dashboardWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT'**
  String get dashboardWeightTitle;

  /// No description provided for @dashboardWeightSinceStart.
  ///
  /// In en, this message translates to:
  /// **'{delta} kg since start'**
  String dashboardWeightSinceStart(String delta);

  /// No description provided for @snackIdeaTitle.
  ///
  /// In en, this message translates to:
  /// **'Snack idea'**
  String get snackIdeaTitle;

  /// No description provided for @snackIdeaHearty.
  ///
  /// In en, this message translates to:
  /// **'You’ve got room for a proper snack — nuts, ayran with flatbread, or cottage cheese with fruit.'**
  String get snackIdeaHearty;

  /// No description provided for @snackIdeaLight.
  ///
  /// In en, this message translates to:
  /// **'A light bite fits nicely — an apple, a yogurt, or a small handful of nuts.'**
  String get snackIdeaLight;

  /// No description provided for @snackIdeaTiny.
  ///
  /// In en, this message translates to:
  /// **'Almost there for today — tea, a few berries or a cucumber if you feel peckish.'**
  String get snackIdeaTiny;

  /// No description provided for @mealsEstimatedMacros.
  ///
  /// In en, this message translates to:
  /// **'~P{p} F{f} C{c}'**
  String mealsEstimatedMacros(int p, int f, int c);

  /// No description provided for @dashboardOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing local data'**
  String get dashboardOffline;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @dashboardMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'PROTEIN'**
  String get dashboardMacroProtein;

  /// No description provided for @dashboardMacroFat.
  ///
  /// In en, this message translates to:
  /// **'FAT'**
  String get dashboardMacroFat;

  /// No description provided for @dashboardMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'CARBS'**
  String get dashboardMacroCarbs;

  /// No description provided for @dashboardMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get dashboardMeals;

  /// No description provided for @dashboardKcalUnit.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get dashboardKcalUnit;

  /// No description provided for @dashboardKcalWithValue.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String dashboardKcalWithValue(int kcal);

  /// No description provided for @dashboardEmptyMeal.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add'**
  String get dashboardEmptyMeal;

  /// No description provided for @dashboardStreakDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get dashboardStreakDays;

  /// No description provided for @dashboardStreakLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String dashboardStreakLine(int count);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get navMeals;

  /// No description provided for @navCameraAction.
  ///
  /// In en, this message translates to:
  /// **'Scan a meal'**
  String get navCameraAction;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @dashboardStreakValue.
  ///
  /// In en, this message translates to:
  /// **'{n}'**
  String dashboardStreakValue(int n);

  /// No description provided for @gramsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{g} g'**
  String gramsSuffix(int g);

  /// Bare grams unit suffix (no number). Used in macro stats.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get gramsUnit;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @mealBreakfastLower.
  ///
  /// In en, this message translates to:
  /// **'breakfast'**
  String get mealBreakfastLower;

  /// No description provided for @mealLunchLower.
  ///
  /// In en, this message translates to:
  /// **'lunch'**
  String get mealLunchLower;

  /// No description provided for @mealDinnerLower.
  ///
  /// In en, this message translates to:
  /// **'dinner'**
  String get mealDinnerLower;

  /// No description provided for @mealSnackLower.
  ///
  /// In en, this message translates to:
  /// **'snack'**
  String get mealSnackLower;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get cameraPermissionTitle;

  /// No description provided for @cameraPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Settings to recognise dishes from photos.'**
  String get cameraPermissionBody;

  /// No description provided for @cameraOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get cameraOpenSettings;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera not available on the simulator'**
  String get cameraUnavailable;

  /// No description provided for @cameraUnavailableDevice.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available on this device'**
  String get cameraUnavailableDevice;

  /// No description provided for @cameraSimulate.
  ///
  /// In en, this message translates to:
  /// **'Simulate recognition'**
  String get cameraSimulate;

  /// No description provided for @cameraHint.
  ///
  /// In en, this message translates to:
  /// **'POINT AT THE DISH'**
  String get cameraHint;

  /// No description provided for @cameraLoading.
  ///
  /// In en, this message translates to:
  /// **'Recognising dish...'**
  String get cameraLoading;

  /// No description provided for @cameraNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Could not recognise the dish'**
  String get cameraNotRecognized;

  /// No description provided for @cameraErrorNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get cameraErrorNoNetwork;

  /// No description provided for @cameraErrorServer.
  ///
  /// In en, this message translates to:
  /// **'Service is temporarily unavailable'**
  String get cameraErrorServer;

  /// No description provided for @cameraConfidence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% match'**
  String cameraConfidence(int percent);

  /// No description provided for @cameraKcalPerPortion.
  ///
  /// In en, this message translates to:
  /// **'kcal per {g} g'**
  String cameraKcalPerPortion(int g);

  /// No description provided for @cameraMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get cameraMacroProtein;

  /// No description provided for @cameraMacroFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get cameraMacroFat;

  /// No description provided for @cameraMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get cameraMacroCarbs;

  /// No description provided for @cameraAddButton.
  ///
  /// In en, this message translates to:
  /// **'✓ Add to diary'**
  String get cameraAddButton;

  /// No description provided for @cameraRetake.
  ///
  /// In en, this message translates to:
  /// **'↺ Retake'**
  String get cameraRetake;

  /// No description provided for @cameraOutOfPhotos.
  ///
  /// In en, this message translates to:
  /// **'Your free scan for today is used'**
  String get cameraOutOfPhotos;

  /// No description provided for @cameraTryPro.
  ///
  /// In en, this message translates to:
  /// **'Try Pro'**
  String get cameraTryPro;

  /// No description provided for @cameraAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Added ✓'**
  String get cameraAddedSnack;

  /// No description provided for @cameraCounter.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String cameraCounter(int used, int limit);

  /// No description provided for @cameraDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cameraDialogCancel;

  /// No description provided for @paywallTitleLine1.
  ///
  /// In en, this message translates to:
  /// **'Eat smarter'**
  String get paywallTitleLine1;

  /// No description provided for @paywallTitleLine2.
  ///
  /// In en, this message translates to:
  /// **'with Salamat Pro'**
  String get paywallTitleLine2;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'1 free scan a day.\nWith Pro — 10 scans a day + forecast + analysis.'**
  String get paywallSubtitle;

  /// No description provided for @paywallLimitBadge.
  ///
  /// In en, this message translates to:
  /// **'Photo limit reached'**
  String get paywallLimitBadge;

  /// No description provided for @paywallFeature1Title.
  ///
  /// In en, this message translates to:
  /// **'10 photo scans a day'**
  String get paywallFeature1Title;

  /// No description provided for @paywallFeature1Sub.
  ///
  /// In en, this message translates to:
  /// **'Snap every meal'**
  String get paywallFeature1Sub;

  /// No description provided for @paywallFeature2Title.
  ///
  /// In en, this message translates to:
  /// **'Weight forecast'**
  String get paywallFeature2Title;

  /// No description provided for @paywallFeature2Sub.
  ///
  /// In en, this message translates to:
  /// **'See when you reach your goal'**
  String get paywallFeature2Sub;

  /// No description provided for @paywallFeature3Title.
  ///
  /// In en, this message translates to:
  /// **'Full history & trends'**
  String get paywallFeature3Title;

  /// No description provided for @paywallFeature3Sub.
  ///
  /// In en, this message translates to:
  /// **'Your whole food diary'**
  String get paywallFeature3Sub;

  /// No description provided for @paywallPopular.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get paywallPopular;

  /// No description provided for @paywallTrialButton.
  ///
  /// In en, this message translates to:
  /// **'Try free — 7 days'**
  String get paywallTrialButton;

  /// No description provided for @paywallCancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get paywallCancelAnytime;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get paywallRestore;

  /// No description provided for @paywallWelcomePro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pro'**
  String get paywallWelcomePro;

  /// No description provided for @paywallPurchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed — please try again'**
  String get paywallPurchaseError;

  /// No description provided for @paywallRestoreFound.
  ///
  /// In en, this message translates to:
  /// **'Pro restored'**
  String get paywallRestoreFound;

  /// No description provided for @paywallRestoreNotFound.
  ///
  /// In en, this message translates to:
  /// **'No purchases found'**
  String get paywallRestoreNotFound;

  /// No description provided for @paywallOfferingsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load prices from Google Play.\nCheck your connection and retry.'**
  String get paywallOfferingsError;

  /// No description provided for @paywallHeroHeadlineLose.
  ///
  /// In en, this message translates to:
  /// **'Get full access to\nyour weight-loss plan'**
  String get paywallHeroHeadlineLose;

  /// No description provided for @paywallHeroHeadlineGain.
  ///
  /// In en, this message translates to:
  /// **'Get full access to\nyour weight-gain plan'**
  String get paywallHeroHeadlineGain;

  /// No description provided for @paywallHeroHeadlineMaintain.
  ///
  /// In en, this message translates to:
  /// **'Get full access to\nyour balance plan'**
  String get paywallHeroHeadlineMaintain;

  /// No description provided for @paywallUrgencyLine.
  ///
  /// In en, this message translates to:
  /// **'Reach {weight} kg by {date}'**
  String paywallUrgencyLine(int weight, String date);

  /// No description provided for @paywallScanEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Recognized'**
  String get paywallScanEyebrow;

  /// No description provided for @paywallScanMeal.
  ///
  /// In en, this message translates to:
  /// **'Pilaf'**
  String get paywallScanMeal;

  /// No description provided for @paywallScanKcal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String paywallScanKcal(int kcal);

  /// No description provided for @paywallTier1mo.
  ///
  /// In en, this message translates to:
  /// **'1 MONTH'**
  String get paywallTier1mo;

  /// No description provided for @paywallTier12mo.
  ///
  /// In en, this message translates to:
  /// **'12 MONTHS'**
  String get paywallTier12mo;

  /// No description provided for @paywallPerMonthUnit.
  ///
  /// In en, this message translates to:
  /// **'/mo'**
  String get paywallPerMonthUnit;

  /// No description provided for @paywallPerMonthValue.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String paywallPerMonthValue(String price);

  /// No description provided for @paywallSaveBadge.
  ///
  /// In en, this message translates to:
  /// **'−{percent}%'**
  String paywallSaveBadge(int percent);

  /// No description provided for @paywallNoPaymentNow.
  ///
  /// In en, this message translates to:
  /// **'No payment now'**
  String get paywallNoPaymentNow;

  /// No description provided for @paywallFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Subscription renews automatically at the end of each period. Cancel anytime in your store account. Terms and Privacy apply.'**
  String get paywallFinePrint;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// No description provided for @profileBadgePro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get profileBadgePro;

  /// No description provided for @profileBadgeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get profileBadgeFree;

  /// No description provided for @profileStatDaysInApp.
  ///
  /// In en, this message translates to:
  /// **'days in Salamat'**
  String get profileStatDaysInApp;

  /// No description provided for @profileStatEntries.
  ///
  /// In en, this message translates to:
  /// **'dishes added'**
  String get profileStatEntries;

  /// No description provided for @profileStatStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get profileStatStreak;

  /// No description provided for @profileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get profileDataTitle;

  /// No description provided for @profileDataAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get profileDataAge;

  /// No description provided for @profileDataAgeValue.
  ///
  /// In en, this message translates to:
  /// **'{age} y'**
  String profileDataAgeValue(int age);

  /// No description provided for @profileDataHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileDataHeight;

  /// No description provided for @profileDataWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileDataWeight;

  /// No description provided for @profileDataGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get profileDataGoal;

  /// No description provided for @profileDataCalorieNorm.
  ///
  /// In en, this message translates to:
  /// **'Calorie target'**
  String get profileDataCalorieNorm;

  /// No description provided for @profileDataKcalUnit.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get profileDataKcalUnit;

  /// No description provided for @profileDataCmUnit.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get profileDataCmUnit;

  /// No description provided for @profileDataKgUnit.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get profileDataKgUnit;

  /// No description provided for @profileReferralTitle.
  ///
  /// In en, this message translates to:
  /// **'🎁 Invite a friend — get 7 days of Pro'**
  String get profileReferralTitle;

  /// No description provided for @profileReferralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'5 friends = one Pro week free'**
  String get profileReferralSubtitle;

  /// No description provided for @profileReferralCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get profileReferralCopy;

  /// No description provided for @profileReferralCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied!'**
  String get profileReferralCopied;

  /// No description provided for @profileSettingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileSettingNotifications;

  /// No description provided for @profileSettingMyGoal.
  ///
  /// In en, this message translates to:
  /// **'My goal'**
  String get profileSettingMyGoal;

  /// No description provided for @profileSettingUpdateWeight.
  ///
  /// In en, this message translates to:
  /// **'Update weight'**
  String get profileSettingUpdateWeight;

  /// No description provided for @profileSettingPro.
  ///
  /// In en, this message translates to:
  /// **'Salamat Pro'**
  String get profileSettingPro;

  /// No description provided for @profileSettingLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSettingLogout;

  /// No description provided for @profileSettingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profileSettingPrivacy;

  /// No description provided for @profileSettingTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get profileSettingTerms;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get profileDeleteDialogTitle;

  /// No description provided for @profileDeleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'All your data — profile, food history and weight — will be permanently deleted. This cannot be undone.'**
  String get profileDeleteDialogBody;

  /// No description provided for @profileDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDeleteConfirm;

  /// No description provided for @profileDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete account. Please try again later.'**
  String get profileDeleteError;

  /// No description provided for @paywallFinePrintPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get paywallFinePrintPrivacy;

  /// No description provided for @paywallFinePrintTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get paywallFinePrintTerms;

  /// No description provided for @profileSettingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileSettingLanguage;

  /// No description provided for @profileSoonSuffix.
  ///
  /// In en, this message translates to:
  /// **'{label} — soon'**
  String profileSoonSuffix(String label);

  /// No description provided for @profileUpdateWeightDialog.
  ///
  /// In en, this message translates to:
  /// **'Update weight'**
  String get profileUpdateWeightDialog;

  /// No description provided for @profileWeightHint.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get profileWeightHint;

  /// No description provided for @profileWeightRangeError.
  ///
  /// In en, this message translates to:
  /// **'Enter a weight between {min} and {max} kg'**
  String profileWeightRangeError(int min, int max);

  /// No description provided for @profileKgShort.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get profileKgShort;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @progressStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day in a row} other{{count} days in a row}}'**
  String progressStreak(int count);

  /// No description provided for @progressNextGoal.
  ///
  /// In en, this message translates to:
  /// **'Keep going — next goal is 7 days'**
  String get progressNextGoal;

  /// No description provided for @progressStreakStart.
  ///
  /// In en, this message translates to:
  /// **'Start today'**
  String get progressStreakStart;

  /// No description provided for @progressStreakStartHint.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal to start a streak'**
  String get progressStreakStartHint;

  /// No description provided for @progressHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data yet. Add meals and your history will appear here.'**
  String get progressHistoryEmpty;

  /// No description provided for @progressToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get progressToday;

  /// No description provided for @progressHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get progressHistory;

  /// No description provided for @progressOfNormKcal.
  ///
  /// In en, this message translates to:
  /// **'of {norm} kcal'**
  String progressOfNormKcal(int norm);

  /// No description provided for @progressMacroProtein.
  ///
  /// In en, this message translates to:
  /// **'g protein'**
  String get progressMacroProtein;

  /// No description provided for @progressMacroFat.
  ///
  /// In en, this message translates to:
  /// **'g fat'**
  String get progressMacroFat;

  /// No description provided for @progressMacroCarbs.
  ///
  /// In en, this message translates to:
  /// **'g carbs'**
  String get progressMacroCarbs;

  /// No description provided for @progressDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get progressDayMon;

  /// No description provided for @progressDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get progressDayTue;

  /// No description provided for @progressDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get progressDayWed;

  /// No description provided for @progressDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get progressDayThu;

  /// No description provided for @progressDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get progressDayFri;

  /// No description provided for @progressDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get progressDaySat;

  /// No description provided for @progressDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get progressDayToday;

  /// No description provided for @languageRu.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSelectTitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ru': return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
