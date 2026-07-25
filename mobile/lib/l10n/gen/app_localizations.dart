import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('tr'),
  ];

  /// No description provided for @ortakKaydet.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get ortakKaydet;

  /// Kart sayaci — ICU plural TOHUM anahtari: ru/ar cogul kategorileri testle kilitlidir; ana ekran sayaclari bir sonraki turda ayni deseni kullanir.
  ///
  /// In tr, this message translates to:
  /// **'{n} Bekliyor'**
  String sayacBekliyor(int n);

  /// No description provided for @ortakKaydediliyor.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor...'**
  String get ortakKaydediliyor;

  /// No description provided for @ortakVazgec.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get ortakVazgec;

  /// No description provided for @ortakSil.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get ortakSil;

  /// No description provided for @ortakDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get ortakDuzenle;

  /// No description provided for @ortakEkle.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get ortakEkle;

  /// No description provided for @ortakTamam.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get ortakTamam;

  /// No description provided for @ortakKapat.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get ortakKapat;

  /// No description provided for @ortakTumunuGor.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Gör'**
  String get ortakTumunuGor;

  /// No description provided for @ortakYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi'**
  String get ortakYuklenemedi;

  /// No description provided for @ortakYenidenDene.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get ortakYenidenDene;

  /// No description provided for @ortakYakinda.
  ///
  /// In tr, this message translates to:
  /// **'Yakında'**
  String get ortakYakinda;

  /// No description provided for @ortakBolumYakinda.
  ///
  /// In tr, this message translates to:
  /// **'Bu bölüm yakında'**
  String get ortakBolumYakinda;

  /// No description provided for @ortakBeklenmeyenHata.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.'**
  String get ortakBeklenmeyenHata;

  /// Form dogrulama: eksik zorunlu alan
  ///
  /// In tr, this message translates to:
  /// **'{alan} zorunludur'**
  String ortakZorunluAlan(String alan);

  /// No description provided for @ayarlarBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get ayarlarBaslik;

  /// No description provided for @ayarlarTesis.
  ///
  /// In tr, this message translates to:
  /// **'Tesis'**
  String get ayarlarTesis;

  /// No description provided for @ayarlarYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim'**
  String get ayarlarYonetim;

  /// No description provided for @ayarlarGorunum.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get ayarlarGorunum;

  /// No description provided for @ayarlarTema.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get ayarlarTema;

  /// No description provided for @ayarlarTemaSistem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get ayarlarTemaSistem;

  /// No description provided for @ayarlarTemaAcik.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get ayarlarTemaAcik;

  /// No description provided for @ayarlarTemaKoyu.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get ayarlarTemaKoyu;

  /// No description provided for @ayarlarTemaAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Koyu tema tüm ekranlarda uygulanır; sistem seçilirse cihaz ayarını izler.'**
  String get ayarlarTemaAciklama;

  /// No description provided for @ayarlarTesisAdi.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adı'**
  String get ayarlarTesisAdi;

  /// No description provided for @ayarlarTesisAdiAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Ana ekranda ve raporlarda görünen ad.'**
  String get ayarlarTesisAdiAciklama;

  /// No description provided for @ayarlarTesisAdiGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adı güncellendi'**
  String get ayarlarTesisAdiGuncellendi;

  /// No description provided for @ayarlarKameralar.
  ///
  /// In tr, this message translates to:
  /// **'Kameralar'**
  String get ayarlarKameralar;

  /// No description provided for @ayarlarKameralarAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kamera ekle, düzenle, sil'**
  String get ayarlarKameralarAlt;

  /// Ayarlardaki dil satiri — TR disi dillerde de "Language" ile bulunabilir
  ///
  /// In tr, this message translates to:
  /// **'Dil / Language'**
  String get ayarlarDil;

  /// No description provided for @dilSecBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama dili'**
  String get dilSecBaslik;

  /// No description provided for @kameraBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kameralar'**
  String get kameraBaslik;

  /// No description provided for @kameraEkle.
  ///
  /// In tr, this message translates to:
  /// **'Kamera Ekle'**
  String get kameraEkle;

  /// No description provided for @kameraYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kamera'**
  String get kameraYeni;

  /// No description provided for @kameraDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kamerayı düzenle'**
  String get kameraDuzenleBaslik;

  /// No description provided for @kameraAd.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get kameraAd;

  /// No description provided for @kameraKonum.
  ///
  /// In tr, this message translates to:
  /// **'Konum (opsiyonel)'**
  String get kameraKonum;

  /// No description provided for @kameraTur.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get kameraTur;

  /// No description provided for @kameraUrl.
  ///
  /// In tr, this message translates to:
  /// **'Yayın URL\'si'**
  String get kameraUrl;

  /// No description provided for @kameraAktif.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get kameraAktif;

  /// No description provided for @kameraAktifAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken hiçbir listede görünmez'**
  String get kameraAktifAlt;

  /// No description provided for @kameraSakinGorebilir.
  ///
  /// In tr, this message translates to:
  /// **'Site sakinleri görebilsin'**
  String get kameraSakinGorebilir;

  /// No description provided for @kameraSakinGorebilirAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken kamerayı yalnızca yönetim ve güvenlik görür'**
  String get kameraSakinGorebilirAlt;

  /// No description provided for @kameraRtspFormUyari.
  ///
  /// In tr, this message translates to:
  /// **'RTSP yayınlar şu an uygulama içinde oynatılamaz. Kayıt saklanır; oynatma desteği ileride eklenecek.'**
  String get kameraRtspFormUyari;

  /// No description provided for @kameraUrlZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Yayın adresi zorunludur'**
  String get kameraUrlZorunlu;

  /// tur: HLS | MP4
  ///
  /// In tr, this message translates to:
  /// **'{tur} yayın adresi http:// veya https:// ile başlamalı'**
  String kameraUrlHataHttp(String tur);

  /// No description provided for @kameraUrlHataRtsp.
  ///
  /// In tr, this message translates to:
  /// **'RTSP yayın adresi rtsp:// ile başlamalı'**
  String get kameraUrlHataRtsp;

  /// No description provided for @kameraSilBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kamerayı sil'**
  String get kameraSilBaslik;

  /// No description provided for @kameraSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" silinsin mi?'**
  String kameraSilOnay(String ad);

  /// No description provided for @kameraBosYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Kamera tanımı yok. Sağ alttan ekleyebilirsiniz.'**
  String get kameraBosYonetim;

  /// No description provided for @kameraBosSakin.
  ///
  /// In tr, this message translates to:
  /// **'Görüntülemenize açık kamera yok.'**
  String get kameraBosSakin;

  /// No description provided for @kameraListeHata.
  ///
  /// In tr, this message translates to:
  /// **'Kameralar yüklenemedi.'**
  String get kameraListeHata;

  /// No description provided for @kameraCanli.
  ///
  /// In tr, this message translates to:
  /// **'Canlı'**
  String get kameraCanli;

  /// No description provided for @kameraOynatilamiyor.
  ///
  /// In tr, this message translates to:
  /// **'Oynatılamıyor'**
  String get kameraOynatilamiyor;

  /// No description provided for @kameraYayinAcilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Yayın açılamadı'**
  String get kameraYayinAcilamadi;

  /// No description provided for @kameraYayinAcilamadiAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kamera kapalı olabilir ya da ağ yayına ulaşamıyor.'**
  String get kameraYayinAcilamadiAlt;

  /// No description provided for @kameraTurEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Tür: {tur}'**
  String kameraTurEtiket(String tur);

  /// No description provided for @kameraRtspBilgi.
  ///
  /// In tr, this message translates to:
  /// **'RTSP yayınlar şu an uygulama içinde oynatılamıyor. Kayıt sistemde tutuluyor; oynatma desteği ileride eklenecek.'**
  String get kameraRtspBilgi;

  /// No description provided for @kameraSeritBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Canlı Kamera'**
  String get kameraSeritBaslik;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
