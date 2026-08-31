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
  String get manualKcalError => 'Введи 1–5000 ккал';

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
  String scansLeftOf(int left, int total) {
    return 'Осталось $left из $total';
  }

  @override
  String get scansUnlimited => 'Без ограничений';

  @override
  String get scansExhaustedTitle => 'Это был последний бесплатный скан';

  @override
  String get scansExhaustedBody =>
      'Ручной ввод остаётся бесплатным и безлимитным. Оформи подписку, чтобы сканировать по фото дальше.';

  @override
  String get scansLater => 'Не сейчас';

  @override
  String get limitTitle => 'Три бесплатных скана использованы';

  @override
  String get limitGoPro => 'Перейти на Pro';

  @override
  String get welcomeFreeLine =>
      'Бесплатно · 3 фото-скана за всё время · ручной ввод без ограничений';

  @override
  String get welcomeHeadline =>
      'Фотографируй еду —\nи видишь, из чего\nскладывается день';

  @override
  String get welcomeSubtitle =>
      'Начнём с нескольких вопросов\nдля твоего персонального плана';

  @override
  String get nameTitle => 'Как тебя зовут?';

  @override
  String get nameSubtitle => 'Чтобы обращаться к тебе';

  @override
  String get nameFieldHint => 'Твоё имя';

  @override
  String get countryTitle => 'Откуда ты?';

  @override
  String get countrySubtitle => 'Чтобы показывать цены в твоей валюте';

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
  String get goalTitle => 'Какая твоя\nглавная цель?';

  @override
  String get goalSubtitle => 'Выбери одну — под неё подберём план';

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
  String get genderTitle => 'Твой пол?';

  @override
  String get genderSubtitle => 'Нужно для точного расчёта нормы калорий';

  @override
  String get genderFemale => 'Женщина';

  @override
  String get genderMale => 'Мужчина';

  @override
  String get yearTitle => 'Твой год\nрождения?';

  @override
  String get yearSubtitle => 'Возраст влияет на расчёт нормы калорий';

  @override
  String yearAgeLabel(int age) {
    return 'Тебе $age';
  }

  @override
  String yearMinAgeWarning(int min) {
    return 'Приложение доступно с $min лет';
  }

  @override
  String get weightTitle => 'Твой рост и\nтекущий вес?';

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
  String get targetTitle => 'Какой твой\nцелевой вес?';

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
  String targetConflictLose(int current) {
    return 'Цель — похудеть, поэтому целевой вес должен быть ниже текущего: $current кг.';
  }

  @override
  String targetConflictGain(int current) {
    return 'Цель — набрать, поэтому целевой вес должен быть выше текущего: $current кг.';
  }

  @override
  String get targetDeltaMaintain => 'Удерживать вес';

  @override
  String get underweightWarningTitle => 'Снижение веса может быть небезопасно';

  @override
  String get underweightWarningBody =>
      'Твой индекс массы тела ниже нормы. Снижение веса при таком показателе может навредить здоровью. Рекомендуем проконсультироваться с врачом перед началом.';

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
  String get celebrationStatLose =>
      'Общее наблюдение медицины: снижение веса\nна 5% уже улучшает здоровье';

  @override
  String get celebrationStatGain =>
      'Общее наблюдение медицины: набор 0,25–0,5 кг\nв неделю даёт мышцы, а не жир';

  @override
  String get celebrationStatMaintain =>
      'Общее наблюдение медицины: стабильный вес\nснижает риски для сердца и обмена веществ';

  @override
  String get longTermTitle => 'Salamat создаёт\nдолгосрочный\nрезультат';

  @override
  String get longTermLegendSalamat => 'Постепенные изменения';

  @override
  String get longTermLegendOthers => 'Строгие диеты';

  @override
  String get longTermApproach =>
      'Salamat делает ставку на постепенные\nизменения, а не на строгие диеты';

  @override
  String get familiarityTitle => 'Твой опыт\nв похудении?';

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
  String get activityTitle => 'Какой у тебя\nуровень активности?';

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
  String get summaryTitle => 'Твой персональный\nплан';

  @override
  String get summaryStatBmi => 'ИМТ';

  @override
  String get summaryStatTarget => 'Целевой вес';

  @override
  String get summaryStatLevel => 'Уровень';

  @override
  String get summaryStatActivity => 'Активность';

  @override
  String get yesLoseQuestion => 'Хочешь похудеть?';

  @override
  String get yesGainQuestion => 'Хочешь набрать вес\nбез вреда для здоровья?';

  @override
  String get yesMaintainQuestion => 'Хочешь удерживать\nкомфортный вес?';

  @override
  String get yesOrderQuestion => 'Хочешь навести\nпорядок в питании?';

  @override
  String get yesHealthQuestion => 'Хочешь попрощаться\nс проблемами здоровья?';

  @override
  String get yesCaptionBefore => 'Сейчас';

  @override
  String get yesCaptionAfter => 'С Salamat';

  @override
  String get comparisonTitle => 'Что даёт тебе\nSalamat';

  @override
  String get comparisonFeaturePhoto => 'Логируй еду по фото за секунды';

  @override
  String get comparisonFeatureNumbers => 'Твои привычки — в наглядных цифрах';

  @override
  String get comparisonFeatureOneScreen =>
      'Всё на одном экране — без ручного поиска по базам';

  @override
  String get socialTitle => 'Salamat создан\nдля таких людей,\nкак ты!';

  @override
  String get buildingTitle => 'Создаём твою\nпрограмму...';

  @override
  String get buildingStep1 => 'Анализ профиля';

  @override
  String get buildingStep2 => 'Расчёт метаболизма';

  @override
  String get buildingStep3 => 'Создание плана питания';

  @override
  String get planTitle => 'Твой персональный\nплан готов';

  @override
  String get planNow => 'Сейчас';

  @override
  String get planTarget => 'Цель';

  @override
  String planWeeksToTarget(int weeks) {
    return 'Длительность плана — около $weeks нед.';
  }

  @override
  String get planMaintain => 'Удерживать вес';

  @override
  String get planCaloriesLabel => 'Твоя норма калорий';

  @override
  String planCaloriesValue(int kcal) {
    return '$kcal ккал / день';
  }

  @override
  String planPaceLine(String pace) {
    return 'План рассчитан примерно на $pace кг в неделю';
  }

  @override
  String planPaceShort(String pace) {
    return '$pace кг/нед';
  }

  @override
  String get planStartTracking => 'Начать трекинг';

  @override
  String dashboardGreeting(String name) {
    return 'Привет, $name';
  }

  @override
  String get dashboardGreetingNoName => 'Привет!';

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
  String get dashboardSnapFirstMeal => 'Сними первое блюдо';

  @override
  String get mealsNothingYet => 'Пока пусто';

  @override
  String get dashboardWeightTitle => 'ВЕС';

  @override
  String dashboardWeightSinceStart(String delta) {
    return '$delta кг с начала';
  }

  @override
  String get snackIdeaTitle => 'Идея перекуса';

  @override
  String get dashboardWeightFirstLog => 'Запиши первое взвешивание';

  @override
  String get snackIdeaHearty =>
      'Ещё есть запас на полноценный перекус — йогурт с фруктами или сэндвич отлично впишутся.';

  @override
  String get snackIdeaLight =>
      'Есть запас на 120–240 ккал — горсть миндаля или яблоко впишутся отлично.';

  @override
  String get snackIdeaTiny =>
      'День почти закрыт — вода или чай мягко его завершат.';

  @override
  String mealsMacros(int p, int f, int c) {
    return 'Б$p Ж$f У$c';
  }

  @override
  String get mealsMacrosUnknown => '—';

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
  String get navMeals => 'Приёмы';

  @override
  String get navCameraAction => 'Сканировать блюдо';

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
  String get cameraPermissionBody =>
      'Разреши доступ к камере в настройках, чтобы распознавать блюда на фото.';

  @override
  String get cameraOpenSettings => 'Открыть настройки';

  @override
  String get cameraUnavailable => 'Камера недоступна на симуляторе';

  @override
  String get cameraUnavailableDevice => 'Камера недоступна на этом устройстве';

  @override
  String get cameraSimulate => 'Симулировать распознавание';

  @override
  String get barcodeModePhoto => 'Фото';

  @override
  String get barcodeModeCode => 'Штрихкод';

  @override
  String get barcodeHint => 'НАВЕДИ НА ШТРИХКОД';

  @override
  String get barcodeSearching => 'Ищем товар…';

  @override
  String get barcodeFreeNote => 'Сканы штрихкодов бесплатны';

  @override
  String get barcodeNotFoundTitle => 'Товара нет в базе';

  @override
  String get barcodeNotFoundBody =>
      'Open Food Facts пока не знает этот товар. Добавь его вручную — это займёт пару секунд.';

  @override
  String get barcodeNoNutritionTitle => 'Нет данных о составе';

  @override
  String get barcodeNoNutritionBody =>
      'Товар есть в базе, но без калорий — записать его по этикетке не получится.';

  @override
  String get barcodeOfflineTitle => 'Нет связи';

  @override
  String get barcodeOfflineBody =>
      'Не удалось получить данные о товаре. Проверь связь и попробуй ещё раз.';

  @override
  String get barcodeInvalidTitle => 'Не удалось прочитать код';

  @override
  String get barcodeInvalidBody =>
      'Держи телефон ровно, чтобы штрихкод целиком попал в рамку.';

  @override
  String get voiceModeVoice => 'Голос';

  @override
  String get voiceTapToSpeak => 'Нажми и скажи, что ты съел';

  @override
  String get voiceListening => 'Слушаю…';

  @override
  String get voiceHint => 'СКАЖИ, ЧТО ТЫ СЪЕЛ';

  @override
  String get voiceExample => '«Съел шаурму и колу»';

  @override
  String get voiceCheckText =>
      'Проверь текст перед отправкой — распознавание ошибается.';

  @override
  String get voiceParsing => 'Разбираем, что это было…';

  @override
  String get voiceSend => 'Найти эти блюда';

  @override
  String get voiceFreeNote => 'Голосовой ввод бесплатный';

  @override
  String get voiceItemsTitle => 'Добавить эти блюда?';

  @override
  String voiceAddAll(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Добавить $n блюда',
      many: 'Добавить $n блюд',
      few: 'Добавить $n блюда',
      one: 'Добавить 1 блюдо',
    );
    return '$_temp0';
  }

  @override
  String get voiceMicDeniedTitle => 'Микрофон выключен';

  @override
  String get voiceMicDeniedBody =>
      'Разреши доступ к микрофону в настройках, чтобы записывать еду голосом.';

  @override
  String get voiceUnavailableTitle => 'Голосовой ввод недоступен';

  @override
  String get voiceUnavailableBody =>
      'На этом устройстве нет распознавания речи.';

  @override
  String get voiceNotUnderstoodTitle => 'Не расслышал';

  @override
  String get voiceNotUnderstoodBody =>
      'Скажи блюда ещё раз или введи их вручную.';

  @override
  String get voiceOfflineTitle => 'Нет связи';

  @override
  String get voiceOfflineBody =>
      'Не удалось связаться с сервисом, чтобы разобрать блюда. Проверь связь и попробуй ещё раз.';

  @override
  String get cameraTitlePhoto => 'Сканировать блюдо';

  @override
  String get cameraTitleBarcode => 'Сканировать штрихкод';

  @override
  String get cameraTitleVoice => 'Скажи, что ты съел';

  @override
  String get coachTitle => 'Коуч';

  @override
  String get coachCardTitle => 'Спроси коуча';

  @override
  String get coachCardBody =>
      'Почему вес встал и что съесть на оставшиеся калории — с опорой на твой дневник.';

  @override
  String get coachCardBadge => 'PRO';

  @override
  String get coachIntro =>
      'Спроси про питание — что приготовить, сходится ли день, как добрать белок.';

  @override
  String get coachPlaceholder => 'Спроси про питание…';

  @override
  String get coachSendLabel => 'Отправить сообщение';

  @override
  String get coachThinking => 'Думаю…';

  @override
  String coachRemaining(int left, int total) {
    return 'Осталось $left из $total сообщений в этом месяце';
  }

  @override
  String get coachDisclaimer =>
      'Это не медицинская консультация. По вопросам здоровья — к врачу.';

  @override
  String get coachSuggest1 => 'Сходится ли сегодняшний день?';

  @override
  String get coachSuggest2 => 'Что приготовить на ужин?';

  @override
  String get coachSuggest3 => 'Как добрать белок?';

  @override
  String get coachNotSubscribedTitle => 'Коуч входит в Pro';

  @override
  String get coachNotSubscribedBody =>
      'Сканы без ограничений, прогноз веса и коуч — всё в одной подписке.';

  @override
  String get coachLimitTitle => 'Сообщения на этот месяц закончились';

  @override
  String get coachLimitBody =>
      'Лимит обновится в начале следующего месяца. Дневник и всё остальное работают как обычно.';

  @override
  String get coachOfflineTitle => 'Нет связи';

  @override
  String get coachOfflineBody =>
      'Не удалось связаться с коучем. Проверь связь и попробуй ещё раз.';

  @override
  String get coachUnavailableTitle => 'Коуч ещё не включён';

  @override
  String get coachUnavailableBody =>
      'В этой сборке функция пока недоступна. Всё остальное работает.';

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
  String get cameraAddButton => 'Добавить в дневник';

  @override
  String get cameraRetake => 'Переснять';

  @override
  String get cameraOutOfPhotos => 'Три бесплатных скана использованы';

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
  String get paywallSubtitle =>
      'Это весь бесплатный лимит.\nС Pro — сканы без ограничений + прогноз + анализ.';

  @override
  String get paywallLimitBadge => 'Лимит фото исчерпан';

  @override
  String get paywallFeature1Title => 'Фото-сканы без ограничений';

  @override
  String get paywallFeature1Sub => 'Фотай каждый приём пищи';

  @override
  String get paywallFeature2Title => 'Прогноз веса';

  @override
  String get paywallFeature2Sub => 'Динамика и темп, неделя за неделей';

  @override
  String get paywallFeature3Title => 'Полная история и тренды';

  @override
  String get paywallFeature3Sub => 'Весь дневник питания';

  @override
  String get paywallPopular => 'Выгоднее всего';

  @override
  String get paywallCancelAnytime => 'Отменить в любой момент';

  @override
  String get paywallRestore => 'Восстановить';

  @override
  String get paywallWelcomePro => 'Добро пожаловать в Pro';

  @override
  String get paywallPurchaseError => 'Оплата не прошла — попробуй ещё раз';

  @override
  String get paywallRestoreFound => 'Pro восстановлен';

  @override
  String get paywallRestoreNotFound => 'Покупки не найдены';

  @override
  String get paywallOfferingsError =>
      'Не удалось загрузить цены подписки.\nПроверь связь и повтори.';

  @override
  String get paywallHeroHeadlineLose =>
      'Полный доступ к твоему\nплану похудения';

  @override
  String get paywallHeroHeadlineGain =>
      'Полный доступ к твоему\nплану набора веса';

  @override
  String get paywallHeroHeadlineMaintain =>
      'Полный доступ к твоему\nплану баланса';

  @override
  String paywallGoalPaceLine(int weight, String pace) {
    return 'Цель — $weight кг. План рассчитан примерно на $pace кг в неделю.';
  }

  @override
  String paywallGoalHoldLine(int weight) {
    return 'Цель — удержаться на $weight кг.';
  }

  @override
  String get paywallGoalGenericLine => 'Под твою цель и твой день.';

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
  String get paywallFinePrint =>
      'Подписка продлевается автоматически в конце каждого периода. Отмени в любой момент в аккаунте магазина. Действуют Условия и Политика конфиденциальности.';

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
  String get profileDeleteDialogBody =>
      'Все твои данные — профиль, история питания и вес — будут удалены безвозвратно. Это действие нельзя отменить.';

  @override
  String get profileDeleteConfirm => 'Удалить';

  @override
  String get profileDeleteError =>
      'Не удалось удалить аккаунт. Попробуй позже.';

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
    return 'Введи вес от $min до $max кг';
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
  String get progressStreakStartHint =>
      'Отметь первый приём пищи — серия начнётся';

  @override
  String get progressHistoryEmpty =>
      'Пока нет данных. Добавляй блюда — история появится здесь.';

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

  @override
  String get splashTagline => 'ИИ-коуч по питанию';

  @override
  String get welcomeChipSnap => 'Снимок';

  @override
  String get welcomeChipConfirm => 'Проверка';

  @override
  String get welcomeChipDone => 'Готово';

  @override
  String get dashboardTodaysMeals => 'Приёмы за сегодня';

  @override
  String get dashboardScanAction => 'Снять';

  @override
  String get cameraConfirmTitle => 'Проверь тарелку';

  @override
  String cameraLogKcal(int kcal) {
    return 'Записать $kcal ккал';
  }

  @override
  String get cameraDetectedOne => 'Найден 1 продукт';

  @override
  String get cameraMealSlotHint => 'Добавить в';

  @override
  String cameraDetectedBoxLabel(String name, int percent) {
    return '$name $percent%';
  }

  @override
  String get progressRangeDay => 'День';

  @override
  String get progressRangeWeek => 'Неделя';

  @override
  String get progressRangeMonth => 'Месяц';

  @override
  String get progressRangeYear => 'Год';

  @override
  String get progressCalorieTrend => 'Динамика калорий';

  @override
  String progressDailyAvg(int kcal) {
    return 'в среднем $kcal';
  }

  @override
  String progressGoalLine(int kcal) {
    return 'цель $kcal';
  }

  @override
  String get progressProteinScore => 'Белковый счёт';

  @override
  String progressProteinScoreSub(int hit, int total) {
    return '$hit из $total дней в норме';
  }

  @override
  String get progressConsistencyLabel => 'Регулярность';

  @override
  String get progressConsistencySub => 'дней подряд';

  @override
  String get progressNoRangeData => 'За этот период пока ничего не записано';

  @override
  String get progressWeeklyMilestones => 'Цели по неделям';

  @override
  String progressMilestoneWeek(int n) {
    return 'Н$n';
  }

  @override
  String get cookTitle => 'Что приготовить';

  @override
  String get cookSubtitle => 'Из того, что есть, в рамках остатка на сегодня';

  @override
  String get cookPantryHeader => 'Твои продукты';

  @override
  String get cookAddHint => 'Добавить продукт';

  @override
  String get cookAddButton => 'Добавить';

  @override
  String get cookClearAll => 'Очистить';

  @override
  String cookRemoveItem(String item) {
    return 'Убрать $item';
  }

  @override
  String cookPantryFull(int max) {
    return 'До $max продуктов';
  }

  @override
  String get cookSuggestButton => 'Подобрать 3 блюда';

  @override
  String get cookRemainingLabel => 'Осталось сегодня';

  @override
  String get cookEmptyPantryTitle => 'Добавь, что есть';

  @override
  String get cookEmptyPantryBody =>
      'Перечисли продукты из холодильника, и Salamat подберёт три блюда под остаток дня.';

  @override
  String get cookNoBudgetTitle => 'Норма на сегодня исчерпана';

  @override
  String get cookNoBudgetBody =>
      'Под остаток сейчас ничего не подходит. Загляни завтра или измени цель.';

  @override
  String get cookFailedTitle => 'Не удалось подобрать блюдо';

  @override
  String get cookFailedBody =>
      'Сервис не ответил. Проверь связь и попробуй ещё раз.';

  @override
  String get cookLoading => 'Подбираем блюда…';

  @override
  String cookRangeKcal(int min, int max) {
    return '$min–$max ккал';
  }

  @override
  String cookRangeG(int min, int max) {
    return '$min–$max г';
  }

  @override
  String cookTimeMinutes(int n) {
    return '$n мин';
  }

  @override
  String get cookFits => 'Подходит';

  @override
  String get cookBorderline => 'Может не влезть';

  @override
  String get cookOver => 'Больше остатка';

  @override
  String get cookWhyRange =>
      'Оценка — диапазон шире, когда порция или способ готовки неясны';

  @override
  String get cookIngredientsHeader => 'Ингредиенты';

  @override
  String get cookStepsHeader => 'Как готовить';

  @override
  String get cookAddToDiary => 'Добавить в дневник';

  @override
  String cookAddedToDiary(String dish, int kcal) {
    return '$dish добавлено — $kcal ккал';
  }

  @override
  String get cookMidpointNote => 'Записано по середине диапазона';

  @override
  String get cookRetry => 'Ещё раз';

  @override
  String paywallTrialCta(String period) {
    return 'Начать $period бесплатно';
  }

  @override
  String paywallTrialThen(String price, String date) {
    return 'Затем $price, списание $date';
  }

  @override
  String get paywallSubscribeCta => 'Оформить подписку';

  @override
  String paywallPeriodDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дня',
      many: '$n дней',
      few: '$n дня',
      one: '1 день',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n недели',
      many: '$n недель',
      few: '$n недели',
      one: '1 неделя',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n месяца',
      many: '$n месяцев',
      few: '$n месяца',
      one: '1 месяц',
    );
    return '$_temp0';
  }

  @override
  String paywallPeriodYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n года',
      many: '$n лет',
      few: '$n года',
      one: '1 год',
    );
    return '$_temp0';
  }

  @override
  String paywallPerMonthShort(String price) {
    return '$price / мес';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionPlan => 'План и цели';

  @override
  String get settingsSectionAbout => 'О приложении';

  @override
  String get settingsAppearanceUnavailable =>
      'Тема задаётся сборкой приложения';

  @override
  String get detailTitle => 'Блюдо';

  @override
  String detailLoggedAt(String time) {
    return 'Записано в $time';
  }

  @override
  String detailServing(int grams) {
    return 'порция $grams г';
  }

  @override
  String get detailSourceBarcode => 'По штрихкоду';

  @override
  String get detailSourceVoice => 'Сказано голосом';

  @override
  String get detailSourcePhoto => 'Распознано по фото';

  @override
  String get detailSourceManual => 'Добавлено вручную';

  @override
  String get detailSourceSuggested => 'Из подборки';

  @override
  String get detailDuplicate => 'Дублировать';

  @override
  String get detailSave => 'Сохранить';

  @override
  String detailDeleted(String dish) {
    return '$dish удалено';
  }

  @override
  String detailDuplicated(String dish) {
    return '$dish записано ещё раз';
  }

  @override
  String get detailDeleteTitle => 'Удалить это блюдо?';

  @override
  String get detailDeleteBody => 'Оно исчезнет из сегодняшнего дневника.';

  @override
  String detailShareOfDay(int percent) {
    return '$percent% от нормы';
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
  String get waterUndo => 'Отменить';

  @override
  String waterOfGoal(String liters) {
    return 'из $liters л';
  }

  @override
  String get waterNotSynced => 'Сохранено только на этом устройстве';
}
