/// Prayer step entry for Namaz rehberi. actionKey/meaningKey are l10n keys.
/// surahNumber: 0 = Subhaneke, 1 = Fatiha, 2 = Tahiyyat. Load Arabic from prayerSurahsArabic.
class PrayerStepEntry {
  final int rakat;
  final String actionKey;
  final String meaningKey;
  final String? arabic;
  final String? transliteration;
  /// 0 = Subhaneke, 1 = Fatiha, 2 = Tahiyyat. Null = not a surah step.
  final int? surahNumber;
  /// If true, this step shows zammi surah; use zammiSurahNumber from config.
  final bool isZammiSurah;
  /// Hide this step in "basic" view mode.
  final bool hideInBasic;

  const PrayerStepEntry({
    required this.rakat,
    required this.actionKey,
    required this.meaningKey,
    this.arabic,
    this.transliteration,
    this.surahNumber,
    this.isZammiSurah = false,
    this.hideInBasic = false,
  });
}

// Default zammi surah numbers per prayer/rakat (matches RN DEFAULT_ZAMMI_CONFIG).
const Map<String, Map<int, int>> defaultZammiConfig = {
  'fajr': {1: 97, 2: 102},
  'dhuhr': {1: 103, 2: 105},
  'asr': {1: 106, 2: 107},
  'maghrib': {1: 108, 2: 109},
  'isha': {1: 110, 2: 111},
  'vitr': {1: 112, 2: 113, 3: 114},
};

