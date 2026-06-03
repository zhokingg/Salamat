import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Gender { male, female }

extension GenderLoc on Gender {
  String label(AppLocalizations loc) => switch (this) {
        Gender.male => loc.genderMale,
        Gender.female => loc.genderFemale,
      };
}

enum Goal { lose, gain, maintain, healthy }

extension GoalLoc on Goal {
  String label(AppLocalizations loc) => switch (this) {
        Goal.lose => loc.goalLose,
        Goal.gain => loc.goalGain,
        Goal.maintain => loc.goalMaintain,
        Goal.healthy => loc.goalHealthy,
      };

  String subtitle(AppLocalizations loc) => switch (this) {
        Goal.lose => loc.goalLoseSub,
        Goal.gain => loc.goalGainSub,
        Goal.maintain => loc.goalMaintainSub,
        Goal.healthy => loc.goalHealthySub,
      };
}

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  veryActive(1.725);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

extension ActivityLevelLoc on ActivityLevel {
  String label(AppLocalizations loc) => switch (this) {
        ActivityLevel.sedentary => loc.activitySedentary,
        ActivityLevel.light => loc.activityLight,
        ActivityLevel.moderate => loc.activityModerate,
        ActivityLevel.veryActive => loc.activityVery,
      };

  String subtitle(AppLocalizations loc) => switch (this) {
        ActivityLevel.sedentary => loc.activitySedentarySub,
        ActivityLevel.light => loc.activityLightSub,
        ActivityLevel.moderate => loc.activityModerateSub,
        ActivityLevel.veryActive => loc.activityVerySub,
      };
}

enum Familiarity { novice, intermediate, expert }

/// Country selection from the onboarding country screen. The flag is purely
/// visual; the code (`KZ`, `KG`, etc.) drives currency lookup.
enum Country {
  kz('KZ', '🇰🇿'),
  kg('KG', '🇰🇬'),
  uz('UZ', '🇺🇿'),
  tj('TJ', '🇹🇯'),
  tm('TM', '🇹🇲'),
  ru('RU', '🇷🇺'),
  other('OTHER', '🌍');

  const Country(this.code, this.flag);
  final String code;
  final String flag;

  /// Best-effort map from a device ISO country code (e.g. "KZ", "US") to our
  /// supported `Country` enum. Anything we don't price natively → `other`.
  static Country fromDeviceCode(String? deviceCode) {
    if (deviceCode == null) return Country.other;
    final c = deviceCode.toUpperCase();
    for (final v in Country.values) {
      if (v.code == c) return v;
    }
    return Country.other;
  }
}

extension CountryLoc on Country {
  String label(AppLocalizations loc) => switch (this) {
        Country.kz => loc.countryKZ,
        Country.kg => loc.countryKG,
        Country.uz => loc.countryUZ,
        Country.tj => loc.countryTJ,
        Country.tm => loc.countryTM,
        Country.ru => loc.countryRU,
        Country.other => loc.countryOther,
      };
}

extension FamiliarityLoc on Familiarity {
  String label(AppLocalizations loc) => switch (this) {
        Familiarity.novice => loc.familiarityNovice,
        Familiarity.intermediate => loc.familiarityIntermediate,
        Familiarity.expert => loc.familiarityExpert,
      };

  String subtitle(AppLocalizations loc) => switch (this) {
        Familiarity.novice => loc.familiarityNoviceSub,
        Familiarity.intermediate => loc.familiarityIntermediateSub,
        Familiarity.expert => loc.familiarityExpertSub,
      };
}

class UserState {
  const UserState({
    this.name = '',
    this.lastName = '',
    this.gender,
    this.goal,
    this.age,
    this.height,
    this.weight,
    this.targetWeight,
    this.activityLevel,
    this.familiarity,
    this.calorieNorm,
    this.country,
  });

  final String name;
  final String lastName;
  final Gender? gender;
  final Goal? goal;
  final int? age;
  final double? height;
  final double? weight;
  final double? targetWeight;
  final ActivityLevel? activityLevel;
  final Familiarity? familiarity;
  final int? calorieNorm;
  final Country? country;

  String get initials {
    final a = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '';
    final b = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    return '$a$b';
  }

  double get weightDelta {
    if (weight == null || targetWeight == null) return 0;
    return weight! - targetWeight!;
  }

  double get bmi {
    if (height == null || weight == null || height! <= 0) return 0;
    final m = height! / 100.0;
    return weight! / (m * m);
  }

  /// Untranslated BMI band key. Use [bmiBandLabel] for a localized string.
  BmiBand get bmiBand {
    final b = bmi;
    if (b == 0) return BmiBand.unknown;
    if (b < 18.5) return BmiBand.under;
    if (b < 25.0) return BmiBand.normal;
    if (b < 30.0) return BmiBand.over;
    return BmiBand.obese;
  }

  String bmiBandLabel(AppLocalizations loc) {
    switch (bmiBand) {
      case BmiBand.unknown:
        return '';
      case BmiBand.under:
        return loc.bmiBandUnder;
      case BmiBand.normal:
        return loc.bmiBandNormal;
      case BmiBand.over:
        return loc.bmiBandOver;
      case BmiBand.obese:
        return loc.bmiBandObese;
    }
  }

  UserState copyWith({
    String? name,
    String? lastName,
    Gender? gender,
    Goal? goal,
    int? age,
    double? height,
    double? weight,
    double? targetWeight,
    ActivityLevel? activityLevel,
    Familiarity? familiarity,
    int? calorieNorm,
    Country? country,
  }) {
    return UserState(
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      activityLevel: activityLevel ?? this.activityLevel,
      familiarity: familiarity ?? this.familiarity,
      calorieNorm: calorieNorm ?? this.calorieNorm,
      country: country ?? this.country,
    );
  }
}

enum BmiBand { unknown, under, normal, over, obese }

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => const UserState();

  void setName({required String name, required String lastName}) {
    state = state.copyWith(name: name, lastName: lastName);
  }

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender);
  }

  void setGoal(Goal goal) {
    state = state.copyWith(goal: goal);
  }

  void setAge(int age) {
    state = state.copyWith(age: age);
  }

  void setBody({required double height, required double weight}) {
    state = state.copyWith(height: height, weight: weight);
  }

  void setTargetWeight(double targetWeight) {
    state = state.copyWith(targetWeight: targetWeight);
  }

  void setActivityLevel(ActivityLevel level) {
    state = state.copyWith(activityLevel: level);
  }

  void setFamiliarity(Familiarity familiarity) {
    state = state.copyWith(familiarity: familiarity);
  }

  void setCalorieNorm(int norm) {
    state = state.copyWith(calorieNorm: norm);
  }

  void setCountry(Country country) {
    state = state.copyWith(country: country);
  }
}

final userProvider = NotifierProvider<UserNotifier, UserState>(UserNotifier.new);
