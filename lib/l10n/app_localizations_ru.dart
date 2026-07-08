// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Salamat';

  @override
  String get buttonContinue => 'Продолжить';

  @override
  String get buttonNext => 'Далее';

  @override
  String get buttonStart => 'Начать';

  @override
  String get buttonYes => 'Да';

  @override
  String get buttonNo => 'Нет';

  @override
  String get buttonCancel => 'Отмена';

  @override
  String get buttonSave => 'Сохранить';

  @override
  String get valueDash => '—';

  @override
  String get manualTitle => 'Добавить блюдо вручную';

  @override
  String get manualNameLabel => 'Название блюда';

  @override
  String get manualKcalLabel => 'Калории (ккал)';

  @override
  String get manualKcalError => 'Введите 1–5000 ккал';

  @override
  String get manualAddDetails => 'Добавить детали';

  @override
  String get manualProtein => 'Белки, г';

  @override
  String get manualFat => 'Жиры, г';

  @override
  String get manualCarbs => 'Углеводы, г';

  @override
  String get manualPortion => 'Порция, г';

  @override
  String manualAddToMeal(String meal) {
    return 'Добавить в $meal';
  }

  @override
  String manualAddedSnack(String meal) {
    return 'Добавлено в $meal ✓';
  }

  @override
  String get manualAddButton => 'Добавить вручную';

  @override
  String get limitTitle => 'Бесплатный скан на сегодня использован';

  @override
  String get limitGoPro => 'Перейти на Pro';

  @override
  String get welcomeFreeLine => 'Бесплатно · 1 фото-скан в день · ручной ввод без ограничений';

  @override
  String get welcomeHeadline => 'Ваш вес БУДЕТ\nдостигнут в нашем\nприложении';

  @override
  String get welcomeSubtitle => 'Начнём с нескольких вопросов\nдля вашего персонального плана';

  @override
  String get nameTitle => 'Как вас зовут?';

  @override
  String get nameSubtitle => 'Чтобы обращаться к вам';

  @override
  String get nameFieldHint => 'Ваше имя';

  @override
  String get countryTitle => 'Откуда вы?';

  @override
  String get countrySubtitle => 'Чтобы показывать цены в вашей валюте';

  @override
  String get countryKZ => 'Казахстан';

  @override
  String get countryKG => 'Кыргызстан';

  @override
  String get countryUZ => 'Узбекистан';

  @override
  String get countryTJ => 'Таджикистан';

  @override
  String get countryTM => 'Туркменистан';

  @override
  String get countryRU => 'Россия';

  @override
  String get countryOther => 'Другая';

  @override
  String get goalTitle => 'Какая ваша\nглавная цель?';

  @override
  String get goalSubtitle => 'Выберите одну — под неё подберём план';

  @override
  String get goalLose => 'Похудеть';

  @override
  String get goalLoseSub => 'Снижение веса, дефицит калорий';

  @override
  String get goalGain => 'Набрать вес';

  @override
  String get goalGainSub => 'Рост массы, профицит калорий';

  @override
  String get goalMaintain => 'Поддерживать';

  @override
  String get goalMaintainSub => 'Удержание текущего веса';

  @override
  String get goalHealthy => 'Здоровое питание';

  @override
  String get goalHealthySub => 'Контроль БЖУ, осознанность';

  @override
  String get genderTitle => 'Ваш пол?';

  @override
  String get genderSubtitle => 'Нужно для точного расчёта нормы калорий';

  @override
  String get genderFemale => 'Женщина';

  @override
  String get genderMale => 'Мужчина';

  @override
  String get yearTitle => 'В каком году\nвы родились?';

  @override
  String get yearSubtitle => 'Возраст влияет на расчёт нормы калорий';

  @override
  String yearAgeLabel(int age) {
    return 'Вам $age';
  }

  @override
  String yearMinAgeWarning(int min) {
    return 'Приложение доступно с $min лет';
  }

  @override
  String get weightTitle => 'Ваш рост и\nтекущий вес?';

  @override
  String get weightSubtitle => 'От этого зависит точность плана';

  @override
  String get weightHeightLabel => 'Рост';

  @override
  String get weightWeightLabel => 'Вес';

  @override
  String weightHeightValue(int cm) {
    return '$cm см';
  }

  @override
  String weightWeightValue(int kg) {
    return '$kg кг';
  }

  @override
  String get bmiLabel => 'ИМТ';

  @override
  String get bmiBandUnder => 'Чуть ниже нормы';

  @override
  String get bmiBandNormal => 'Норма';

  @override
  String get bmiBandOver => 'Чуть выше нормы';

  @override
  String get bmiBandObese => 'Ожирение';

  @override
  String get targetTitle => 'Какой ваш\nцелевой вес?';

  @override
  String get targetSubtitle => 'Реалистичная цель — главный фактор успеха';

  @override
  String targetDeltaLose(int kg) {
    return 'Сбросить $kg кг';
  }

  @override
  String targetDeltaGain(int kg) {
    return 'Набрать $kg кг';
  }

  @override
  String get targetDeltaMaintain => 'Удерживать вес';

  @override
  String get underweightWarningTitle => 'Снижение веса может быть небезопасно';

  @override
  String get underweightWarningBody => 'Ваш индекс массы тела ниже нормы. Снижение веса при таком показателе может навредить здоровью. Рекомендуем проконсультироваться с врачом перед началом.';

  @override
  String get underweightWarningChangeGoal => 'Выбрать другую цель';

  @override
  String get underweightWarningProceed => 'Понимаю, продолжить';

  @override
  String celebrationLose(int kg) {
    return 'Похудеть на $kg кг — реальная цель.\nЭто совсем не сложно!';
  }

  @override
  String celebrationGain(int kg) {
    return 'Набрать $kg кг — реальная цель.\nЭто совсем не сложно!';
  }

  @override
  String get celebrationMaintain => 'Отличный выбор —\nудерживать здоровый вес';

  @override
  String get celebrationStatLose => 'Снижение веса на 5%\nуже улучшает здоровье';

  @override
  String get celebrationStatGain => 'Постепенный набор 0,25–0,5 кг в неделю\nпомогает набирать мышцы, а не жир';

  @override
  String get celebrationStatMaintain => 'Стабильный вес снижает риски\nдля сердца и обмена веществ';

  @override
  String get longTermTitle => 'Salamat создаёт\nдолгосрочный\nрезультат';

  @override
  String get longTermLegendSalamat => 'План Salamat';

  @override
  String get longTermLegendOthers => 'Обычные диеты';

  @override
  String get longTermStat => '76% пользователей Salamat удерживают вес\nболее 6 месяцев';

  @override
  String get familiarityTitle => 'Насколько вы знакомы\nс темой похудения?';

  @override
  String get familiarityHint => '75% ответили так же.\nSalamat проведёт вас по пути похудения.';

  @override
  String get familiarityNovice => 'Новичок';

  @override
  String get familiarityNoviceSub => 'Только начинаю разбираться';

  @override
  String get familiarityIntermediate => 'Средний';

  @override
  String get familiarityIntermediateSub => 'Кое-что знаю и пробовал';

  @override
  String get familiarityExpert => 'Эксперт';

  @override
  String get familiarityExpertSub => 'Хорошо разбираюсь в теме';

  @override
  String get activityTitle => 'Какой у вас\nуровень активности?';

  @override
  String get activitySubtitle => 'Чем выше активность, тем больше можно есть';

  @override
  String get activitySedentary => 'Малоподвижный';

  @override
  String get activitySedentarySub => 'Сидячая работа, мало движения';

  @override
  String get activityLight => 'Лёгкая активность';

  @override
  String get activityLightSub => '1–3 тренировки в неделю';

  @override
  String get activityModerate => 'Средняя активность';

  @override
  String get activityModerateSub => '3–5 тренировок в неделю';

  @override
  String get activityVery => 'Высокая активность';

  @override
  String get activityVerySub => '6–7 тренировок в неделю';

  @override
  String get summaryTitle => 'Ваш персональный\nплан';

  @override
  String get summaryStatBmi => 'ИМТ';

  @override
  String get summaryStatTarget => 'Целевой вес';

  @override
  String get summaryStatLevel => 'Уровень';

  @override
  String get summaryStatActivity => 'Активность';

  @override
  String get yesLoseQuestion => 'Хотите похудеть?';

  @override
  String get yesGainQuestion => 'Хотите набрать вес\nбез вреда для здоровья?';

  @override
  String get yesMaintainQuestion => 'Хотите удерживать\nкомфортный вес?';

  @override
  String get yesOrderQuestion => 'Хотите навести\nпорядок в питании?';

  @override
  String get yesHealthQuestion => 'Хотите попрощаться\nс проблемами здоровья?';

  @override
  String get yesCaptionBefore => 'Сейчас';

  @override
  String get yesCaptionAfter => 'С Salamat';

  @override
  String get comparisonTitle => 'Худейте в 2×\nбыстрее с Salamat';

  @override
  String get comparisonWithout => 'Без Salamat';

  @override
  String get comparisonWith => 'С Salamat';

  @override
  String get comparisonStat => '78% пользователей достигают долгосрочного\nрезультата с Salamat';

  @override
  String get socialTitle => 'Salamat создан\nдля таких людей,\nкак вы!';

  @override
  String get socialUsersCount => '1 000 000';

  @override
  String get socialUsersLabel => 'пользователей Salamat';

  @override
  String get socialStatPercent => '83%';

  @override
  String get socialStatText => 'пользователей говорят, что наш план\nлегко соблюдать';

  @override
  String get buildingTitle => 'Создаём вашу\nпрограмму...';

  @override
  String get buildingStep1 => 'Анализ профиля';

  @override
  String get buildingStep2 => 'Расчёт метаболизма';

  @override
  String get buildingStep3 => 'Создание плана питания';

  @override
  String get planTitle => 'Ваш персональный\nплан готов';

  @override
  String get planNow => 'Сейчас';

  @override
  String get planTarget => 'Цель';

  @override
  String planWeeksToTarget(int weeks) {
    return 'Около $weeks нед. до цели';
  }

  @override
  String get planMaintain => 'Удерживать вес';

  @override
  String get planCaloriesLabel => 'Ваша норма калорий';

  @override
  String planCaloriesValue(int kcal) {
    return '$kcal ккал / день';
  }

  @override
  String planReachLine(int kg, String month) {
    return 'Примерно в $month вы достигнете $kg кг';
  }

  @override
  String get planStartTracking => 'Начать трекинг';

  @override
  String dashboardGreeting(String name) {
    return 'Привет, $name 👋';
  }

  @override
  String get dashboardGuestName => 'друг';

  @override
  String get dashboardCaloriesLabel => 'КАЛОРИИ';

  @override
  String dashboardConsumedOfNorm(int norm) {
    return 'из $norm ккал';
  }

  @override
  String dashboardLeft(int left) {
    return 'осталось $left';
  }

  @override
  String dashboardOverflow(int over) {
    return 'перебор $over';
  }

  @override
  String get dashboardLeftLabel => 'осталось';

  @override
  String get dashboardOverflowLabel => 'перебор';

  @override
  String get dashboardLastMeal => 'ПОСЛЕДНИЙ ПРИЁМ';

  @override
  String get dashboardCaloriesBudget => 'Бюджет калорий';

  @override
  String get dashboardWater => 'Вода';

  @override
  String dashboardWaterLiters(String n) {
    return '$n л';
  }

  @override
  String get dashboardSnapFirstMeal => 'Сфотографируй первое блюдо';

  @override
  String get dashboardOffline => 'Офлайн — показаны локальные данные';

  @override
  String get retryButton => 'Повторить';

  @override
  String get dashboardMacroProtein => 'БЕЛКИ';

  @override
  String get dashboardMacroFat => 'ЖИРЫ';

  @override
  String get dashboardMacroCarbs => 'УГЛЕВ.';

  @override
  String get dashboardMeals => 'Приёмы пищи';

  @override
  String get dashboardKcalUnit => 'ккал';

  @override
  String dashboardKcalWithValue(int kcal) {
    return '$kcal ккал';
  }

  @override
  String get dashboardEmptyMeal => 'Нажми + чтобы добавить';

  @override
  String get dashboardStreakDays => 'дней';

  @override
  String dashboardStreakLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '1 день',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Главная';

  @override
  String get navProgress => 'Прогресс';

  @override
  String get navProfile => 'Профиль';

  @override
  String dashboardStreakValue(int n) {
    return '$n';
  }

  @override
  String gramsSuffix(int g) {
    return '$g г';
  }

  @override
  String get gramsUnit => 'г';

  @override
  String get mealBreakfast => 'Завтрак';

  @override
  String get mealLunch => 'Обед';

  @override
  String get mealDinner => 'Ужин';

  @override
  String get mealSnack => 'Перекус';

  @override
  String get mealBreakfastLower => 'завтрак';

  @override
  String get mealLunchLower => 'обед';

  @override
  String get mealDinnerLower => 'ужин';

  @override
  String get mealSnackLower => 'перекус';

  @override
  String get cameraPermissionTitle => 'Нужен доступ к камере';

  @override
  String get cameraPermissionBody => 'Разреши доступ к камере в настройках, чтобы распознавать блюда на фото.';

  @override
  String get cameraOpenSettings => 'Открыть настройки';

  @override
  String get cameraUnavailable => 'Камера недоступна на симуляторе';

  @override
  String get cameraUnavailableDevice => 'Камера недоступна на этом устройстве';

  @override
  String get cameraSimulate => 'Симулировать распознавание';

  @override
  String get cameraHint => 'НАВЕДИ НА БЛЮДО';

  @override
  String get cameraLoading => 'Определяю блюдо...';

  @override
  String get cameraNotRecognized => 'Не удалось определить блюдо';

  @override
  String get cameraErrorNoNetwork => 'Нет подключения к интернету';

  @override
  String get cameraErrorServer => 'Сервис временно недоступен';

  @override
  String cameraConfidence(int percent) {
    return '$percent% совпадение';
  }

  @override
  String cameraKcalPerPortion(int g) {
    return 'ккал на $g г';
  }

  @override
  String get cameraMacroProtein => 'Белки';

  @override
  String get cameraMacroFat => 'Жиры';

  @override
  String get cameraMacroCarbs => 'Углеводы';

  @override
  String get cameraAddButton => '✓ Добавить в дневник';

  @override
  String get cameraRetake => '↺ Переснять';

  @override
  String get cameraOutOfPhotos => 'Бесплатный скан на сегодня использован';

  @override
  String get cameraTryPro => 'Попробовать Pro';

  @override
  String get cameraAddedSnack => 'Добавлено ✓';

  @override
  String cameraCounter(int used, int limit) {
    return '$used из $limit';
  }

  @override
  String get cameraDialogCancel => 'Отмена';

  @override
  String get paywallTitleLine1 => 'Питайся умнее';

  @override
  String get paywallTitleLine2 => 'с Salamat Pro';

  @override
  String get paywallSubtitle => '1 бесплатный скан в день.\nС Pro — 10 сканов в день + прогноз + анализ.';

  @override
  String get paywallLimitBadge => 'Лимит фото исчерпан';

  @override
  String get paywallFeature1Title => '10 фото-сканов в день';

  @override
  String get paywallFeature1Sub => 'Фотай каждый приём пищи';

  @override
  String get paywallFeature2Title => 'Прогноз веса';

  @override
  String get paywallFeature2Sub => 'Видишь когда достигнешь цели';

  @override
  String get paywallFeature3Title => 'Полная история и тренды';

  @override
  String get paywallFeature3Sub => 'Весь дневник питания';

  @override
  String get paywallPopular => 'Выгоднее всего';

  @override
  String get paywallTrialButton => 'Попробовать бесплатно — 7 дней';

  @override
  String get paywallCancelAnytime => 'Отменить в любой момент';

  @override
  String get paywallStub => 'Оплата в разработке — скоро!';

  @override
  String get paywallRestore => 'Восстановить';

  @override
  String get paywallHeroHeadlineLose => 'Полный доступ к вашему\nплану похудения';

  @override
  String get paywallHeroHeadlineGain => 'Полный доступ к вашему\nплану набора веса';

  @override
  String get paywallHeroHeadlineMaintain => 'Полный доступ к вашему\nплану баланса';

  @override
  String paywallUrgencyLine(int weight, String date) {
    return 'Достигнете $weight кг к $date';
  }

  @override
  String get paywallScanEyebrow => 'Распознано';

  @override
  String get paywallScanMeal => 'Плов';

  @override
  String paywallScanKcal(int kcal) {
    return '$kcal ккал';
  }

  @override
  String get paywallTier1mo => '1 МЕСЯЦ';

  @override
  String get paywallTier12mo => '12 МЕСЯЦЕВ';

  @override
  String get paywallPerMonthUnit => '/мес';

  @override
  String paywallPerMonthValue(String price) {
    return '$price/мес';
  }

  @override
  String paywallSaveBadge(int percent) {
    return '−$percent%';
  }

  @override
  String get paywallNoPaymentNow => 'Без оплаты сейчас';

  @override
  String get paywallFinePrint => 'Подписка продлевается автоматически в конце каждого периода. Отмените в любой момент в аккаунте магазина. Действуют Условия и Политика конфиденциальности.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileGuest => 'Гость';

  @override
  String get profileBadgePro => 'Pro';

  @override
  String get profileBadgeFree => 'Free';

  @override
  String get profileStatDaysInApp => 'день в Salamat';

  @override
  String get profileStatEntries => 'блюд добавлено';

  @override
  String get profileStatStreak => 'день подряд';

  @override
  String get profileDataTitle => 'Мои данные';

  @override
  String get profileDataAge => 'Возраст';

  @override
  String profileDataAgeValue(int age) {
    return '$age лет';
  }

  @override
  String get profileDataHeight => 'Рост';

  @override
  String get profileDataWeight => 'Вес';

  @override
  String get profileDataGoal => 'Цель';

  @override
  String get profileDataCalorieNorm => 'Норма ккал';

  @override
  String get profileDataKcalUnit => 'ккал';

  @override
  String get profileDataCmUnit => 'см';

  @override
  String get profileDataKgUnit => 'кг';

  @override
  String get profileReferralTitle => '🎁 Пригласи друга — получи 7 дней Pro';

  @override
  String get profileReferralSubtitle => '5 друзей = неделя Pro бесплатно';

  @override
  String get profileReferralCopy => 'Скопировать ссылку';

  @override
  String get profileReferralCopied => 'Ссылка скопирована!';

  @override
  String get profileSettingNotifications => 'Уведомления';

  @override
  String get profileSettingMyGoal => 'Моя цель';

  @override
  String get profileSettingUpdateWeight => 'Обновить вес';

  @override
  String get profileSettingPro => 'Salamat Pro';

  @override
  String get profileSettingLogout => 'Выйти';

  @override
  String get profileSettingPrivacy => 'Политика конфиденциальности';

  @override
  String get profileSettingTerms => 'Условия использования';

  @override
  String get profileDeleteAccount => 'Удалить аккаунт';

  @override
  String get profileDeleteDialogTitle => 'Удалить аккаунт?';

  @override
  String get profileDeleteDialogBody => 'Все ваши данные — профиль, история питания и вес — будут удалены безвозвратно. Это действие нельзя отменить.';

  @override
  String get profileDeleteConfirm => 'Удалить';

  @override
  String get profileDeleteError => 'Не удалось удалить аккаунт. Попробуйте позже.';

  @override
  String get paywallFinePrintPrivacy => 'Политика конфиденциальности';

  @override
  String get paywallFinePrintTerms => 'Условия';

  @override
  String get profileSettingLanguage => 'Язык';

  @override
  String profileSoonSuffix(String label) {
    return '$label — скоро';
  }

  @override
  String get profileUpdateWeightDialog => 'Обновить вес';

  @override
  String get profileWeightHint => 'Вес (кг)';

  @override
  String profileWeightRangeError(int min, int max) {
    return 'Введите вес от $min до $max кг';
  }

  @override
  String get profileKgShort => 'кг';

  @override
  String get progressTitle => 'Прогресс';

  @override
  String progressStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней подряд',
      many: '$count дней подряд',
      few: '$count дня подряд',
      one: '1 день подряд',
    );
    return '$_temp0';
  }

  @override
  String get progressNextGoal => 'Продолжай — следующая цель 7 дней';

  @override
  String get progressStreakStart => 'Начни сегодня';

  @override
  String get progressStreakStartHint => 'Отметь первый приём пищи — серия начнётся';

  @override
  String get progressHistoryEmpty => 'Пока нет данных. Добавляй блюда — история появится здесь.';

  @override
  String get progressToday => 'Сегодня';

  @override
  String get progressHistory => 'История';

  @override
  String progressOfNormKcal(int norm) {
    return 'из $norm ккал';
  }

  @override
  String get progressMacroProtein => 'г белков';

  @override
  String get progressMacroFat => 'г жиров';

  @override
  String get progressMacroCarbs => 'г углеводов';

  @override
  String get progressDayMon => 'Пн';

  @override
  String get progressDayTue => 'Вт';

  @override
  String get progressDayWed => 'Ср';

  @override
  String get progressDayThu => 'Чт';

  @override
  String get progressDayFri => 'Пт';

  @override
  String get progressDaySat => 'Сб';

  @override
  String get progressDayToday => 'Сегодня';

  @override
  String get languageRu => 'Русский';

  @override
  String get languageEn => 'English';

  @override
  String get languageSelectTitle => 'Язык';
}