/// Returns full list of steps for the given prayer. Filter by rakat in UI.
List<PrayerStepEntry> getStepsForPrayer(
  String prayer,
  int? Function(String p, int r) getZammiForRakat,
) {
  final steps = <PrayerStepEntry>[];

  void add(int r, String action, String meaning, {String? arabic, String? transliteration, int? surahNumber, bool isZammiSurah = false, bool hideInBasic = false}) {
    steps.add(PrayerStepEntry(
      rakat: r,
      actionKey: action,
      meaningKey: meaning,
      arabic: arabic,
      transliteration: transliteration,
      surahNumber: surahNumber,
      isZammiSurah: isZammiSurah,
      hideInBasic: hideInBasic,
    ));
  }

  // Common middle block: Fatiha (optional), Zammi (optional), then ruku → second secde.
  void middleBlock(int r, {bool withZammi = true, int? zammiNum}) {
    add(r, 'prayerActionFatiha', '', surahNumber: 1);
    if (withZammi && zammiNum != null) {
      add(r, 'prayerActionZammiSure', '', isZammiSurah: true);
    }
    add(r, 'prayerActionTekbirVeRuku', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(r, 'prayerActionRukuTesbihi', 'prayerMeaningRukuTesbihi', arabic: rukuTesbihAr, transliteration: rukuTesbihTrans);
    add(r, 'prayerActionRukudanKalkis', 'prayerMeaningRukudanKalkis', arabic: rukudanKalkisAr, transliteration: rukudanKalkisTrans);
    add(r, 'prayerActionRabbenaVeLekelHamd', 'prayerMeaningRabbenaVeLekelHamd', arabic: rabbenaHamdAr, transliteration: rabbenaHamdTrans);
    add(r, 'prayerActionTekbirVeSecde', 'prayerMeaningTakbirSecde', arabic: takbirAr, transliteration: takbirTrans);
    add(r, 'prayerActionSecdeTesbihi', 'prayerMeaningSecdeTesbihi', arabic: secdeTesbihAr, transliteration: secdeTesbihTrans);
    add(r, 'prayerActionTekbirVeCelseIstirahat', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(r, 'prayerActionCelseDuasi', 'prayerMeaningCelseDuasi', arabic: celseDuasiAr, transliteration: celseDuasiTrans, hideInBasic: true);
    add(r, 'prayerActionTekbirVeIkinciSecde', 'prayerMeaningTakbirIkinciSecde', arabic: takbirAr, transliteration: takbirTrans);
    add(r, 'prayerActionSecdeTesbihi2', 'prayerMeaningSecdeTesbihi', arabic: secdeTesbihAr, transliteration: secdeTesbihTrans);
  }

  final niyetKey = prayer == 'vitr' ? 'prayerMeaningNiyetVitr' : 'prayerMeaningNiyet${_capitalize(prayer)}';

  if (prayer == 'fajr') {
    // Rakat 1
    add(1, 'prayerActionNiyet', niyetKey);
    add(1, 'prayerActionTakbir', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(1, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    add(1, 'prayerActionSubhaneke', 'prayerMeaningSubhaneke', arabic: subhanekeAr, transliteration: subhanekeTrans, surahNumber: 0, hideInBasic: true);
    middleBlock(1, withZammi: true, zammiNum: getZammiForRakat('fajr', 1));
    // Rakat 2
    add(2, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(2, withZammi: true, zammiNum: getZammiForRakat('fajr', 2));
    add(2, 'prayerActionTekbirVeOturus', 'prayerMeaningTakbirOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionTahiyyat', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(2, 'prayerActionAllahummeSalli', 'prayerMeaningAllahummeSalli', arabic: salliAr, transliteration: salliTrans, hideInBasic: true);
    add(2, 'prayerActionAllahummeBarik', 'prayerMeaningAllahummeBarik', arabic: barikAr, transliteration: barikTrans, hideInBasic: true);
    add(2, 'prayerActionRabbenaAtina', 'prayerMeaningRabbenaAtina', arabic: rabbenaAtinaAr, transliteration: rabbenaAtinaTrans, hideInBasic: true);
    add(2, 'prayerActionRabbena\u011Ffirli', 'prayerMeaningRabbena\u011Ffirli', arabic: rabbenaGfirliAr, transliteration: rabbenaGfirliTrans, hideInBasic: true);
    add(2, 'prayerActionSelamSaga', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    add(2, 'prayerActionSelamSola', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    return steps;
  }

  if (prayer == 'maghrib') {
    add(1, 'prayerActionNiyet', niyetKey);
    add(1, 'prayerActionTakbir', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(1, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    add(1, 'prayerActionSubhaneke', 'prayerMeaningSubhaneke', arabic: subhanekeAr, transliteration: subhanekeTrans, surahNumber: 0, hideInBasic: true);
    middleBlock(1, withZammi: true, zammiNum: getZammiForRakat('maghrib', 1));
    add(2, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(2, withZammi: true, zammiNum: getZammiForRakat('maghrib', 2));
    add(2, 'prayerActionTekbirVeOturusIlkOturus', 'prayerMeaningTakbirOturusIlkOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionTahiyyatIlkOturus', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(2, 'prayerActionAyagaKalkis3Rakat', 'prayerMeaningTakbirAyagaKalkis3Rakat', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(3, withZammi: false);
    add(3, 'prayerActionTekbirVeOturus', 'prayerMeaningTakbirOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionTahiyyat', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(3, 'prayerActionAllahummeSalli', 'prayerMeaningAllahummeSalli', arabic: salliAr, transliteration: salliTrans, hideInBasic: true);
    add(3, 'prayerActionAllahummeBarik', 'prayerMeaningAllahummeBarik', arabic: barikAr, transliteration: barikTrans, hideInBasic: true);
    add(3, 'prayerActionRabbenaAtina', 'prayerMeaningRabbenaAtina', arabic: rabbenaAtinaAr, transliteration: rabbenaAtinaTrans, hideInBasic: true);
    add(3, 'prayerActionRabbena\u011Ffirli', 'prayerMeaningRabbena\u011Ffirli', arabic: rabbenaGfirliAr, transliteration: rabbenaGfirliTrans, hideInBasic: true);
    add(3, 'prayerActionSelamSaga', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    add(3, 'prayerActionSelamSola', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    return steps;
  }

  if (prayer == 'dhuhr' || prayer == 'asr' || prayer == 'isha') {
    add(1, 'prayerActionNiyet', niyetKey);
    add(1, 'prayerActionTakbir', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(1, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    add(1, 'prayerActionSubhaneke', 'prayerMeaningSubhaneke', arabic: subhanekeAr, transliteration: subhanekeTrans, surahNumber: 0, hideInBasic: true);
    middleBlock(1, withZammi: true, zammiNum: getZammiForRakat(prayer, 1));
    add(2, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(2, withZammi: true, zammiNum: getZammiForRakat(prayer, 2));
    add(2, 'prayerActionTekbirVeOturusIlkOturus', 'prayerMeaningTakbirOturusIlkOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionTahiyyatIlkOturus', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(2, 'prayerActionAyagaKalkis3Rakat', 'prayerMeaningTakbirAyagaKalkis3Rakat', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(3, withZammi: false);
    add(3, 'prayerActionTekbirVeOturusIlkOturus', 'prayerMeaningTakbirOturusIlkOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionTahiyyatIlkOturus', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(3, 'prayerActionAyagaKalkis3Rakat', 'prayerMeaningTakbirAyagaKalkis3Rakat', arabic: takbirAr, transliteration: takbirTrans);
    add(4, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(4, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(4, withZammi: false);
    add(4, 'prayerActionTekbirVeOturus', 'prayerMeaningTakbirOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(4, 'prayerActionTahiyyat', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(4, 'prayerActionAllahummeSalli', 'prayerMeaningAllahummeSalli', arabic: salliAr, transliteration: salliTrans, hideInBasic: true);
    add(4, 'prayerActionAllahummeBarik', 'prayerMeaningAllahummeBarik', arabic: barikAr, transliteration: barikTrans, hideInBasic: true);
    add(4, 'prayerActionRabbenaAtina', 'prayerMeaningRabbenaAtina', arabic: rabbenaAtinaAr, transliteration: rabbenaAtinaTrans, hideInBasic: true);
    add(4, 'prayerActionRabbena\u011Ffirli', 'prayerMeaningRabbena\u011Ffirli', arabic: rabbenaGfirliAr, transliteration: rabbenaGfirliTrans, hideInBasic: true);
    add(4, 'prayerActionSelamSaga', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    add(4, 'prayerActionSelamSola', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    return steps;
  }

  if (prayer == 'vitr') {
    add(1, 'prayerActionNiyet', niyetKey);
    add(1, 'prayerActionTakbir', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(1, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    add(1, 'prayerActionSubhaneke', 'prayerMeaningSubhaneke', arabic: subhanekeAr, transliteration: subhanekeTrans, surahNumber: 0, hideInBasic: true);
    middleBlock(1, withZammi: true, zammiNum: getZammiForRakat('vitr', 1));
    add(2, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    middleBlock(2, withZammi: true, zammiNum: getZammiForRakat('vitr', 2));
    add(2, 'prayerActionTekbirVeOturusIlkOturus', 'prayerMeaningTakbirOturusIlkOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(2, 'prayerActionTahiyyatIlkOturus', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(2, 'prayerActionAyagaKalkis3Rakat', 'prayerMeaningTakbirAyagaKalkis3Rakat', arabic: takbirAr, transliteration: takbirTrans);
    // 3. rekat: Fatiha, Zammi (Nas), Kunut, then ruku → selam
    add(3, 'prayerActionAyagaKalkis', 'prayerMeaningTakbirAyagaKalkis', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionElleriBaglama', 'prayerMeaningElleriBaglama');
    add(3, 'prayerActionFatiha', '', surahNumber: 1);
    add(3, 'prayerActionZammiSureNas', '', isZammiSurah: true); // zammi for rakat 3
    add(3, 'prayerActionTekbirKunutIcin', 'prayerMeaningTakbirKunutIcin', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionKunutDuasi', 'prayerMeaningKunutDuasi', arabic: kunut1Ar, transliteration: kunut1Trans);
    add(3, 'prayerActionKunutDuasiDevami', 'prayerMeaningKunutDuasiDevami', arabic: kunut2Ar, transliteration: kunut2Trans);
    add(3, 'prayerActionTekbirVeRuku', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionRukuTesbihi', 'prayerMeaningRukuTesbihi', arabic: rukuTesbihAr, transliteration: rukuTesbihTrans);
    add(3, 'prayerActionRukudanKalkis', 'prayerMeaningRukudanKalkis', arabic: rukudanKalkisAr, transliteration: rukudanKalkisTrans);
    add(3, 'prayerActionRabbenaVeLekelHamd', 'prayerMeaningRabbenaVeLekelHamd', arabic: rabbenaHamdAr, transliteration: rabbenaHamdTrans);
    add(3, 'prayerActionTekbirVeSecde', 'prayerMeaningTakbirSecde', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionSecdeTesbihi', 'prayerMeaningSecdeTesbihi', arabic: secdeTesbihAr, transliteration: secdeTesbihTrans);
    add(3, 'prayerActionTekbirVeCelseIstirahat', 'prayerMeaningTakbir', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionCelseDuasi', 'prayerMeaningCelseDuasi', arabic: celseDuasiAr, transliteration: celseDuasiTrans, hideInBasic: true);
    add(3, 'prayerActionTekbirVeIkinciSecde', 'prayerMeaningTakbirIkinciSecde', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionSecdeTesbihi2', 'prayerMeaningSecdeTesbihi', arabic: secdeTesbihAr, transliteration: secdeTesbihTrans);
    add(3, 'prayerActionTekbirVeOturus', 'prayerMeaningTakbirOturus', arabic: takbirAr, transliteration: takbirTrans);
    add(3, 'prayerActionTahiyyat', 'prayerMeaningTahiyyat', surahNumber: 2);
    add(3, 'prayerActionAllahummeSalli', 'prayerMeaningAllahummeSalli', arabic: salliAr, transliteration: salliTrans, hideInBasic: true);
    add(3, 'prayerActionAllahummeBarik', 'prayerMeaningAllahummeBarik', arabic: barikAr, transliteration: barikTrans, hideInBasic: true);
    add(3, 'prayerActionRabbenaAtina', 'prayerMeaningRabbenaAtina', arabic: rabbenaAtinaAr, transliteration: rabbenaAtinaTrans, hideInBasic: true);
    add(3, 'prayerActionRabbena\u011Ffirli', 'prayerMeaningRabbena\u011Ffirli', arabic: rabbenaGfirliAr, transliteration: rabbenaGfirliTrans, hideInBasic: true);
    add(3, 'prayerActionSelamSaga', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    add(3, 'prayerActionSelamSola', 'prayerMeaningSelam', arabic: selamAr, transliteration: selamTrans);
    return steps;
  }

  return steps;
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

// Arabic & transliteration constants (from RN). Transliteration in ASCII to avoid encoding issues.
const String takbirAr = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f \u0623\u064e\u0643\u0652\u0628\u064e\u0631\u064f';
const String takbirTrans = 'Allahu Akbar';
const String subhanekeAr = '\u0633\u064f\u0628\u0652\u062d\u064e\u0627\u0646\u064e\u0643\u064e \u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0648\u064e\u0628\u0650\u062d\u064e\u0645\u0652\u062f\u0650\u0643\u064e \u0648\u064e\u062a\u064e\u0628\u064e\u0627\u0631\u064e\u0643\u064e \u0627\u0633\u0652\u0645\u064f\u0643\u064e \u0648\u064e\u062a\u064e\u0639\u064e\u0627\u0644\u064e\u0649\u0670 \u062c\u064e\u062f\u0651\u064f\u0643\u064e \u0648\u064e\u0644\u064e\u0627 \u0625\u0650\u0644\u064e\u0671\u0647\u064e \u063a\u064e\u064a\u0652\u0631\u064f\u0643\u064e';
const String subhanekeTrans = 'Subhanakallahumma wa bihamdik, wa tabarakasmuk, wa taala jadduk, wa la ilaha gayruk';
const String rukuTesbihAr = '\u0633\u064f\u0628\u0652\u062d\u064e\u0627\u0646\u064e \u0631\u064e\u0628\u0651\u0650\u064a\u064e \u0627\u0644\u0652\u0639\u064e\u0638\u0652\u064a\u0645\u0650';
const String rukuTesbihTrans = 'Subhana rabbiyal-azim';
const String rukudanKalkisAr = '\u0633\u064e\u0645\u0650\u0639\u064e \u0627\u0644\u0644\u0651\u064e\u0647\u064f \u0644\u0650\u0645\u064e\u0646\u0652 \u062d\u064e\u0645\u0650\u062f\u064e\u0647\u064f';
const String rukudanKalkisTrans = 'Sami\'allahu liman hamidah';
const String rabbenaHamdAr = '\u0631\u064e\u0628\u0651\u064e\u0646\u064e\u0627 \u0648\u064e\u0644\u064e\u0643\u064e \u0627\u0644\u0652\u062d\u064e\u0645\u0652\u062f\u064f';
const String rabbenaHamdTrans = 'Rabbena wa lekel hamd';
const String secdeTesbihAr = '\u0633\u064f\u0628\u0652\u062d\u064e\u0627\u0646\u064e \u0631\u064e\u0628\u0651\u0650\u064a\u064e \u0627\u0644\u0652\u0623\u064e\u0639\u0652\u0644\u064e\u0649\u0670';
const String secdeTesbihTrans = 'Subhana rabbiyal-a\'la';
const String celseDuasiAr = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0627\u063a\u0652\u0641\u0650\u0631\u0652 \u0644\u0650\u064a \u0648\u064e\u0627\u0631\u0652\u062d\u064e\u0645\u0652\u0646\u0650\u064a \u0648\u064e\u0627\u062c\u0652\u0628\u064f\u0631\u0652\u0646\u0650\u064a \u0648\u064e\u0627\u062c\u0652\u0639\u064e\u0644\u0652\u0646\u0650\u064a \u0648\u064e\u0627\u0647\u0652\u062f\u0650\u0646\u0650\u064a \u0648\u064e\u0639\u064e\u0627\u0641\u0650\u0646\u0650\u064a';
const String celseDuasiTrans = 'Allahumma ighfir li, warhamni, wajburni, waj\'alni, wahdini, wa\'afini';
const String salliAr = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0635\u064e\u0644\u0651\u0650\u064a \u0639\u064e\u0644\u064e\u0649\u0670 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d \u0648\u064e\u0639\u064e\u0644\u064e\u0649\u0670 \u0622\u0644\u0650 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d \u0643\u064e\u0645\u064e\u0627 \u0635\u064e\u0644\u0651\u064e\u064a\u0652\u062a\u064e \u0639\u064e\u0644\u064e\u0649\u0670 \u0625\u0650\u0628\u0652\u0631\u064e\u0627\u0647\u0650\u064a\u064e\u0645\u064e \u0648\u064e\u0639\u064e\u0644\u064e\u0649\u0670 \u0622\u0644\u0650 \u0625\u0650\u0628\u0652\u0631\u064e\u0627\u0647\u0650\u064a\u064e\u0645\u064e \u0625\u0650\u0646\u0651\u064e\u0643\u064e \u062d\u064e\u0645\u0650\u064a\u062f\u064c \u0645\u064e\u062c\u0650\u064a\u062f\u064c';
const String salliTrans = 'Allahumma salli ala Muhammadin wa ala ali Muhammadin, kama sallayta ala Ibrahim wa ala ali Ibrahim, innaka hamidun majid';
const String barikAr = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0628\u064e\u0627\u0631\u0650\u0643\u0652 \u0639\u064e\u0644\u064e\u0649\u0670 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d \u0648\u064e\u0639\u064e\u0644\u064e\u0649\u0670 \u0622\u0644\u0650 \u0645\u064f\u062d\u064e\u0645\u0651\u064e\u062f\u064d \u0643\u064e\u0645\u064e\u0627 \u0628\u064e\u0627\u0631\u064e\u0643\u0652\u062a\u064e \u0639\u064e\u0644\u064e\u0649\u0670 \u0625\u0650\u0628\u0652\u0631\u064e\u0627\u0647\u0650\u064a\u064e\u0645\u064e \u0648\u064e\u0639\u064e\u0644\u064e\u0649\u0670 \u0622\u0644\u0650 \u0625\u0650\u0628\u0652\u0631\u064e\u0627\u0647\u0650\u064a\u064e\u0645\u064e \u0625\u0650\u0646\u0651\u064e\u0643\u064e \u062d\u064e\u0645\u0650\u064a\u062f\u064c \u0645\u064e\u062c\u0650\u064a\u062f\u064c';
const String barikTrans = 'Allahumma barik ala Muhammadin wa ala ali Muhammadin, kama barakta ala Ibrahim wa ala ali Ibrahim, innaka hamidun majid';
const String rabbenaAtinaAr = '\u0631\u064e\u0628\u0651\u064e\u0646\u064e\u0627 \u0622\u062a\u0650\u0646\u064e\u0627 \u0641\u0650\u064a \u0627\u0644\u0652\u062f\u0651\u064f\u0646\u0652\u064a\u064e\u0627 \u062d\u064e\u0633\u064e\u0646\u064e\u0629\u064b \u0648\u064e\u0641\u0650\u064a \u0627\u0644\u0652\u0622\u062e\u0650\u0631\u064e\u0629\u064e \u062d\u064e\u0633\u064e\u0646\u064e\u0629\u064b \u0648\u064e\u0642\u0650\u0646\u064e\u0627 \u0639\u064e\u0630\u064e\u0627\u0628\u064e \u0627\u0644\u0652\u0646\u0651\u064e\u0627\u0631\u0650';
const String rabbenaAtinaTrans = 'Rabbena atina fi\'d-dunya hasanatan wa fi\'l-akhirati hasanatan wa qina adhaban-nar';
const String rabbenaGfirliAr = '\u0631\u064e\u0628\u0651\u064e\u0646\u064e\u0627 \u0627\u063a\u0652\u0641\u0650\u0631\u0652 \u0644\u0650\u064a \u0648\u064e\u0644\u0650\u0648\u064e\u0627\u0644\u0650\u062f\u064e\u064a\u0651\u064e \u0648\u064e\u0644\u0650\u0644\u0651\u064e\u0645\u064f\u0624\u0652\u0645\u0650\u0646\u0650\u064a\u064e\u0646\u064e \u064a\u064e\u0648\u0652\u0645\u064e \u064a\u064e\u0642\u064f\u0648\u0652\u0645\u064f \u0627\u0644\u0652\u062d\u0650\u0633\u064e\u0627\u0628\u0650';
const String rabbenaGfirliTrans = 'Rabbena ighfir li wa li-walidayya wa li\'l-mu\'minina yawma yaqumul-hisab';
const String selamAr = '\u0627\u0644\u0633\u0651\u064e\u0644\u064e\u0627\u0645\u064f \u0639\u064e\u0644\u064e\u064a\u0652\u0643\u064f\u0645\u064f \u0648\u064e\u0631\u064e\u062d\u0652\u0645\u064e\u0629\u064f \u0627\u0644\u0644\u0651\u064e\u0647\u0650';
const String selamTrans = 'As-salamu alaykum wa rahmatullah';
const String kunut1Ar = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0625\u0650\u0646\u0651\u064e\u0627 \u0646\u064e\u0633\u0652\u062a\u064e\u0639\u0650\u064a\u064e\u0646\u064f\u0643\u064e \u0648\u064e\u0646\u064e\u0633\u0652\u062a\u064e\u063a\u0652\u0641\u0650\u0631\u064f\u0643\u064e \u0648\u064e\u0646\u064f\u0624\u0652\u0645\u0650\u0646\u064f \u0628\u0650\u0643\u064e \u0648\u064e\u0646\u064e\u062a\u064e\u0648\u064e\u0643\u0651\u064e\u0644\u064f \u0639\u064e\u0644\u064e\u064a\u0652\u0643\u064e \u0648\u064e\u0646\u064f\u062b\u0652\u0646\u0650\u064a \u0639\u064e\u0644\u064e\u064a\u0652\u0643\u064e \u0627\u0644\u0652\u062e\u064e\u064a\u0652\u0631\u064e \u0648\u064e\u0646\u064e\u0634\u0652\u0643\u064f\u0631\u064f\u0643\u064e \u0648\u064e\u0644\u064e\u0627 \u0646\u064e\u0643\u0652\u0641\u064f\u0631\u064f\u0643\u064e \u0648\u064e\u0646\u064e\u062e\u0652\u0644\u064e\u0639\u064f \u0648\u064e\u0646\u064e\u062a\u0652\u0631\u064f\u0643\u064f \u0645\u064e\u0646 \u064a\u064e\u0641\u0652\u062c\u064f\u0631\u064f\u0643\u064e';
const String kunut1Trans = 'Allahumma inna nasta\'inuka wa nastaghfiruka wa nu\'minu bika wa natawakkalu alayka wa nuthni alaykal-khayra wa nashkuruka wa la nakfuruka wa nakhla\'u wa natruku man yafjuruka';
const String kunut2Ar = '\u0627\u0644\u0644\u0651\u064e\u0647\u064f\u0645\u0651\u064e \u0625\u0650\u064a\u0651\u064e\u0627\u0643\u064e \u0646\u064e\u0639\u0652\u0628\u064f\u062f\u064f \u0648\u064e\u0644\u064e\u0643\u064e \u0646\u064f\u0635\u064e\u0644\u0651\u0650\u064a \u0648\u064e\u0646\u064e\u0633\u0652\u062c\u064f\u062f\u064f \u0648\u064e\u0625\u0650\u0644\u064e\u064a\u0652\u0643\u064e \u0646\u064e\u0633\u0652\u0639\u064e\u0649 \u0648\u064e\u0646\u064e\u062d\u0652\u0641\u0650\u062f\u064f \u0646\u064e\u0631\u0652\u062c\u064f\u0648 \u0631\u064e\u062d\u0652\u0645\u064e\u062a\u064e\u0643\u064e \u0648\u064e\u0646\u064e\u062e\u0652\u0634\u064e\u0649 \u0639\u064e\u0630\u064e\u0627\u0628\u064e\u0643\u064e \u0625\u0650\u0646\u0651\u064e \u0639\u064e\u0630\u064e\u0627\u0628\u064e\u0643\u064e \u0628\u0650\u0627\u0644\u0652\u0643\u064f\u0641\u0651\u064e\u0627\u0631\u0650 \u0645\u064f\u0644\u0652\u062d\u0650\u0642\u064c';
const String kunut2Trans = 'Allahumma iyyaka na\'budu wa laka nusalli wa nasjudu wa ilayka nas\'a wa nahfidu narju rahmataka wa nakhsha adhabaka inn adhabaka bil-kuffari mulhiq';
