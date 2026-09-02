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

  /// Duyuru kartinin sag alt cipi — SAYI TASIMAZ
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get cipYeni;

  /// Vardiya karti durum cipi
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get cipAktif;

  /// No description provided for @bolumVardiyaDurumu.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya Durumu'**
  String get bolumVardiyaDurumu;

  /// No description provided for @bolumSonHareketler.
  ///
  /// In tr, this message translates to:
  /// **'Son Hareketler'**
  String get bolumSonHareketler;

  /// No description provided for @bolumHizliOzet.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı Özet'**
  String get bolumHizliOzet;

  /// No description provided for @bolumDuyurular.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get bolumDuyurular;

  /// No description provided for @bolumSiteKurallari.
  ///
  /// In tr, this message translates to:
  /// **'Site Kuralları'**
  String get bolumSiteKurallari;

  /// No description provided for @bolumEtkinlikler.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get bolumEtkinlikler;

  /// No description provided for @bolumOdemeAidat.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme ve Aidat Durumu'**
  String get bolumOdemeAidat;

  /// No description provided for @bolumTumModuller.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Modüller'**
  String get bolumTumModuller;

  /// No description provided for @kartVardiyaDurum.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya Durum'**
  String get kartVardiyaDurum;

  /// No description provided for @kartKargo.
  ///
  /// In tr, this message translates to:
  /// **'Kargo'**
  String get kartKargo;

  /// No description provided for @kartZiyaretci.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi'**
  String get kartZiyaretci;

  /// No description provided for @kartAracPlaka.
  ///
  /// In tr, this message translates to:
  /// **'Araç Plaka'**
  String get kartAracPlaka;

  /// No description provided for @kartIhlaller.
  ///
  /// In tr, this message translates to:
  /// **'İhlaller'**
  String get kartIhlaller;

  /// No description provided for @kartGorevlerim.
  ///
  /// In tr, this message translates to:
  /// **'Görevlerim'**
  String get kartGorevlerim;

  /// No description provided for @kartDemirbas.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaş'**
  String get kartDemirbas;

  /// No description provided for @kartTurlarim.
  ///
  /// In tr, this message translates to:
  /// **'Turlarım'**
  String get kartTurlarim;

  /// No description provided for @kartTalepAriza.
  ///
  /// In tr, this message translates to:
  /// **'Talep / Arıza'**
  String get kartTalepAriza;

  /// No description provided for @kartZiyaretciler.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçiler'**
  String get kartZiyaretciler;

  /// No description provided for @kartKargolarim.
  ///
  /// In tr, this message translates to:
  /// **'Kargolarım'**
  String get kartKargolarim;

  /// No description provided for @kartAidatBilgileri.
  ///
  /// In tr, this message translates to:
  /// **'Aidat Bilgileri'**
  String get kartAidatBilgileri;

  /// No description provided for @kartGurultuSikayeti.
  ///
  /// In tr, this message translates to:
  /// **'Gürültü Şikayeti'**
  String get kartGurultuSikayeti;

  /// No description provided for @kartGeriBildirim.
  ///
  /// In tr, this message translates to:
  /// **'Geri Bildirim'**
  String get kartGeriBildirim;

  /// No description provided for @kartSikayetlerim.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetlerim'**
  String get kartSikayetlerim;

  /// No description provided for @kartSiteRaporlari.
  ///
  /// In tr, this message translates to:
  /// **'Site Raporları'**
  String get kartSiteRaporlari;

  /// No description provided for @kartGorevler.
  ///
  /// In tr, this message translates to:
  /// **'Görevler'**
  String get kartGorevler;

  /// No description provided for @kartAidatDurumu.
  ///
  /// In tr, this message translates to:
  /// **'Aidat Durumu'**
  String get kartAidatDurumu;

  /// No description provided for @kartOtoparkKullanimi.
  ///
  /// In tr, this message translates to:
  /// **'Otopark Kullanımı'**
  String get kartOtoparkKullanimi;

  /// No description provided for @kartSikayetler.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetler'**
  String get kartSikayetler;

  /// No description provided for @kartRaporlar.
  ///
  /// In tr, this message translates to:
  /// **'Raporlar'**
  String get kartRaporlar;

  /// No description provided for @kartYonetici.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get kartYonetici;

  /// No description provided for @kartGonderimKuyrugu.
  ///
  /// In tr, this message translates to:
  /// **'Gönderim Kuyruğu'**
  String get kartGonderimKuyrugu;

  /// No description provided for @etiketAylikOzet.
  ///
  /// In tr, this message translates to:
  /// **'Aylık Özet'**
  String get etiketAylikOzet;

  /// No description provided for @etiketDevriye.
  ///
  /// In tr, this message translates to:
  /// **'Devriye'**
  String get etiketDevriye;

  /// No description provided for @etiketKurallar.
  ///
  /// In tr, this message translates to:
  /// **'Kurallar'**
  String get etiketKurallar;

  /// No description provided for @etiketIletisim.
  ///
  /// In tr, this message translates to:
  /// **'İletişim'**
  String get etiketIletisim;

  /// No description provided for @sayacAktif.
  ///
  /// In tr, this message translates to:
  /// **'{n} Aktif'**
  String sayacAktif(num n);

  /// No description provided for @sayacIceride.
  ///
  /// In tr, this message translates to:
  /// **'{n} İçeride'**
  String sayacIceride(num n);

  /// No description provided for @sayacGiris.
  ///
  /// In tr, this message translates to:
  /// **'{n} Giriş'**
  String sayacGiris(num n);

  /// No description provided for @sayacYeni.
  ///
  /// In tr, this message translates to:
  /// **'{n} Yeni'**
  String sayacYeni(num n);

  /// No description provided for @sayacAcik.
  ///
  /// In tr, this message translates to:
  /// **'{n} Açık'**
  String sayacAcik(num n);

  /// No description provided for @sayacZimmetli.
  ///
  /// In tr, this message translates to:
  /// **'{n} Zimmetli'**
  String sayacZimmetli(num n);

  /// No description provided for @sayacKayit.
  ///
  /// In tr, this message translates to:
  /// **'{n} Kayıt'**
  String sayacKayit(num n);

  /// No description provided for @sayacYaklasan.
  ///
  /// In tr, this message translates to:
  /// **'{n} Yaklaşan'**
  String sayacYaklasan(num n);

  /// No description provided for @sayacDaire.
  ///
  /// In tr, this message translates to:
  /// **'{n} Daire'**
  String sayacDaire(num n);

  /// No description provided for @sayacArac.
  ///
  /// In tr, this message translates to:
  /// **'{n} araç'**
  String sayacArac(num n);

  /// No description provided for @sayacGorevli.
  ///
  /// In tr, this message translates to:
  /// **'{n} Görevli'**
  String sayacGorevli(num n);

  /// No description provided for @sayacBekleyen.
  ///
  /// In tr, this message translates to:
  /// **'{n} bekleyen'**
  String sayacBekleyen(num n);

  /// No description provided for @ozetToplamDaire.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Daire'**
  String get ozetToplamDaire;

  /// No description provided for @ozetToplamTahsilat.
  ///
  /// In tr, this message translates to:
  /// **'Toplam Tahsilat'**
  String get ozetToplamTahsilat;

  /// No description provided for @ozetTahsilatOrani.
  ///
  /// In tr, this message translates to:
  /// **'Aidat Tahsilat Oranı'**
  String get ozetTahsilatOrani;

  /// No description provided for @ozetOtoparkDoluluk.
  ///
  /// In tr, this message translates to:
  /// **'Otopark Doluluk'**
  String get ozetOtoparkDoluluk;

  /// No description provided for @ozetTumSite.
  ///
  /// In tr, this message translates to:
  /// **'Tüm Site'**
  String get ozetTumSite;

  /// No description provided for @ozetBuAy.
  ///
  /// In tr, this message translates to:
  /// **'Bu Ay'**
  String get ozetBuAy;

  /// No description provided for @ozetSuAn.
  ///
  /// In tr, this message translates to:
  /// **'Şu An'**
  String get ozetSuAn;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{dolu} / {kapasite}'**
  String otoparkDoluKapasite(Object dolu, Object kapasite);

  /// No description provided for @yuzdeDeger.
  ///
  /// In tr, this message translates to:
  /// **'%{oran}'**
  String yuzdeDeger(Object oran);

  /// No description provided for @anaSelam.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba, {ad}'**
  String anaSelam(Object ad);

  /// No description provided for @anaYoneticiPaneli.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici Paneli'**
  String get anaYoneticiPaneli;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'Daire {daireler}  •  {rol}'**
  String anaDaireAltBaslik(Object daireler, Object rol);

  /// No description provided for @anaDun.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get anaDun;

  /// No description provided for @anaOnline.
  ///
  /// In tr, this message translates to:
  /// **'Online'**
  String get anaOnline;

  /// No description provided for @anaVardiyaAktif.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get anaVardiyaAktif;

  /// No description provided for @anaVardiyaPlanlandi.
  ///
  /// In tr, this message translates to:
  /// **'Planlandı'**
  String get anaVardiyaPlanlandi;

  /// No description provided for @anaEtkinlikSuruyor.
  ///
  /// In tr, this message translates to:
  /// **'Sürüyor'**
  String get anaEtkinlikSuruyor;

  /// No description provided for @anaEtkinlikYaklasan.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get anaEtkinlikYaklasan;

  /// No description provided for @anaOdendi.
  ///
  /// In tr, this message translates to:
  /// **'Ödendi'**
  String get anaOdendi;

  /// No description provided for @anaOdenmedi.
  ///
  /// In tr, this message translates to:
  /// **'Ödenmedi'**
  String get anaOdenmedi;

  /// No description provided for @anaBorcVar.
  ///
  /// In tr, this message translates to:
  /// **'Borç Var'**
  String get anaBorcVar;

  /// No description provided for @anaBorcYok.
  ///
  /// In tr, this message translates to:
  /// **'Borç Yok'**
  String get anaBorcYok;

  /// No description provided for @anaBuAykiAidat.
  ///
  /// In tr, this message translates to:
  /// **'Bu Ayki Aidat'**
  String get anaBuAykiAidat;

  /// No description provided for @anaSonOdemeTarih.
  ///
  /// In tr, this message translates to:
  /// **'Son Ödeme: {tarih}'**
  String anaSonOdemeTarih(Object tarih);

  /// No description provided for @anaGelecekOdeme.
  ///
  /// In tr, this message translates to:
  /// **'Gelecek Ödeme'**
  String get anaGelecekOdeme;

  /// No description provided for @anaGecmisOdemeler.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş Ödemeler'**
  String get anaGecmisOdemeler;

  /// No description provided for @anaAidatKaydiYok.
  ///
  /// In tr, this message translates to:
  /// **'Aidat kaydı bulunamadı'**
  String get anaAidatKaydiYok;

  /// No description provided for @anaBildirimlerYakinda.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler yakında'**
  String get anaBildirimlerYakinda;

  /// No description provided for @anaBildirimlerRolYok.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler bu rolde kullanılamıyor'**
  String get anaBildirimlerRolYok;

  /// No description provided for @anaRaporlarYakinda.
  ///
  /// In tr, this message translates to:
  /// **'Raporlar yakında'**
  String get anaRaporlarYakinda;

  /// No description provided for @sekmeAnaSayfa.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get sekmeAnaSayfa;

  /// No description provided for @sekmeBildirimler.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get sekmeBildirimler;

  /// No description provided for @sekmeRaporlar.
  ///
  /// In tr, this message translates to:
  /// **'Raporlar'**
  String get sekmeRaporlar;

  /// (P154/7.2) Alt-bar 4. yuva — SAKIN. Ayni yuva yoneticide Raporlar, sahada Gorevlerim.
  ///
  /// In tr, this message translates to:
  /// **'Şeffaflık'**
  String get sekmeSeffaflik;

  /// (P154/7.2) Alt-bar 4. yuva — guvenlik + tesis gorevlisi.
  ///
  /// In tr, this message translates to:
  /// **'Görevlerim'**
  String get sekmeGorevlerim;

  /// No description provided for @sekmeAyarlar.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get sekmeAyarlar;

  /// (P154/7.1) Cekmece bolum basligi — taksonomi WEB ile AYNI (admin-web/lib/menu.ts). Iki urun ayni kavram agacini gosterir.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik'**
  String get kabukGrupGuvenlik;

  /// (P154/7.1) Cekmece bolum basligi — taksonomi WEB ile AYNI (admin-web/lib/menu.ts). Iki urun ayni kavram agacini gosterir.
  ///
  /// In tr, this message translates to:
  /// **'Tesis'**
  String get kabukGrupTesis;

  /// (P154/7.1) Cekmece bolum basligi — taksonomi WEB ile AYNI (admin-web/lib/menu.ts). Iki urun ayni kavram agacini gosterir.
  ///
  /// In tr, this message translates to:
  /// **'Finans'**
  String get kabukGrupFinans;

  /// (P154/7.1) Cekmece bolum basligi — taksonomi WEB ile AYNI (admin-web/lib/menu.ts). Iki urun ayni kavram agacini gosterir.
  ///
  /// In tr, this message translates to:
  /// **'İletişim'**
  String get kabukGrupIletisim;

  /// (P154/7.1) Cekmece bolum basligi — taksonomi WEB ile AYNI (admin-web/lib/menu.ts). Iki urun ayni kavram agacini gosterir.
  ///
  /// In tr, this message translates to:
  /// **'Tanımlar'**
  String get kabukGrupTanimlar;

  /// No description provided for @kabukProfil.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get kabukProfil;

  /// No description provided for @kabukCikisYap.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get kabukCikisYap;

  /// No description provided for @fabOlayBildir.
  ///
  /// In tr, this message translates to:
  /// **'Olay Bildir'**
  String get fabOlayBildir;

  /// No description provided for @fabTalepBildir.
  ///
  /// In tr, this message translates to:
  /// **'Talep / Bildir'**
  String get fabTalepBildir;

  /// No description provided for @fabTalepArizaBildir.
  ///
  /// In tr, this message translates to:
  /// **'Talep / Arıza Bildir'**
  String get fabTalepArizaBildir;

  /// No description provided for @fabRezervasyonYap.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyon Yap'**
  String get fabRezervasyonYap;

  /// No description provided for @fabDuyuruYayinla.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru Yayınla'**
  String get fabDuyuruYayinla;

  /// No description provided for @fabGorevOlustur.
  ///
  /// In tr, this message translates to:
  /// **'Görev Oluştur'**
  String get fabGorevOlustur;

  /// No description provided for @fabDestekTalebi.
  ///
  /// In tr, this message translates to:
  /// **'Destek Talebi'**
  String get fabDestekTalebi;

  /// No description provided for @modulDuyurular.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get modulDuyurular;

  /// No description provided for @modulTurlarim.
  ///
  /// In tr, this message translates to:
  /// **'Turlarım'**
  String get modulTurlarim;

  /// No description provided for @modulDevriyeTakibi.
  ///
  /// In tr, this message translates to:
  /// **'Devriye Takibi'**
  String get modulDevriyeTakibi;

  /// No description provided for @modulGorevlerim.
  ///
  /// In tr, this message translates to:
  /// **'Görevlerim'**
  String get modulGorevlerim;

  /// No description provided for @modulGorevYonetimi.
  ///
  /// In tr, this message translates to:
  /// **'Görev Yönetimi'**
  String get modulGorevYonetimi;

  /// No description provided for @modulDemirbas.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaş'**
  String get modulDemirbas;

  /// No description provided for @modulNfcOkutma.
  ///
  /// In tr, this message translates to:
  /// **'NFC Okutma'**
  String get modulNfcOkutma;

  /// No description provided for @modulGonderimKuyrugu.
  ///
  /// In tr, this message translates to:
  /// **'Gönderim Kuyruğu'**
  String get modulGonderimKuyrugu;

  /// No description provided for @modulAylikRaporlar.
  ///
  /// In tr, this message translates to:
  /// **'Aylık Raporlar'**
  String get modulAylikRaporlar;

  /// No description provided for @modulButce.
  ///
  /// In tr, this message translates to:
  /// **'Bütçe'**
  String get modulButce;

  /// No description provided for @modulFinansalOzet.
  ///
  /// In tr, this message translates to:
  /// **'Finansal Özet'**
  String get modulFinansalOzet;

  /// No description provided for @modulSeffaflik.
  ///
  /// In tr, this message translates to:
  /// **'Şeffaflık'**
  String get modulSeffaflik;

  /// No description provided for @modulSiteButcesi.
  ///
  /// In tr, this message translates to:
  /// **'Site Bütçesi'**
  String get modulSiteButcesi;

  /// No description provided for @modulAidatim.
  ///
  /// In tr, this message translates to:
  /// **'Aidatım'**
  String get modulAidatim;

  /// No description provided for @modulSikayetOneri.
  ///
  /// In tr, this message translates to:
  /// **'Şikayet / Öneri'**
  String get modulSikayetOneri;

  /// No description provided for @modulZiyaretciler.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçiler'**
  String get modulZiyaretciler;

  /// No description provided for @modulKargo.
  ///
  /// In tr, this message translates to:
  /// **'Kargo'**
  String get modulKargo;

  /// No description provided for @modulGoruntulemeIzni.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüleme İzni'**
  String get modulGoruntulemeIzni;

  /// No description provided for @modulRezervasyon.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyon'**
  String get modulRezervasyon;

  /// No description provided for @modulEtkinlikler.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get modulEtkinlikler;

  /// No description provided for @modulSiteKurallari.
  ///
  /// In tr, this message translates to:
  /// **'Site Kuralları'**
  String get modulSiteKurallari;

  /// No description provided for @modulDisHizmetler.
  ///
  /// In tr, this message translates to:
  /// **'Dış Hizmetler'**
  String get modulDisHizmetler;

  /// No description provided for @modulEntegrasyonlar.
  ///
  /// In tr, this message translates to:
  /// **'Entegrasyonlar'**
  String get modulEntegrasyonlar;

  /// No description provided for @modulPersonel.
  ///
  /// In tr, this message translates to:
  /// **'Saha Personeli'**
  String get modulPersonel;

  /// No description provided for @modulSakinler.
  ///
  /// In tr, this message translates to:
  /// **'Site Sakinleri'**
  String get modulSakinler;

  /// No description provided for @modulBinaYapisi.
  ///
  /// In tr, this message translates to:
  /// **'Bina Yapısı'**
  String get modulBinaYapisi;

  /// No description provided for @modulSikayetHaritasi.
  ///
  /// In tr, this message translates to:
  /// **'Şikayet Haritası'**
  String get modulSikayetHaritasi;

  /// No description provided for @modulSikayetlerim.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetlerim'**
  String get modulSikayetlerim;

  /// No description provided for @modulYoneticiIletisim.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici İletişim'**
  String get modulYoneticiIletisim;

  /// No description provided for @ortakKaydet.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get ortakKaydet;

  /// No description provided for @sayacBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'{n} Bekliyor'**
  String sayacBekliyor(num n);

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

  /// No description provided for @ortakZorunluAlan.
  ///
  /// In tr, this message translates to:
  /// **'{alan} zorunludur'**
  String ortakZorunluAlan(Object alan);

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

  /// No description provided for @ayarlarDil.
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

  /// No description provided for @kameraUrlHataHttp.
  ///
  /// In tr, this message translates to:
  /// **'{tur} yayın adresi http:// veya https:// ile başlamalı'**
  String kameraUrlHataHttp(Object tur);

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
  String kameraSilOnay(Object ad);

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

  /// No description provided for @kameraKareYok.
  ///
  /// In tr, this message translates to:
  /// **'Görüntü alınamıyor'**
  String get kameraKareYok;

  /// No description provided for @kameraBaglantiYok.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok'**
  String get kameraBaglantiYok;

  /// No description provided for @kameraUrlWebSayfasi.
  ///
  /// In tr, this message translates to:
  /// **'Bu bir web sayfası adresi. Uygulama yalnız doğrudan yayın adreslerini oynatır: .m3u8 (HLS) veya .mp4.'**
  String get kameraUrlWebSayfasi;

  /// No description provided for @kameraKaynakYardim.
  ///
  /// In tr, this message translates to:
  /// **'Yalnız doğrudan medya adresleri oynatılır: HLS (.m3u8) ve MP4. Web sayfaları (YouTube, Vimeo, belediye izleyici sayfaları) oynatılamaz. RTSP kaydedilir ama oynatmak için bir HLS geçidi gerekir.'**
  String get kameraKaynakYardim;

  /// No description provided for @kameraSnapshot.
  ///
  /// In tr, this message translates to:
  /// **'Anlık görüntü adresi'**
  String get kameraSnapshot;

  /// No description provided for @kameraSnapshotAlt.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı. Doldurulursa kamera listesinde canlı kare gösterilir (tek kare, JPEG).'**
  String get kameraSnapshotAlt;

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
  String kameraTurEtiket(Object tur);

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

  /// Ana ekran karsilama basligi (ad = kullanicinin adi)
  ///
  /// In tr, this message translates to:
  /// **'Merhaba, {ad}'**
  String anaKarsilama(String ad);

  /// No description provided for @gorevKategorilerTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get gorevKategorilerTooltip;

  /// No description provided for @gorevYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni görev'**
  String get gorevYeni;

  /// No description provided for @gorevOlusturuldu.
  ///
  /// In tr, this message translates to:
  /// **'Görev oluşturuldu ✓'**
  String get gorevOlusturuldu;

  /// No description provided for @gorevListesiYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Görev listesi için yetkiniz yok. Bu ekran temizlik ve güvenlik rollerine açıktır.'**
  String get gorevListesiYetkiYok;

  /// No description provided for @gorevBuFiltredeYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu filtreyle aktif görev yok.'**
  String get gorevBuFiltredeYok;

  /// No description provided for @gorevCipBanaAtanan.
  ///
  /// In tr, this message translates to:
  /// **'Bana atanan'**
  String get gorevCipBanaAtanan;

  /// No description provided for @gorevCipTumGorevler.
  ///
  /// In tr, this message translates to:
  /// **'Tüm görevler'**
  String get gorevCipTumGorevler;

  /// No description provided for @gorevCipTumu.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get gorevCipTumu;

  /// No description provided for @gorevKategoriDiger.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get gorevKategoriDiger;

  /// Gorevin sonraki planlanan zamani (tarih + saat)
  ///
  /// In tr, this message translates to:
  /// **'Planlanan: {zaman}'**
  String gorevPlanlanan(Object zaman);

  /// No description provided for @gorevSanaAtanmis.
  ///
  /// In tr, this message translates to:
  /// **'Sana atanmış'**
  String get gorevSanaAtanmis;

  /// No description provided for @gorevFotoZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Foto zorunlu'**
  String get gorevFotoZorunlu;

  /// No description provided for @gorevTamamlandiZatenKayitli.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı ✓ (zaten kayıtlıydı)'**
  String get gorevTamamlandiZatenKayitli;

  /// No description provided for @gorevTamamlandiBuOturumda.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı ✓ (bu oturumda)'**
  String get gorevTamamlandiBuOturumda;

  /// No description provided for @gorevIslemleriTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Görev işlemleri'**
  String get gorevIslemleriTooltip;

  /// No description provided for @gorevTakipGorunumu.
  ///
  /// In tr, this message translates to:
  /// **'Takip görünümü'**
  String get gorevTakipGorunumu;

  /// No description provided for @gorevTakipGorunumuAlt.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlama saha personeli tarafından yapılır (güvenlik / tesis görevlisi). Bu ekran izleme içindir.'**
  String get gorevTakipGorunumuAlt;

  /// No description provided for @gorevGonderiliyor.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get gorevGonderiliyor;

  /// No description provided for @gorevTamamla.
  ///
  /// In tr, this message translates to:
  /// **'Tamamla'**
  String get gorevTamamla;

  /// No description provided for @gorevGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Görev güncellendi ✓'**
  String get gorevGuncellendi;

  /// No description provided for @gorevSilinsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Görev silinsin mi?'**
  String get gorevSilinsinMi;

  /// No description provided for @gorevSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Görev silindi ✓'**
  String get gorevSilindi;

  /// No description provided for @gorevNfcAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Bu görev NFC doğrulamalı: tamamlamadan önce görev noktasındaki etiketi okutun.'**
  String get gorevNfcAciklama;

  /// No description provided for @gorevAdim1Etiket.
  ///
  /// In tr, this message translates to:
  /// **'1. Etiketi okutun'**
  String get gorevAdim1Etiket;

  /// Okunan NFC etiketinin UID'si
  ///
  /// In tr, this message translates to:
  /// **'Okundu: {uid}'**
  String gorevOkundu(Object uid);

  /// No description provided for @gorevEtiketBekleniyor.
  ///
  /// In tr, this message translates to:
  /// **'Etiket bekleniyor...'**
  String get gorevEtiketBekleniyor;

  /// No description provided for @gorevYenidenOkut.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden okut'**
  String get gorevYenidenOkut;

  /// No description provided for @gorevEtiketiOkut.
  ///
  /// In tr, this message translates to:
  /// **'Etiketi okut'**
  String get gorevEtiketiOkut;

  /// No description provided for @gorevAdim2Foto.
  ///
  /// In tr, this message translates to:
  /// **'2. Foto kanıtı'**
  String get gorevAdim2Foto;

  /// No description provided for @gorevAdim2FotoOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'2. Foto kanıtı (isteğe bağlı)'**
  String get gorevAdim2FotoOpsiyonel;

  /// No description provided for @gorevYukleniyorNokta.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get gorevYukleniyorNokta;

  /// No description provided for @gorevYuklendi.
  ///
  /// In tr, this message translates to:
  /// **'Yüklendi ✓'**
  String get gorevYuklendi;

  /// No description provided for @gorevKamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get gorevKamera;

  /// No description provided for @gorevYenidenCek.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden çek'**
  String get gorevYenidenCek;

  /// No description provided for @gorevGaleridenSec.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get gorevGaleridenSec;

  /// No description provided for @gorevTekrarYukle.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar yükle'**
  String get gorevTekrarYukle;

  /// No description provided for @gorevKaldir.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get gorevKaldir;

  /// No description provided for @gorevAdim3Not.
  ///
  /// In tr, this message translates to:
  /// **'3. Not (isteğe bağlı)'**
  String get gorevAdim3Not;

  /// No description provided for @gorevNotIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Örn. çöp konteynerleri boşaltıldı'**
  String get gorevNotIpucu;

  /// No description provided for @gorevZatenKayitliydi.
  ///
  /// In tr, this message translates to:
  /// **'Bu tamamlama zaten kayıtlıydı (tekrar gönderim — çift kayıt oluşmadı).'**
  String get gorevZatenKayitliydi;

  /// No description provided for @gorevTamamlandiKayit.
  ///
  /// In tr, this message translates to:
  /// **'Görev tamamlandı — kayıt oluşturuldu.'**
  String get gorevTamamlandiKayit;

  /// Tamamlama zamani (tarih + saat)
  ///
  /// In tr, this message translates to:
  /// **'Zaman: {zaman}'**
  String gorevZaman(Object zaman);

  /// No description provided for @gorevFotoKanitiVar.
  ///
  /// In tr, this message translates to:
  /// **'foto kanıtı var'**
  String get gorevFotoKanitiVar;

  /// No description provided for @gorevNfcDogrulandi.
  ///
  /// In tr, this message translates to:
  /// **'NFC doğrulandı'**
  String get gorevNfcDogrulandi;

  /// No description provided for @gorevYeniTamamlamaBaslat.
  ///
  /// In tr, this message translates to:
  /// **'Yeni tamamlama başlat'**
  String get gorevYeniTamamlamaBaslat;

  /// No description provided for @gorevDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Görev düzenle'**
  String get gorevDuzenleBaslik;

  /// No description provided for @gorevKategoriSilinmis.
  ///
  /// In tr, this message translates to:
  /// **'Kategori (silinmiş)'**
  String get gorevKategoriSilinmis;

  /// No description provided for @gorevAtananListedeDegil.
  ///
  /// In tr, this message translates to:
  /// **'Atanan kullanıcı (listede değil)'**
  String get gorevAtananListedeDegil;

  /// No description provided for @gorevTipleriYukleniyor.
  ///
  /// In tr, this message translates to:
  /// **'Görev tipleri yükleniyor...'**
  String get gorevTipleriYukleniyor;

  /// No description provided for @gorevTipi.
  ///
  /// In tr, this message translates to:
  /// **'Görev tipi'**
  String get gorevTipi;

  /// No description provided for @gorevTipiYokUyari.
  ///
  /// In tr, this message translates to:
  /// **'Henüz görev tipi tanımlamadınız. Üstteki \"Kategoriler\" ekranından kendi tiplerinizi ekleyebilirsiniz; şimdilik \"Diğer\" kullanılır.'**
  String get gorevTipiYokUyari;

  /// No description provided for @gorevAdi.
  ///
  /// In tr, this message translates to:
  /// **'Görev adı'**
  String get gorevAdi;

  /// No description provided for @gorevAdiZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Görev adı zorunludur'**
  String get gorevAdiZorunlu;

  /// No description provided for @gorevAciklamaOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (opsiyonel)'**
  String get gorevAciklamaOpsiyonel;

  /// No description provided for @gorevPersonelYukleniyor.
  ///
  /// In tr, this message translates to:
  /// **'Personel listesi yükleniyor...'**
  String get gorevPersonelYukleniyor;

  /// No description provided for @gorevAtananPersonel.
  ///
  /// In tr, this message translates to:
  /// **'Atanan personel'**
  String get gorevAtananPersonel;

  /// No description provided for @gorevAtanmamisHavuz.
  ///
  /// In tr, this message translates to:
  /// **'— atanmamış (havuz görevi) —'**
  String get gorevAtanmamisHavuz;

  /// No description provided for @gorevPersonelAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Personel listesi alınamadı: {hata}'**
  String gorevPersonelAlinamadi(Object hata);

  /// No description provided for @gorevKontrolNoktasiOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol noktası (NFC) — opsiyonel'**
  String get gorevKontrolNoktasiOpsiyonel;

  /// No description provided for @gorevKontrolNoktasiYardim.
  ///
  /// In tr, this message translates to:
  /// **'Bağlanırsa görev NFC okutularak tamamlanır'**
  String get gorevKontrolNoktasiYardim;

  /// No description provided for @gorevNfcYok.
  ///
  /// In tr, this message translates to:
  /// **'— NFC yok —'**
  String get gorevNfcYok;

  /// No description provided for @gorevPeriyotDakika.
  ///
  /// In tr, this message translates to:
  /// **'Periyot dakika (opsiyonel)'**
  String get gorevPeriyotDakika;

  /// No description provided for @gorevPeriyotYardim.
  ///
  /// In tr, this message translates to:
  /// **'Periyodik görevler için; boş = tek seferlik'**
  String get gorevPeriyotYardim;

  /// No description provided for @gorevPozitifSayi.
  ///
  /// In tr, this message translates to:
  /// **'Pozitif tam sayı girin'**
  String get gorevPozitifSayi;

  /// No description provided for @gorevFotoKanitiZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Foto kanıtı zorunlu'**
  String get gorevFotoKanitiZorunlu;

  /// No description provided for @gorevFotoKanitiZorunluAlt.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlama foto olmadan kabul edilmez'**
  String get gorevFotoKanitiZorunluAlt;

  /// No description provided for @gorevPasifAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Pasif görev listede görünmez'**
  String get gorevPasifAciklama;

  /// No description provided for @gorevKategorileriBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Görev kategorileri'**
  String get gorevKategorileriBaslik;

  /// No description provided for @gorevKategoriYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kategori'**
  String get gorevKategoriYeni;

  /// No description provided for @gorevKategoriAdi.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get gorevKategoriAdi;

  /// No description provided for @gorevKategoriAdiIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Havuz bakımı'**
  String get gorevKategoriAdiIpucu;

  /// ad = yoneticinin girdigi kategori adi
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" eklendi'**
  String gorevKategoriEklendi(Object ad);

  /// No description provided for @gorevKategoriEklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Eklenemedi: {hata}'**
  String gorevKategoriEklenemedi(Object hata);

  /// No description provided for @gorevKategoriSilinsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Kategori silinsin mi?'**
  String get gorevKategoriSilinsinMi;

  /// No description provided for @gorevKategoriSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" pasifleştirilir; mevcut görevlerin geçmişi korunur, yeni görevlerde seçilemez.'**
  String gorevKategoriSilOnay(Object ad);

  /// No description provided for @gorevKategoriSilindi.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" silindi'**
  String gorevKategoriSilindi(Object ad);

  /// No description provided for @gorevKategoriSilinemedi.
  ///
  /// In tr, this message translates to:
  /// **'Silinemedi: {hata}'**
  String gorevKategoriSilinemedi(Object hata);

  /// No description provided for @gorevKategoriListeAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Liste alınamadı: {hata}'**
  String gorevKategoriListeAlinamadi(Object hata);

  /// No description provided for @gorevKategoriYokBos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kategori yok. Görev oluştururken seçilebilmesi için \"Yeni kategori\" ile ekleyin.'**
  String get gorevKategoriYokBos;

  /// No description provided for @gorevOncelikDusuk.
  ///
  /// In tr, this message translates to:
  /// **'Düşük'**
  String get gorevOncelikDusuk;

  /// No description provided for @gorevOncelikOrta.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get gorevOncelikOrta;

  /// No description provided for @gorevOncelikYuksek.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek'**
  String get gorevOncelikYuksek;

  /// No description provided for @gorevOncelik.
  ///
  /// In tr, this message translates to:
  /// **'Öncelik'**
  String get gorevOncelik;

  /// No description provided for @gorevTaleptenGeldi.
  ///
  /// In tr, this message translates to:
  /// **'Talepten geldi'**
  String get gorevTaleptenGeldi;

  /// No description provided for @gorevBagliTalep.
  ///
  /// In tr, this message translates to:
  /// **'Bağlı talep'**
  String get gorevBagliTalep;

  /// Talebi acanin dairesi (orn. A-12)
  ///
  /// In tr, this message translates to:
  /// **'Daire {daire}'**
  String gorevDaireEtiket(Object daire);

  /// No description provided for @talepDurumAcik.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get talepDurumAcik;

  /// No description provided for @talepDurumIsEmri.
  ///
  /// In tr, this message translates to:
  /// **'İş Emri'**
  String get talepDurumIsEmri;

  /// No description provided for @talepDurumCozuldu.
  ///
  /// In tr, this message translates to:
  /// **'Çözüldü'**
  String get talepDurumCozuldu;

  /// No description provided for @talepDurumReddedildi.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get talepDurumReddedildi;

  /// No description provided for @gorevEtiketOkunamadi.
  ///
  /// In tr, this message translates to:
  /// **'Etiket okunamadı.'**
  String get gorevEtiketOkunamadi;

  /// No description provided for @gorevFotoOnlineGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklemek için internet bağlantısı gerekli (yükleme adresi kısa ömürlü). Bağlantı gelince \"Tekrar yükle\" ile deneyin.'**
  String get gorevFotoOnlineGerekli;

  /// No description provided for @gorevFotoAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf alınamadı: {hata}'**
  String gorevFotoAlinamadi(Object hata);

  /// No description provided for @gorevFotoOnlineGerekliKisa.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklemek için internet bağlantısı gerekli.'**
  String get gorevFotoOnlineGerekliKisa;

  /// No description provided for @gorevFotoZorunluUyari.
  ///
  /// In tr, this message translates to:
  /// **'Bu görev için FOTO KANITI ZORUNLU. Tamamlamadan önce fotoğraf çekip yükleyin.'**
  String get gorevFotoZorunluUyari;

  /// No description provided for @gorevFotoHenuzYuklenmedi.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin, \"Tekrar yükle\"yi deneyin veya fotoyu kaldırın.'**
  String get gorevFotoHenuzYuklenmedi;

  /// No description provided for @gorevTamamlamaOfflineUyari.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlama gönderilemedi — internet bağlantısı gerekli. Bağlantı gelince tekrar \"Tamamla\"ya basın; aynı kayıt çift oluşmaz (Idempotency-Key sabit). Fotoğraflı tamamlama offline desteklenmez (bilinen kısıt).'**
  String get gorevTamamlamaOfflineUyari;

  /// UserRole gorunen adlari — domain enum'u METIN TASIMAZ
  ///
  /// In tr, this message translates to:
  /// **'Platform Admini'**
  String get rolAdmin;

  /// No description provided for @rolYonetici.
  ///
  /// In tr, this message translates to:
  /// **'Site Yöneticisi'**
  String get rolYonetici;

  /// No description provided for @rolGuvenlik.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik'**
  String get rolGuvenlik;

  /// No description provided for @rolTesisGorevlisi.
  ///
  /// In tr, this message translates to:
  /// **'Tesis Görevlisi'**
  String get rolTesisGorevlisi;

  /// No description provided for @rolSakin.
  ///
  /// In tr, this message translates to:
  /// **'Site Sakini'**
  String get rolSakin;

  /// No description provided for @rolBilinmeyen.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen rol'**
  String get rolBilinmeyen;

  /// No description provided for @ortakOlustur.
  ///
  /// In tr, this message translates to:
  /// **'Oluştur'**
  String get ortakOlustur;

  /// No description provided for @ortakGuncelle.
  ///
  /// In tr, this message translates to:
  /// **'Güncelle'**
  String get ortakGuncelle;

  /// No description provided for @ortakYenile.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get ortakYenile;

  /// No description provided for @devriyeGonderimKuyruguTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Gönderim kuyruğu'**
  String get devriyeGonderimKuyruguTooltip;

  /// No description provided for @sekmeGecmis.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get sekmeGecmis;

  /// No description provided for @devriyeYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu ekrandaki veriler için yetkiniz yok. Tur takibi güvenlik (ve yönetici) rolüne açıktır.'**
  String get devriyeYetkiYok;

  /// saat = son yenileme saati (aktif dile gore bicimli)
  ///
  /// In tr, this message translates to:
  /// **'Son güncelleme: {saat} (otomatik yenileme: 60 sn)'**
  String devriyeSonGuncelleme(Object saat);

  /// No description provided for @devriyeTuru.
  ///
  /// In tr, this message translates to:
  /// **'Devriye turu'**
  String get devriyeTuru;

  /// No description provided for @devriyeBitisEtiket.
  ///
  /// In tr, this message translates to:
  /// **'bitiş {saat}'**
  String devriyeBitisEtiket(Object saat);

  /// Pencerenin baslangic/bitis saati
  ///
  /// In tr, this message translates to:
  /// **'Pencere: {baslangic} – {bitis}'**
  String devriyePencere(Object baslangic, Object bitis);

  /// okutulan/beklenen nokta sayisi
  ///
  /// In tr, this message translates to:
  /// **'{okutulan}/{beklenen} nokta'**
  String devriyeNoktaSayaci(Object okutulan, Object beklenen);

  /// No description provided for @devriyeTumNoktalarOkutuldu.
  ///
  /// In tr, this message translates to:
  /// **'Tüm noktalar okutuldu — tur tamamlanıyor. ✓'**
  String get devriyeTumNoktalarOkutuldu;

  /// Sunucudaki okutma sayisi (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Sunucuda {n} okutma kayıtlı (diğer cihazların okutmaları dahil olabilir).'**
  String devriyeSunucudaOkutma(num n);

  /// No description provided for @devriyeNoktaOkutNfc.
  ///
  /// In tr, this message translates to:
  /// **'Nokta okut (NFC)'**
  String get devriyeNoktaOkutNfc;

  /// No description provided for @devriyeBugununDigerTurlari.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün diğer turları'**
  String get devriyeBugununDigerTurlari;

  /// No description provided for @devriyeBugununTurlari.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün turları'**
  String get devriyeBugununTurlari;

  /// No description provided for @devriyeDurumTamamlandi.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get devriyeDurumTamamlandi;

  /// No description provided for @devriyeDurumKacirildi.
  ///
  /// In tr, this message translates to:
  /// **'Kaçırıldı'**
  String get devriyeDurumKacirildi;

  /// No description provided for @devriyeDurumSimdiAktif.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi aktif'**
  String get devriyeDurumSimdiAktif;

  /// No description provided for @devriyeDurumYaklasan.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get devriyeDurumYaklasan;

  /// No description provided for @devriyeDurumBitti.
  ///
  /// In tr, this message translates to:
  /// **'Bitti'**
  String get devriyeDurumBitti;

  /// No description provided for @devriyeDurumBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get devriyeDurumBekliyor;

  /// No description provided for @devriyeDurumBilinmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmiyor'**
  String get devriyeDurumBilinmiyor;

  /// No description provided for @devriyeDurumSuresiGecti.
  ///
  /// In tr, this message translates to:
  /// **'Süresi geçti'**
  String get devriyeDurumSuresiGecti;

  /// No description provided for @devriyeBugunTurYok.
  ///
  /// In tr, this message translates to:
  /// **'Bugün için devriye turu yok.'**
  String get devriyeBugunTurYok;

  /// No description provided for @devriyeNoktaListesiYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu planın nokta listesi alınamadı veya plana nokta atanmamış.'**
  String get devriyeNoktaListesiYok;

  /// No description provided for @devriyeKontrolNoktalari.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol noktaları'**
  String get devriyeKontrolNoktalari;

  /// No description provided for @devriyeNoktaDurumAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Nokta durumları sunucudandır; tüm görevlilerin okutmaları ✓ görünür. \"Gönderiliyor\" satırlar bu cihazın henüz gönderilmemiş okutmalarıdır.'**
  String get devriyeNoktaDurumAciklama;

  /// Nokta adi sunucudan gelmediyse kisa id ile yedek ad
  ///
  /// In tr, this message translates to:
  /// **'Nokta {kisaId}'**
  String devriyeNoktaAdiYedek(Object kisaId);

  /// No description provided for @devriyeOkutuldu.
  ///
  /// In tr, this message translates to:
  /// **'Okutuldu ✓'**
  String get devriyeOkutuldu;

  /// No description provided for @devriyeOkutulduZamanli.
  ///
  /// In tr, this message translates to:
  /// **'Okutuldu ✓ · {saat}'**
  String devriyeOkutulduZamanli(Object saat);

  /// No description provided for @devriyeOkutulduGonderiliyor.
  ///
  /// In tr, this message translates to:
  /// **'Okutuldu ✓ — gönderiliyor (kuyrukta)'**
  String get devriyeOkutulduGonderiliyor;

  /// No description provided for @devriyePencereSuresiDoldu.
  ///
  /// In tr, this message translates to:
  /// **'Pencere süresi doldu.'**
  String get devriyePencereSuresiDoldu;

  /// No description provided for @devriyeKalanSure.
  ///
  /// In tr, this message translates to:
  /// **'Kalan süre: {sure}'**
  String devriyeKalanSure(Object sure);

  /// Kalan sure birimi — kisaltmalar dile gore
  ///
  /// In tr, this message translates to:
  /// **'{saat} sa {dakika} dk'**
  String sureSaatDakika(Object saat, Object dakika);

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{dakika} dk {saniye} sn'**
  String sureDakikaSaniye(Object dakika, Object saniye);

  /// No description provided for @sureSaniye.
  ///
  /// In tr, this message translates to:
  /// **'{saniye} sn'**
  String sureSaniye(Object saniye);

  /// No description provided for @devriyeGecmisYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Tur geçmişi için yetkiniz yok. Bu liste güvenlik ve yönetici rollerine açıktır.'**
  String get devriyeGecmisYetkiYok;

  /// No description provided for @devriyeGecmisBos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tur penceresi kaydı yok.'**
  String get devriyeGecmisBos;

  /// No description provided for @devriyeOzetToplam.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get devriyeOzetToplam;

  /// No description provided for @devriyePlanlariBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Devriye Planları'**
  String get devriyePlanlariBaslik;

  /// No description provided for @devriyePlanEkle.
  ///
  /// In tr, this message translates to:
  /// **'Plan ekle'**
  String get devriyePlanEkle;

  /// No description provided for @devriyePlanlarListelenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Planlar listelenemedi.'**
  String get devriyePlanlarListelenemedi;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{baslangic}–{bitis} · her {dakika} dk'**
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika);

  /// No description provided for @devriyePasif.
  ///
  /// In tr, this message translates to:
  /// **'Pasif'**
  String get devriyePasif;

  /// No description provided for @devriyePlanSilinsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Plan silinsin mi?'**
  String get devriyePlanSilinsinMi;

  /// No description provided for @devriyePlanSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" devriye planı silinecek.'**
  String devriyePlanSilOnay(Object ad);

  /// No description provided for @devriyePlanSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Plan silindi ✓'**
  String get devriyePlanSilindi;

  /// No description provided for @devriyePlanDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Devriye planı düzenle'**
  String get devriyePlanDuzenleBaslik;

  /// No description provided for @devriyePlanYeniBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yeni devriye planı'**
  String get devriyePlanYeniBaslik;

  /// No description provided for @devriyePlanAdi.
  ///
  /// In tr, this message translates to:
  /// **'Plan adı'**
  String get devriyePlanAdi;

  /// No description provided for @devriyePlanAdiIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Gece devriyesi'**
  String get devriyePlanAdiIpucu;

  /// No description provided for @devriyeAdZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Ad zorunludur'**
  String get devriyeAdZorunlu;

  /// No description provided for @devriyeBaslangicSaat.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç {saat}'**
  String devriyeBaslangicSaat(Object saat);

  /// No description provided for @devriyeBitisSaat.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş {saat}'**
  String devriyeBitisSaat(Object saat);

  /// No description provided for @devriyeTurSikligi.
  ///
  /// In tr, this message translates to:
  /// **'Tur sıklığı (dakika)'**
  String get devriyeTurSikligi;

  /// No description provided for @devriyeTurSikligiYardim.
  ///
  /// In tr, this message translates to:
  /// **'örn. 60 = saatte bir tur'**
  String get devriyeTurSikligiYardim;

  /// No description provided for @devriyeTurSikligiPozitif.
  ///
  /// In tr, this message translates to:
  /// **'Tur sıklığı (dk) pozitif olmalı.'**
  String get devriyeTurSikligiPozitif;

  /// No description provided for @devriyeTumunuKaldir.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü kaldır'**
  String get devriyeTumunuKaldir;

  /// No description provided for @devriyeTumunuSec.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü seç'**
  String get devriyeTumunuSec;

  /// No description provided for @devriyeAktifNoktaYok.
  ///
  /// In tr, this message translates to:
  /// **'Aktif kontrol noktası yok. Önce \"Kontrol noktaları\"ndan ekleyin.'**
  String get devriyeAktifNoktaYok;

  /// NFC etiket UID'si (LTR izolasyonlu gosterilir)
  ///
  /// In tr, this message translates to:
  /// **'UID: {uid}'**
  String devriyeUidEtiket(Object uid);

  /// No description provided for @devriyeKaydedilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi. Tekrar deneyin.'**
  String get devriyeKaydedilemedi;

  /// No description provided for @devriyePlanYokBos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz devriye planı yok.\nSağ alttan ekleyin (saatler + noktalar).'**
  String get devriyePlanYokBos;

  /// No description provided for @devriyeTakibiBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Devriye takibi'**
  String get devriyeTakibiBaslik;

  /// No description provided for @sekmeBugun.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get sekmeBugun;

  /// No description provided for @sekmeTaramaGunlugu.
  ///
  /// In tr, this message translates to:
  /// **'Tarama günlüğü'**
  String get sekmeTaramaGunlugu;

  /// No description provided for @devriyeTakibiYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Devriye takibi için yetkiniz yok. Bu ekran yönetici ve güvenlik rollerine açıktır.'**
  String get devriyeTakibiYetkiYok;

  /// No description provided for @devriyeBugunPencereYok.
  ///
  /// In tr, this message translates to:
  /// **'Bugün için planlanmış devriye penceresi yok.'**
  String get devriyeBugunPencereYok;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{okutulan}/{beklenen} nokta okutuldu'**
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen);

  /// No description provided for @devriyeTaramaGunluguAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Tarama günlüğü alınamadı.'**
  String get devriyeTaramaGunluguAlinamadi;

  /// No description provided for @devriyeGunOkutmaYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için okutma yok.'**
  String get devriyeGunOkutmaYok;

  /// No description provided for @devriyeImzali.
  ///
  /// In tr, this message translates to:
  /// **'imzalı ✓'**
  String get devriyeImzali;

  /// Outbox'ta bekleyen okutma sayisi (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} okutma gönderim bekliyor'**
  String devriyeOkutmaBekliyor(num n);

  /// No description provided for @ortakIptal.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get ortakIptal;

  /// No description provided for @ortakNotOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'Not (opsiyonel)'**
  String get ortakNotOpsiyonel;

  /// No description provided for @binaDuzenlemeBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bina Düzenleme'**
  String get binaDuzenlemeBaslik;

  /// No description provided for @binaBlokTile.
  ///
  /// In tr, this message translates to:
  /// **'Blok'**
  String get binaBlokTile;

  /// No description provided for @binaBlokAtanmamis.
  ///
  /// In tr, this message translates to:
  /// **'Blok atanmamış'**
  String get binaBlokAtanmamis;

  /// ad = blok etiketi (A, B1 ...) — SUNUCU verisi, cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad}'**
  String binaBlokEtiket(Object ad);

  /// No description provided for @binaSaltGoruntulemeAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Bina yapısı (salt görüntüleme). Blok kutucuğuna dokunup kat ve daire yerleşimini görebilirsiniz.'**
  String get binaSaltGoruntulemeAciklama;

  /// No description provided for @binaDuzenlemeAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Blok ekleyin, kutucuğa dokunup içine kat ve daire yerleştirin. Her daire bir bloğa bağlanır. Şikayet Haritası bu yapıyı yansıtır.'**
  String get binaDuzenlemeAciklama;

  /// Blok kutucugundaki daire sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} daire'**
  String binaDaireSayisi(num n);

  /// No description provided for @binaKayitsiz.
  ///
  /// In tr, this message translates to:
  /// **'kayıtsız'**
  String get binaKayitsiz;

  /// No description provided for @binaBloksuzDairelerSalt.
  ///
  /// In tr, this message translates to:
  /// **'Bloğa atanmamış daireler (salt görüntüleme).'**
  String get binaBloksuzDairelerSalt;

  /// No description provided for @binaBlokYerlesimSalt.
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} — kat ve daire yerleşimi (salt görüntüleme).'**
  String binaBlokYerlesimSalt(Object ad);

  /// No description provided for @binaBloksuzUyari.
  ///
  /// In tr, this message translates to:
  /// **'Bu daireler bir bloğa atanmamış (eski kayıtlar). Görüntülenir, düzenlenip silinebilir; yeni daire için bir blok seçin/oluşturun.'**
  String get binaBloksuzUyari;

  /// No description provided for @binaBlokYerlesimYardim.
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} — kat ekleyip her katın \"+\" düğmesiyle daire ekleyin. Aynı kattakiler yan yana dizilir.'**
  String binaBlokYerlesimYardim(Object ad);

  /// No description provided for @binaKatEkle.
  ///
  /// In tr, this message translates to:
  /// **'Kat ekle'**
  String get binaKatEkle;

  /// No description provided for @binaTopluDaireEkle.
  ///
  /// In tr, this message translates to:
  /// **'Toplu daire ekle'**
  String get binaTopluDaireEkle;

  /// No description provided for @binaBloktaDaireYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu blokta henüz daire yok.'**
  String get binaBloktaDaireYok;

  /// No description provided for @binaKatYokBos.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kat yok. \"Kat ekle\" ile başlayın, sonra kattaki \"+\" ile daire ekleyin.'**
  String get binaKatYokBos;

  /// No description provided for @binaKatYok.
  ///
  /// In tr, this message translates to:
  /// **'Kat yok'**
  String get binaKatYok;

  /// No description provided for @binaKatEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Kat {kat}'**
  String binaKatEtiket(Object kat);

  /// No description provided for @binaBlokDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} — düzenle'**
  String binaBlokDuzenleBaslik(Object ad);

  /// No description provided for @binaBloguSil.
  ///
  /// In tr, this message translates to:
  /// **'Bloğu sil'**
  String get binaBloguSil;

  /// Blok silme secenegi alt metni (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} daire ile birlikte silinir (onay gerekir)'**
  String binaBloguSilAlt(num n);

  /// No description provided for @binaBlokSilinsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} silinsin mi?'**
  String binaBlokSilinsinMi(Object ad);

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} ve {n} daire silindi.'**
  String binaBlokVeDaireSilindi(Object ad, Object n);

  /// No description provided for @binaBlokSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Blok {ad} silindi.'**
  String binaBlokSilindi(Object ad);

  /// No description provided for @binaBlokSilinemedi.
  ///
  /// In tr, this message translates to:
  /// **'Blok silinemedi: {hata}'**
  String binaBlokSilinemedi(Object hata);

  /// No description provided for @binaBlokSilinemediGenel.
  ///
  /// In tr, this message translates to:
  /// **'Blok silinemedi. Lütfen tekrar deneyin.'**
  String get binaBlokSilinemediGenel;

  /// No description provided for @binaKaliciSilmeUyari.
  ///
  /// In tr, this message translates to:
  /// **'Bu blok ve içindeki {n} daire; aidat, ziyaretçi, kargo, rezervasyon ve şikayet kayıtlarıyla birlikte KALICI olarak silinecek. Bu işlem geri alınamaz.'**
  String binaKaliciSilmeUyari(Object n);

  /// No description provided for @binaOnayIcinBlokAdi.
  ///
  /// In tr, this message translates to:
  /// **'Onaylamak için blok adını yazın'**
  String get binaOnayIcinBlokAdi;

  /// No description provided for @binaSilNDaire.
  ///
  /// In tr, this message translates to:
  /// **'Sil ({n} daire)'**
  String binaSilNDaire(Object n);

  /// No description provided for @binaBlokEtiketiGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Blok etiketi gerekli (örn. A, B1).'**
  String get binaBlokEtiketiGerekli;

  /// No description provided for @binaBlokEtiketiZatenVar.
  ///
  /// In tr, this message translates to:
  /// **'Bu blok etiketi zaten kayıtlı.'**
  String get binaBlokEtiketiZatenVar;

  /// No description provided for @binaBlokDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Blok düzenle'**
  String get binaBlokDuzenle;

  /// No description provided for @binaYeniBlok.
  ///
  /// In tr, this message translates to:
  /// **'Yeni blok'**
  String get binaYeniBlok;

  /// No description provided for @binaBlokEtiketi.
  ///
  /// In tr, this message translates to:
  /// **'Blok etiketi'**
  String get binaBlokEtiketi;

  /// No description provided for @binaBlokEtiketiYardim.
  ///
  /// In tr, this message translates to:
  /// **'Kısa alfanumerik (örn. A, B1) — tire yok'**
  String get binaBlokEtiketiYardim;

  /// No description provided for @binaDaireNoGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Daire no gerekli (örn. A-12, 12).'**
  String get binaDaireNoGerekli;

  /// No description provided for @binaKatSiraTamSayi.
  ///
  /// In tr, this message translates to:
  /// **'Kat ve sıra tam sayı olmalı.'**
  String get binaKatSiraTamSayi;

  /// No description provided for @binaDaireNoZatenVar.
  ///
  /// In tr, this message translates to:
  /// **'Bu daire no zaten kayıtlı.'**
  String get binaDaireNoZatenVar;

  /// No description provided for @binaDaireDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Daire {no} — düzenle'**
  String binaDaireDuzenleBaslik(Object no);

  /// No description provided for @binaYeniDaire.
  ///
  /// In tr, this message translates to:
  /// **'Yeni daire · {blok}'**
  String binaYeniDaire(Object blok);

  /// No description provided for @binaDaireNo.
  ///
  /// In tr, this message translates to:
  /// **'Daire no'**
  String get binaDaireNo;

  /// No description provided for @binaDaireNoYardim.
  ///
  /// In tr, this message translates to:
  /// **'Alfanumerik + tire (örn. A-12, B3, 12)'**
  String get binaDaireNoYardim;

  /// No description provided for @binaSira.
  ///
  /// In tr, this message translates to:
  /// **'Sıra'**
  String get binaSira;

  /// No description provided for @binaSiraYardim.
  ///
  /// In tr, this message translates to:
  /// **'Kattaki konum'**
  String get binaSiraYardim;

  /// No description provided for @binaEnFazla500.
  ///
  /// In tr, this message translates to:
  /// **'En fazla 500 daire (şu an {n}).'**
  String binaEnFazla500(Object n);

  /// Toplu ekleme onizlemesi: ilk … son (toplam, kat x adet)
  ///
  /// In tr, this message translates to:
  /// **'{bas} … {bitis}  ({toplam} daire, {kat} kat × {adet})'**
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  );

  /// No description provided for @binaTopluAlanlarGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Kat sayısı, kat başına daire ve başlangıç no gerekli.'**
  String get binaTopluAlanlarGerekli;

  /// No description provided for @binaTekSeferde500.
  ///
  /// In tr, this message translates to:
  /// **'Tek seferde en fazla 500 daire.'**
  String get binaTekSeferde500;

  /// No description provided for @binaAtlananEk.
  ///
  /// In tr, this message translates to:
  /// **' ({n} zaten vardı, atlandı)'**
  String binaAtlananEk(Object n);

  /// ek = ' (n zaten vardi, atlandi)' eki ya da bos
  ///
  /// In tr, this message translates to:
  /// **'{n} daire eklendi ✓{ek}'**
  String binaDaireEklendi(Object n, Object ek);

  /// No description provided for @binaEklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Eklenemedi. Tekrar deneyin.'**
  String get binaEklenemedi;

  /// No description provided for @binaTopluBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Toplu daire ekle — Blok {blok}'**
  String binaTopluBaslik(Object blok);

  /// No description provided for @binaTopluBaslikBloksuz.
  ///
  /// In tr, this message translates to:
  /// **'Toplu daire ekle — Bloksuz'**
  String get binaTopluBaslikBloksuz;

  /// No description provided for @binaTopluAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Numaralar başlangıçtan itibaren ardışık, kat kat dolar. Var olanlar atlanır.'**
  String get binaTopluAciklama;

  /// No description provided for @binaKatSayisi.
  ///
  /// In tr, this message translates to:
  /// **'Kat sayısı'**
  String get binaKatSayisi;

  /// No description provided for @binaKatBasinaDaire.
  ///
  /// In tr, this message translates to:
  /// **'Kat başına daire'**
  String get binaKatBasinaDaire;

  /// No description provided for @binaBaslangicNo.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç no'**
  String get binaBaslangicNo;

  /// No description provided for @binaBaslangicNoIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. 101'**
  String get binaBaslangicNoIpucu;

  /// No description provided for @binaDaireleriOlustur.
  ///
  /// In tr, this message translates to:
  /// **'Daireleri oluştur'**
  String get binaDaireleriOlustur;

  /// No description provided for @binaSilinemedi.
  ///
  /// In tr, this message translates to:
  /// **'Silinemedi. Lütfen tekrar deneyin.'**
  String get binaSilinemedi;

  /// No description provided for @binaKaydedilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi. Lütfen tekrar deneyin.'**
  String get binaKaydedilemedi;

  /// No description provided for @semaDaireYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz daire yok.'**
  String get semaDaireYok;

  /// No description provided for @semaYogunluk.
  ///
  /// In tr, this message translates to:
  /// **'Yoğunluk:'**
  String get semaYogunluk;

  /// No description provided for @semaYerlesimAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Bina yerleşimi. Şikayet yoğunluğu yalnızca yönetime gösterilir.'**
  String get semaYerlesimAciklama;

  /// No description provided for @semaYerlesimGirilmemis.
  ///
  /// In tr, this message translates to:
  /// **'Haritada yerleşimi girilmemiş'**
  String get semaYerlesimGirilmemis;

  /// No description provided for @semaDaireEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Daire {no}'**
  String semaDaireEtiket(Object no);

  /// Dairenin acik sikayet sayisi (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} açık şikayet'**
  String semaAcikSikayet(num n);

  /// No description provided for @semaBuDaireSikayetlerim.
  ///
  /// In tr, this message translates to:
  /// **'Bu daire için şikayetleriniz'**
  String get semaBuDaireSikayetlerim;

  /// No description provided for @semaYogunlukYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Şikayet yoğunluğu yalnızca yönetime gösterilir.'**
  String get semaYogunlukYonetim;

  /// No description provided for @semaBuDaireyiSikayetEt.
  ///
  /// In tr, this message translates to:
  /// **'Bu daireyi şikayet et'**
  String get semaBuDaireyiSikayetEt;

  /// No description provided for @semaSikayetIletildi.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetiniz iletildi.'**
  String get semaSikayetIletildi;

  /// No description provided for @semaSikayetlerYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetler yüklenemedi.'**
  String get semaSikayetlerYuklenemedi;

  /// No description provided for @semaAcikSikayetYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu daire için açık şikayet yok.'**
  String get semaAcikSikayetYok;

  /// No description provided for @semaSikayetlerimYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetleriniz yüklenemedi.'**
  String get semaSikayetlerimYuklenemedi;

  /// No description provided for @semaSikayetimYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu daireye şikayetiniz yok.'**
  String get semaSikayetimYok;

  /// No description provided for @semaYonetimeIletildi.
  ///
  /// In tr, this message translates to:
  /// **'Yönetime iletildi'**
  String get semaYonetimeIletildi;

  /// No description provided for @semaKapatildi.
  ///
  /// In tr, this message translates to:
  /// **'Kapatıldı'**
  String get semaKapatildi;

  /// No description provided for @semaHaftalikSinir.
  ///
  /// In tr, this message translates to:
  /// **'Bu daire için bu konuda haftada en fazla 1 şikayet açabilirsiniz.'**
  String get semaHaftalikSinir;

  /// No description provided for @semaKendiBlok.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca kendi bloğunuzdaki daireleri şikayet edebilirsiniz.'**
  String get semaKendiBlok;

  /// No description provided for @semaGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi. Lütfen tekrar deneyin.'**
  String get semaGonderilemedi;

  /// No description provided for @semaSikayetEtBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Daire {no} — şikayet et'**
  String semaSikayetEtBaslik(Object no);

  /// No description provided for @semaSikayetAnonimNot.
  ///
  /// In tr, this message translates to:
  /// **'Şikayetiniz yönetime iletilir; komşularınıza gösterilmez.'**
  String get semaSikayetAnonimNot;

  /// No description provided for @semaSikayetiGonder.
  ///
  /// In tr, this message translates to:
  /// **'Şikayeti gönder'**
  String get semaSikayetiGonder;

  /// UnitComplaintKategori gorunen adlari — enum METIN TASIMAZ
  ///
  /// In tr, this message translates to:
  /// **'Gürültü'**
  String get kategoriGurultu;

  /// No description provided for @kategoriKapiOnuAyakkabi.
  ///
  /// In tr, this message translates to:
  /// **'Kapı önü / ayakkabı'**
  String get kategoriKapiOnuAyakkabi;

  /// No description provided for @kategoriZararVerme.
  ///
  /// In tr, this message translates to:
  /// **'Zarar verme'**
  String get kategoriZararVerme;

  /// No description provided for @talepSekmeAcik.
  ///
  /// In tr, this message translates to:
  /// **'Açık ({n})'**
  String talepSekmeAcik(Object n);

  /// No description provided for @talepSekmeIsEmri.
  ///
  /// In tr, this message translates to:
  /// **'İş Emri ({n})'**
  String talepSekmeIsEmri(Object n);

  /// No description provided for @talepSekmeCozulen.
  ///
  /// In tr, this message translates to:
  /// **'Çözülen ({n})'**
  String talepSekmeCozulen(Object n);

  /// No description provided for @talepSekmeReddedilen.
  ///
  /// In tr, this message translates to:
  /// **'Reddedilen ({n})'**
  String talepSekmeReddedilen(Object n);

  /// No description provided for @talepYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni talep'**
  String get talepYeni;

  /// No description provided for @talepAcikYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Açık talebiniz yok. \"Yeni talep\" ile talep/arızanızı iletebilirsiniz.'**
  String get talepAcikYokSakin;

  /// No description provided for @talepAcikYok.
  ///
  /// In tr, this message translates to:
  /// **'Açık talep yok.'**
  String get talepAcikYok;

  /// No description provided for @talepIsEmriYok.
  ///
  /// In tr, this message translates to:
  /// **'İş emrine dönüşen talep yok.'**
  String get talepIsEmriYok;

  /// No description provided for @talepCozulenYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz çözülen talep yok.'**
  String get talepCozulenYok;

  /// No description provided for @talepReddedilenYok.
  ///
  /// In tr, this message translates to:
  /// **'Reddedilen talep yok.'**
  String get talepReddedilenYok;

  /// No description provided for @talepIletildi.
  ///
  /// In tr, this message translates to:
  /// **'Talebiniz iletildi ✓'**
  String get talepIletildi;

  /// No description provided for @talepDurumGecmisi.
  ///
  /// In tr, this message translates to:
  /// **'Durum geçmişi'**
  String get talepDurumGecmisi;

  /// No description provided for @talepGorselYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Görsel yüklenemedi'**
  String get talepGorselYuklenemedi;

  /// No description provided for @talepIsEmriAtandi.
  ///
  /// In tr, this message translates to:
  /// **'Atandı'**
  String get talepIsEmriAtandi;

  /// No description provided for @talepIsEmriTamamlandi.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get talepIsEmriTamamlandi;

  /// No description provided for @talepIsEmriDurumBilinmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Durum bilinmiyor'**
  String get talepIsEmriDurumBilinmiyor;

  /// No description provided for @talepIsEmri.
  ///
  /// In tr, this message translates to:
  /// **'İş emri'**
  String get talepIsEmri;

  /// No description provided for @talepYeniBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yeni talep / arıza'**
  String get talepYeniBaslik;

  /// No description provided for @talepBaslikAlan.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get talepBaslikAlan;

  /// No description provided for @talepBaslikZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Başlık zorunludur'**
  String get talepBaslikZorunlu;

  /// No description provided for @talepAciklamaAlan.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get talepAciklamaAlan;

  /// No description provided for @talepAciklamaZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama zorunludur'**
  String get talepAciklamaZorunlu;

  /// No description provided for @talepGonder.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get talepGonder;

  /// No description provided for @talepKategoriOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'Kategori (opsiyonel)'**
  String get talepKategoriOpsiyonel;

  /// No description provided for @talepKategoriYok.
  ///
  /// In tr, this message translates to:
  /// **'Tanımlı kategori yok; talep \"Diğer\" olarak açılır.'**
  String get talepKategoriYok;

  /// No description provided for @talepGorseller.
  ///
  /// In tr, this message translates to:
  /// **'Görseller (opsiyonel, en fazla 3)'**
  String get talepGorseller;

  /// No description provided for @talepYoneticiIslemleri.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici işlemleri'**
  String get talepYoneticiIslemleri;

  /// No description provided for @talepIsEmrineDonusturuldu.
  ///
  /// In tr, this message translates to:
  /// **'Talep iş emrine dönüştürüldü ✓'**
  String get talepIsEmrineDonusturuldu;

  /// No description provided for @talepIsEmrineDonusturBuyuk.
  ///
  /// In tr, this message translates to:
  /// **'İş Emrine Dönüştür'**
  String get talepIsEmrineDonusturBuyuk;

  /// No description provided for @talepCozuldu.
  ///
  /// In tr, this message translates to:
  /// **'Talep çözüldü ✓'**
  String get talepCozuldu;

  /// No description provided for @talepCoz.
  ///
  /// In tr, this message translates to:
  /// **'Çöz'**
  String get talepCoz;

  /// No description provided for @talepReddedildiBildirim.
  ///
  /// In tr, this message translates to:
  /// **'Talep reddedildi ✓'**
  String get talepReddedildiBildirim;

  /// No description provided for @talepReddet.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get talepReddet;

  /// No description provided for @talepReddediliyor.
  ///
  /// In tr, this message translates to:
  /// **'Reddediliyor...'**
  String get talepReddediliyor;

  /// No description provided for @talepPersonelAlinamadiKisa.
  ///
  /// In tr, this message translates to:
  /// **'Personel listesi alınamadı.'**
  String get talepPersonelAlinamadiKisa;

  /// No description provided for @talepIsEmrineDonustur.
  ///
  /// In tr, this message translates to:
  /// **'İş emrine dönüştür'**
  String get talepIsEmrineDonustur;

  /// No description provided for @talepAtanabilirPersonelYok.
  ///
  /// In tr, this message translates to:
  /// **'Atanabilir aktif saha personeli yok. Dönüştürmek için önce security/tesis görevlisi ekleyin.'**
  String get talepAtanabilirPersonelYok;

  /// No description provided for @talepDonusturuluyor.
  ///
  /// In tr, this message translates to:
  /// **'Dönüştürülüyor...'**
  String get talepDonusturuluyor;

  /// No description provided for @talepDonustur.
  ///
  /// In tr, this message translates to:
  /// **'Dönüştür'**
  String get talepDonustur;

  /// No description provided for @talepReddetBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Talebi reddet'**
  String get talepReddetBaslik;

  /// No description provided for @talepRetSebebiNot.
  ///
  /// In tr, this message translates to:
  /// **'Ret sebebi talebi açan kişiye durum geçmişinde görünür.'**
  String get talepRetSebebiNot;

  /// No description provided for @talepRetSebebi.
  ///
  /// In tr, this message translates to:
  /// **'Ret sebebi'**
  String get talepRetSebebi;

  /// No description provided for @talepCozBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Talebi çöz'**
  String get talepCozBaslik;

  /// No description provided for @talepCozNot.
  ///
  /// In tr, this message translates to:
  /// **'Talep iş emri açmadan doğrudan çözüldü olarak işaretlenir.'**
  String get talepCozNot;

  /// No description provided for @talepCozumNotu.
  ///
  /// In tr, this message translates to:
  /// **'Çözüm notu (opsiyonel)'**
  String get talepCozumNotu;

  /// No description provided for @talepKategorilerYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler yüklenemedi.'**
  String get talepKategorilerYuklenemedi;

  /// No description provided for @talepFotoYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklenemedi.'**
  String get talepFotoYuklenemedi;

  /// No description provided for @binaKat.
  ///
  /// In tr, this message translates to:
  /// **'Kat'**
  String get binaKat;

  /// No description provided for @binaKatYardim.
  ///
  /// In tr, this message translates to:
  /// **'0 = zemin'**
  String get binaKatYardim;

  /// No description provided for @binaBloksuz.
  ///
  /// In tr, this message translates to:
  /// **'Bloksuz'**
  String get binaBloksuz;

  /// No description provided for @talepAcanSakin.
  ///
  /// In tr, this message translates to:
  /// **'Sakin'**
  String get talepAcanSakin;

  /// No description provided for @rezSekmeRezervasyonlar.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonlar ({n})'**
  String rezSekmeRezervasyonlar(Object n);

  /// No description provided for @rezSekmeAlanlar.
  ///
  /// In tr, this message translates to:
  /// **'Alanlar ({n})'**
  String rezSekmeAlanlar(Object n);

  /// No description provided for @rezYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonunuz yok. \"Alanlar\" sekmesinden bir alan seçip boş bir slotu ayırtın.'**
  String get rezYokSakin;

  /// No description provided for @rezYok.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyon yok.'**
  String get rezYok;

  /// No description provided for @rezYeniAlan.
  ///
  /// In tr, this message translates to:
  /// **'Yeni alan'**
  String get rezYeniAlan;

  /// No description provided for @rezAlanEklendi.
  ///
  /// In tr, this message translates to:
  /// **'Ortak alan eklendi ✓'**
  String get rezAlanEklendi;

  /// No description provided for @rezAlanGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Alan güncellendi ✓'**
  String get rezAlanGuncellendi;

  /// No description provided for @rezOrtakAlan.
  ///
  /// In tr, this message translates to:
  /// **'Ortak alan'**
  String get rezOrtakAlan;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{tarih} · {baslangic}-{bitis} · {kisi} kişi'**
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  );

  /// No description provided for @rezIptalEdildi.
  ///
  /// In tr, this message translates to:
  /// **'İptal edildi'**
  String get rezIptalEdildi;

  /// No description provided for @rezIptalEdilsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyon iptal edilsin mi?'**
  String get rezIptalEdilsinMi;

  /// No description provided for @rezIptalUyari.
  ///
  /// In tr, this message translates to:
  /// **'Slot yeniden boşa çıkar; bu işlem geri alınamaz.'**
  String get rezIptalUyari;

  /// No description provided for @rezEvetIptalEt.
  ///
  /// In tr, this message translates to:
  /// **'Evet, iptal et'**
  String get rezEvetIptalEt;

  /// No description provided for @rezIptalEdildiBildirim.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyon iptal edildi'**
  String get rezIptalEdildiBildirim;

  /// No description provided for @rezIptalGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'İptal gönderilemedi. Tekrar deneyin.'**
  String get rezIptalGonderilemedi;

  /// No description provided for @rezIptalEt.
  ///
  /// In tr, this message translates to:
  /// **'İptal et'**
  String get rezIptalEt;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'Tarih: {tarih} · {baslangic}-{bitis}'**
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis);

  /// No description provided for @rezDetayKisi.
  ///
  /// In tr, this message translates to:
  /// **'Kişi sayısı: {n}'**
  String rezDetayKisi(Object n);

  /// No description provided for @rezDetayRezerve.
  ///
  /// In tr, this message translates to:
  /// **'Rezerve: {zaman}'**
  String rezDetayRezerve(Object zaman);

  /// No description provided for @rezDetayNot.
  ///
  /// In tr, this message translates to:
  /// **'Not: {not}'**
  String rezDetayNot(Object not);

  /// No description provided for @rezAlanYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ortak alan yok. \"Yeni alan\" ile ekleyin.'**
  String get rezAlanYokYonetim;

  /// No description provided for @rezAlanYokGoruntuleme.
  ///
  /// In tr, this message translates to:
  /// **'Görüntülenecek ortak alan yok.'**
  String get rezAlanYokGoruntuleme;

  /// No description provided for @rezAlanYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Rezerve edilebilir alan yok.'**
  String get rezAlanYokSakin;

  /// No description provided for @rezMusait.
  ///
  /// In tr, this message translates to:
  /// **'Müsait: {ozet}'**
  String rezMusait(Object ozet);

  /// Alan musaitlik ozeti — domain'den TASINDI (metin cizimde)
  ///
  /// In tr, this message translates to:
  /// **'{acilis}–{kapanis} · {dakika} dk slot'**
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika);

  /// No description provided for @rezAcikDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Açık · düzenlemek için dokun'**
  String get rezAcikDuzenle;

  /// No description provided for @rezKapaliDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı · düzenlemek için dokun'**
  String get rezKapaliDuzenle;

  /// No description provided for @rezMusaitSlotlariGor.
  ///
  /// In tr, this message translates to:
  /// **'Müsait: {ozet} · dokunup slotları gör'**
  String rezMusaitSlotlariGor(Object ozet);

  /// No description provided for @rezPasifAlan.
  ///
  /// In tr, this message translates to:
  /// **'Pasif (rezerve edilemez)'**
  String get rezPasifAlan;

  /// No description provided for @rezKapanisSonra.
  ///
  /// In tr, this message translates to:
  /// **'Kapanış saati açılıştan sonra olmalı.'**
  String get rezKapanisSonra;

  /// No description provided for @rezAlanEklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Alan eklenemedi. Tekrar deneyin.'**
  String get rezAlanEklenemedi;

  /// No description provided for @rezAlanDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Alanı düzenle'**
  String get rezAlanDuzenle;

  /// No description provided for @rezYeniOrtakAlan.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ortak alan'**
  String get rezYeniOrtakAlan;

  /// No description provided for @rezAlanAdi.
  ///
  /// In tr, this message translates to:
  /// **'Alan adı * (örn. Havuz)'**
  String get rezAlanAdi;

  /// No description provided for @rezAlanAdiGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Alan adı gerekli'**
  String get rezAlanAdiGerekli;

  /// No description provided for @rezMusaitlikHerGun.
  ///
  /// In tr, this message translates to:
  /// **'Müsaitlik (her gün)'**
  String get rezMusaitlikHerGun;

  /// No description provided for @rezAcilis.
  ///
  /// In tr, this message translates to:
  /// **'Açılış: {saat}'**
  String rezAcilis(Object saat);

  /// No description provided for @rezKapanis.
  ///
  /// In tr, this message translates to:
  /// **'Kapanış: {saat}'**
  String rezKapanis(Object saat);

  /// No description provided for @rezSlotUzunlugu.
  ///
  /// In tr, this message translates to:
  /// **'Slot uzunluğu'**
  String get rezSlotUzunlugu;

  /// No description provided for @rezSlotDakika.
  ///
  /// In tr, this message translates to:
  /// **'{n} dakika'**
  String rezSlotDakika(Object n);

  /// No description provided for @rezAlaniEkle.
  ///
  /// In tr, this message translates to:
  /// **'Alanı ekle'**
  String get rezAlaniEkle;

  /// No description provided for @rezSlotlarYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Slotlar yüklenemedi. Tekrar deneyin.'**
  String get rezSlotlarYuklenemedi;

  /// No description provided for @rezOnaylandi.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonunuz onaylandı ✓'**
  String get rezOnaylandi;

  /// No description provided for @rezTarihEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Tarih: {tarih}'**
  String rezTarihEtiket(Object tarih);

  /// No description provided for @rezSlotKurali.
  ///
  /// In tr, this message translates to:
  /// **'Slot yalnızca başlangıcına 24 saatten az kala açılır; günde en fazla bir rezervasyon yapabilirsiniz.'**
  String get rezSlotKurali;

  /// No description provided for @rezSlotYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu alan için tanımlı slot yok.'**
  String get rezSlotYok;

  /// No description provided for @rezBenimAktif.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonum (aktif)'**
  String get rezBenimAktif;

  /// No description provided for @rezBenimGecti.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonum (geçti)'**
  String get rezBenimGecti;

  /// No description provided for @rezDoluBaskasi.
  ///
  /// In tr, this message translates to:
  /// **'Dolu (başkası)'**
  String get rezDoluBaskasi;

  /// No description provided for @rezSizinGecti.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonunuz (geçti)'**
  String get rezSizinGecti;

  /// No description provided for @rezKisiEki.
  ///
  /// In tr, this message translates to:
  /// **' · {n} kişi'**
  String rezKisiEki(Object n);

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'Dolu · Daire {daire}{kisi}'**
  String rezDoluDaire(Object daire, Object kisi);

  /// No description provided for @rezBos.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get rezBos;

  /// No description provided for @rezDolu.
  ///
  /// In tr, this message translates to:
  /// **'Dolu'**
  String get rezDolu;

  /// Parametre sirasi MESAJ sirasidir (bkz. §15 notu).
  ///
  /// In tr, this message translates to:
  /// **'{baslangic} – {bitis}'**
  String rezSlotAralik(Object baslangic, Object bitis);

  /// No description provided for @rezSec.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get rezSec;

  /// No description provided for @rezGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi. Tekrar deneyin.'**
  String get rezGonderilemedi;

  /// No description provided for @rezEtBaslik.
  ///
  /// In tr, this message translates to:
  /// **'{ad} — rezerve et'**
  String rezEtBaslik(Object ad);

  /// No description provided for @rezKisiSayisiEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Kişi sayısı:'**
  String get rezKisiSayisiEtiket;

  /// No description provided for @rezEt.
  ///
  /// In tr, this message translates to:
  /// **'Rezerve et'**
  String get rezEt;

  /// No description provided for @rezDurumOnayli.
  ///
  /// In tr, this message translates to:
  /// **'Onaylı'**
  String get rezDurumOnayli;

  /// Slot kapali sebebi — domain enum'u METIN TASIMAZ
  ///
  /// In tr, this message translates to:
  /// **'dolu'**
  String get rezSebepDolu;

  /// No description provided for @rezSebepGecti.
  ///
  /// In tr, this message translates to:
  /// **'geçti'**
  String get rezSebepGecti;

  /// No description provided for @rezSebepCokErken.
  ///
  /// In tr, this message translates to:
  /// **'24s içinde açılır'**
  String get rezSebepCokErken;

  /// No description provided for @rezSebepGunluk.
  ///
  /// In tr, this message translates to:
  /// **'günlük hakkınız dolu'**
  String get rezSebepGunluk;

  /// No description provided for @etkSekmeYaklasan.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan ({n})'**
  String etkSekmeYaklasan(Object n);

  /// No description provided for @etkSekmeGecmis.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş ({n})'**
  String etkSekmeGecmis(Object n);

  /// No description provided for @etkYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni etkinlik'**
  String get etkYeni;

  /// No description provided for @etkYaklasanYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlik yok. \"Yeni etkinlik\" ile duyurun.'**
  String get etkYaklasanYokYonetim;

  /// No description provided for @etkYaklasanYok.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlik yok.'**
  String get etkYaklasanYok;

  /// No description provided for @etkGecmisYok.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş etkinlik yok.'**
  String get etkGecmisYok;

  /// No description provided for @etkDuyuruldu.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik duyuruldu — sakinlere bildirildi ✓'**
  String get etkDuyuruldu;

  /// No description provided for @etkGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik güncellendi ✓'**
  String get etkGuncellendi;

  /// RSVP katilan sayisi (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} katılıyor'**
  String etkKatiliyorSayisi(num n);

  /// RSVP katilmayan sayisi (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} katılmıyor'**
  String etkKatilmiyorSayisi(num n);

  /// No description provided for @etkKatiliminiz.
  ///
  /// In tr, this message translates to:
  /// **'Katılımınız: {durum}'**
  String etkKatiliminiz(Object durum);

  /// No description provided for @etkBeyanKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Beyanınız kaydedildi: {durum} ✓'**
  String etkBeyanKaydedildi(Object durum);

  /// No description provided for @etkBeyanGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Beyan gönderilemedi. Tekrar deneyin.'**
  String get etkBeyanGonderilemedi;

  /// No description provided for @etkKatiliyorum.
  ///
  /// In tr, this message translates to:
  /// **'Katılıyorum'**
  String get etkKatiliyorum;

  /// No description provided for @etkKatilmiyorum.
  ///
  /// In tr, this message translates to:
  /// **'Katılmıyorum'**
  String get etkKatilmiyorum;

  /// No description provided for @etkZaman.
  ///
  /// In tr, this message translates to:
  /// **'Zaman: {aralik}'**
  String etkZaman(Object aralik);

  /// No description provided for @etkYer.
  ///
  /// In tr, this message translates to:
  /// **'Yer: {konum}'**
  String etkYer(Object konum);

  /// No description provided for @etkDuyuran.
  ///
  /// In tr, this message translates to:
  /// **'Duyuran: {ad}'**
  String etkDuyuran(Object ad);

  /// No description provided for @etkSilinsinMi.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik silinsin mi?'**
  String get etkSilinsinMi;

  /// No description provided for @etkSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'\"{baslik}\" ve tüm katılım beyanları silinecek.'**
  String etkSilOnay(Object baslik);

  /// No description provided for @etkSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik silindi ✓'**
  String get etkSilindi;

  /// No description provided for @etkBitisSonra.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş, başlangıçtan sonra olmalı'**
  String get etkBitisSonra;

  /// No description provided for @etkKaydedilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi. Tekrar deneyin.'**
  String get etkKaydedilemedi;

  /// No description provided for @etkDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği düzenle'**
  String get etkDuzenleBaslik;

  /// No description provided for @etkBaslikAlan.
  ///
  /// In tr, this message translates to:
  /// **'Başlık * (örn. Maç izleme akşamı)'**
  String get etkBaslikAlan;

  /// No description provided for @etkBaslikGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Başlık gerekli'**
  String get etkBaslikGerekli;

  /// No description provided for @etkAciklamaAlan.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama *'**
  String get etkAciklamaAlan;

  /// No description provided for @etkAciklamaGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama gerekli'**
  String get etkAciklamaGerekli;

  /// No description provided for @etkZamanSecim.
  ///
  /// In tr, this message translates to:
  /// **'Zaman: {zaman}'**
  String etkZamanSecim(Object zaman);

  /// No description provided for @etkBitisEkle.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş ekle (opsiyonel)'**
  String get etkBitisEkle;

  /// No description provided for @etkBitis.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş: {zaman}'**
  String etkBitis(Object zaman);

  /// No description provided for @etkBitisiKaldir.
  ///
  /// In tr, this message translates to:
  /// **'Bitişi kaldır'**
  String get etkBitisiKaldir;

  /// No description provided for @etkYerAlan.
  ///
  /// In tr, this message translates to:
  /// **'Yer (opsiyonel)'**
  String get etkYerAlan;

  /// No description provided for @etkGorselAlan.
  ///
  /// In tr, this message translates to:
  /// **'Görsel (opsiyonel)'**
  String get etkGorselAlan;

  /// No description provided for @etkDuyurVeBildir.
  ///
  /// In tr, this message translates to:
  /// **'Duyur ve sakinlere bildir'**
  String get etkDuyurVeBildir;

  /// No description provided for @izinBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüleme izni'**
  String get izinBaslik;

  /// No description provided for @izinTumDairelere.
  ///
  /// In tr, this message translates to:
  /// **'Tüm dairelere izin iste'**
  String get izinTumDairelere;

  /// No description provided for @izinYeniIstek.
  ///
  /// In tr, this message translates to:
  /// **'Yeni istek'**
  String get izinYeniIstek;

  /// No description provided for @izinIstekYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz izin isteğiniz yok. \"Yeni istek\" ile bir daire, üstteki \"Tüm daireler\" ile tümü için izin isteyin.'**
  String get izinIstekYokYonetim;

  /// No description provided for @izinIstekYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Dairenize gelen görüntüleme isteği yok.'**
  String get izinIstekYokSakin;

  /// No description provided for @izinTumDaireUyari.
  ///
  /// In tr, this message translates to:
  /// **'Sakini olan tüm daireler için görüntüleme izni isteği gönderilecek. Her daire kendi sakininin onayına bağlıdır — yalnızca onaylayan dairelerin kayıtlarını görebilirsiniz.'**
  String get izinTumDaireUyari;

  /// No description provided for @izinAtlandiEki.
  ///
  /// In tr, this message translates to:
  /// **' ({n} zaten açık)'**
  String izinAtlandiEki(Object n);

  /// atlandi = ' (n zaten acik)' eki ya da bos
  ///
  /// In tr, this message translates to:
  /// **'{n} daire için istek gönderildi{atlandi} — sakin onayları bekleniyor'**
  String izinTopluGonderildi(Object n, Object atlandi);

  /// No description provided for @izinGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi: {hata}'**
  String izinGonderilemedi(Object hata);

  /// No description provided for @izinIsteBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüleme izni iste'**
  String get izinIsteBaslik;

  /// No description provided for @izinDaireNo.
  ///
  /// In tr, this message translates to:
  /// **'Daire no (örn. A-12)'**
  String get izinDaireNo;

  /// No description provided for @izinIstekGonder.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönder'**
  String get izinIstekGonder;

  /// No description provided for @izinIstekGonderildi.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönderildi — sakinin onayı bekleniyor'**
  String get izinIstekGonderildi;

  /// No description provided for @izinDaireIstegi.
  ///
  /// In tr, this message translates to:
  /// **'Daire görüntüleme isteği{daire}'**
  String izinDaireIstegi(Object daire);

  /// No description provided for @izinIsteyen.
  ///
  /// In tr, this message translates to:
  /// **'İsteyen: {ad}'**
  String izinIsteyen(Object ad);

  /// No description provided for @izinKullanildiUyari.
  ///
  /// In tr, this message translates to:
  /// **'İzin kullanıldı (tek seferlik). Tekrar görmek için yeni istek açın.'**
  String get izinKullanildiUyari;

  /// No description provided for @izinGoruntulenebilirDaireler.
  ///
  /// In tr, this message translates to:
  /// **'Görüntülenebilir daireler ({n})'**
  String izinGoruntulenebilirDaireler(Object n);

  /// No description provided for @izinKullanildi.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıldı'**
  String get izinKullanildi;

  /// No description provided for @izinOnayli.
  ///
  /// In tr, this message translates to:
  /// **'Onaylı'**
  String get izinOnayli;

  /// No description provided for @izinVerildi.
  ///
  /// In tr, this message translates to:
  /// **'İzin verildi'**
  String get izinVerildi;

  /// No description provided for @izinOnayla.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get izinOnayla;

  /// No description provided for @izinKargolar.
  ///
  /// In tr, this message translates to:
  /// **'Kargolar'**
  String get izinKargolar;

  /// Ziyaretci/kargo ekran basligi + opsiyonel daire eki
  ///
  /// In tr, this message translates to:
  /// **'{baslik}{daire}'**
  String izinKayitBaslik(Object baslik, Object daire);

  /// No description provided for @izinDaireEki.
  ///
  /// In tr, this message translates to:
  /// **' — {daire}'**
  String izinDaireEki(Object daire);

  /// No description provided for @izinSuresiDoldu.
  ///
  /// In tr, this message translates to:
  /// **'İzin kullanıldı veya süresi doldu (tek seferlik). Tekrar görüntülemek için yeni bir izin isteği açın.'**
  String get izinSuresiDoldu;

  /// No description provided for @izinTekSeferlikUyari.
  ///
  /// In tr, this message translates to:
  /// **'Tek seferlik izinle görüntüleniyor — yenilemede erişim kapanır.'**
  String get izinTekSeferlikUyari;

  /// No description provided for @izinKayitYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu dairede kayıt yok.'**
  String get izinKayitYok;

  /// No description provided for @izinHedef.
  ///
  /// In tr, this message translates to:
  /// **'Hedef: {ad}'**
  String izinHedef(Object ad);

  /// No description provided for @izinKaydeden.
  ///
  /// In tr, this message translates to:
  /// **'Kaydeden: {ad}'**
  String izinKaydeden(Object ad);

  /// No description provided for @izinDurumEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Durum: {durum}'**
  String izinDurumEtiket(Object durum);

  /// No description provided for @izinDurumOnaylandi.
  ///
  /// In tr, this message translates to:
  /// **'Onaylandı'**
  String get izinDurumOnaylandi;

  /// No description provided for @kargoDurumTeslimAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Teslim alındı'**
  String get kargoDurumTeslimAlindi;

  /// No description provided for @rezSizin.
  ///
  /// In tr, this message translates to:
  /// **'Rezervasyonunuz'**
  String get rezSizin;

  /// No description provided for @butBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bütçe'**
  String get butBaslik;

  /// No description provided for @butSekmeOzet.
  ///
  /// In tr, this message translates to:
  /// **'Özet'**
  String get butSekmeOzet;

  /// No description provided for @butSekmeHareketler.
  ///
  /// In tr, this message translates to:
  /// **'Hareketler'**
  String get butSekmeHareketler;

  /// No description provided for @butSekmeKategoriler.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get butSekmeKategoriler;

  /// No description provided for @butTumZamanlar.
  ///
  /// In tr, this message translates to:
  /// **'Tüm zamanlar'**
  String get butTumZamanlar;

  /// No description provided for @butDonem.
  ///
  /// In tr, this message translates to:
  /// **'Dönem'**
  String get butDonem;

  /// No description provided for @butGelir.
  ///
  /// In tr, this message translates to:
  /// **'Gelir'**
  String get butGelir;

  /// No description provided for @butGider.
  ///
  /// In tr, this message translates to:
  /// **'Gider'**
  String get butGider;

  /// No description provided for @butKasa.
  ///
  /// In tr, this message translates to:
  /// **'Kasa'**
  String get butKasa;

  /// No description provided for @butKategoriKirilimi.
  ///
  /// In tr, this message translates to:
  /// **'Kategori kırılımı'**
  String get butKategoriKirilimi;

  /// No description provided for @butYeniHareket.
  ///
  /// In tr, this message translates to:
  /// **'Yeni hareket'**
  String get butYeniHareket;

  /// No description provided for @butHareketYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hareket yok.'**
  String get butHareketYok;

  /// No description provided for @butKategori.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get butKategori;

  /// No description provided for @butOtomatik.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get butOtomatik;

  /// No description provided for @butKategoriSecin.
  ///
  /// In tr, this message translates to:
  /// **'Kategori seçin'**
  String get butKategoriSecin;

  /// No description provided for @butTutar.
  ///
  /// In tr, this message translates to:
  /// **'Tutar (TL)'**
  String get butTutar;

  /// No description provided for @butTutarIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. 1.250,50'**
  String get butTutarIpucu;

  /// No description provided for @butTutarGecersiz.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir tutar girin (örn. 1.250,50)'**
  String get butTutarGecersiz;

  /// No description provided for @butTarih.
  ///
  /// In tr, this message translates to:
  /// **'Tarih: {tarih}'**
  String butTarih(Object tarih);

  /// No description provided for @butYeniKategori.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kategori'**
  String get butYeniKategori;

  /// No description provided for @butKategoriYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kategori yok.'**
  String get butKategoriYok;

  /// No description provided for @butKategoriAdi.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get butKategoriAdi;

  /// No description provided for @butKategoriAdiIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Bahçe bakımı'**
  String get butKategoriAdiIpucu;

  /// No description provided for @butAdZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Ad zorunludur'**
  String get butAdZorunlu;

  /// Kategori adi + tip etiketi (Gelir/Gider)
  ///
  /// In tr, this message translates to:
  /// **'{ad} ({tip})'**
  String butKategoriTip(Object ad, Object tip);

  /// No description provided for @butPasifEki.
  ///
  /// In tr, this message translates to:
  /// **' · pasif (yeni kayıt kapalı)'**
  String get butPasifEki;

  /// No description provided for @butBeklenmeyenKisa.
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen bir hata oluştu. Tekrar deneyin.'**
  String get butBeklenmeyenKisa;

  /// No description provided for @butFinansalOzet.
  ///
  /// In tr, this message translates to:
  /// **'Finansal özet'**
  String get butFinansalOzet;

  /// No description provided for @butAidatTahsilati.
  ///
  /// In tr, this message translates to:
  /// **'Aidat tahsilatı'**
  String get butAidatTahsilati;

  /// No description provided for @butEnYuksekGiderler.
  ///
  /// In tr, this message translates to:
  /// **'En yüksek giderler'**
  String get butEnYuksekGiderler;

  /// No description provided for @butTahsilatYuzde.
  ///
  /// In tr, this message translates to:
  /// **'Tahsilat %{yuzde}'**
  String butTahsilatYuzde(Object yuzde);

  /// No description provided for @butTahakkukYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem için tahakkuk kaydı yok.'**
  String get butTahakkukYok;

  /// No description provided for @butSiteBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Site Bütçesi'**
  String get butSiteBaslik;

  /// No description provided for @butKategoriToplamlari.
  ///
  /// In tr, this message translates to:
  /// **'Kategori toplamları'**
  String get butKategoriToplamlari;

  /// No description provided for @butSeffaflikNotu.
  ///
  /// In tr, this message translates to:
  /// **'Bu ekran site yönetiminin gelir ve giderlerini şeffaflık amacıyla özet olarak gösterir. Kişi ve daire bazlı detaylar görüntülenmez; sorularınız için yönetiminize başvurun.'**
  String get butSeffaflikNotu;

  /// No description provided for @demBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaş'**
  String get demBaslik;

  /// No description provided for @demEtiketOkut.
  ///
  /// In tr, this message translates to:
  /// **'Etiket okut'**
  String get demEtiketOkut;

  /// No description provided for @demBaskaEtiketOkut.
  ///
  /// In tr, this message translates to:
  /// **'Başka etiket okut'**
  String get demBaskaEtiketOkut;

  /// ek = ' (N)' sayaci ya da bos
  ///
  /// In tr, this message translates to:
  /// **'Üzerimdekiler{ek}'**
  String demUzerimdekiler(Object ek);

  /// No description provided for @demNfcAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaşı alırken veya bırakırken üzerindeki NFC etiketini okutun. Uygulama demirbaşı tanır ve kimde olduğunu gösterir.'**
  String get demNfcAciklama;

  /// No description provided for @demTaniniyor.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaş tanınıyor...'**
  String get demTaniniyor;

  /// No description provided for @demKimsedeDegil.
  ///
  /// In tr, this message translates to:
  /// **'Kimsede değil — alınabilir.'**
  String get demKimsedeDegil;

  /// Sure PARCASI ({sure}) edati kendi tasir — bkz. demSure*
  ///
  /// In tr, this message translates to:
  /// **'SENDE — {sure} üzerinde.'**
  String demSende(Object sure);

  /// Sure PARCASI ({sure}) edati kendi tasir
  ///
  /// In tr, this message translates to:
  /// **'Başkasında: {ad} — {sure} üzerinde.'**
  String demBaskasinda(Object ad, Object sure);

  /// No description provided for @demBaskasininUzerinde.
  ///
  /// In tr, this message translates to:
  /// **'Başkasının üzerinde görünüyor.'**
  String get demBaskasininUzerinde;

  /// No description provided for @demBakimda.
  ///
  /// In tr, this message translates to:
  /// **'Bakımda — şu an zimmetlenemez.'**
  String get demBakimda;

  /// No description provided for @demZorlaDevralmaYok.
  ///
  /// In tr, this message translates to:
  /// **'Zorla devralma yok — demirbaşı şu anki kullanıcısı bırakmalı.'**
  String get demZorlaDevralmaYok;

  /// No description provided for @demZimmetineAl.
  ///
  /// In tr, this message translates to:
  /// **'Zimmetine al'**
  String get demZimmetineAl;

  /// No description provided for @demBirak.
  ///
  /// In tr, this message translates to:
  /// **'Bırak / iade et'**
  String get demBirak;

  /// No description provided for @demBirakKisa.
  ///
  /// In tr, this message translates to:
  /// **'Bırak'**
  String get demBirakKisa;

  /// No description provided for @demSonHareketler.
  ///
  /// In tr, this message translates to:
  /// **'Son hareketler'**
  String get demSonHareketler;

  /// No description provided for @demAldi.
  ///
  /// In tr, this message translates to:
  /// **'{ad} aldı — {zaman} (hala üzerinde)'**
  String demAldi(Object ad, Object zaman);

  /// No description provided for @demListeYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Demirbaş listesi için yetkiniz yok.'**
  String get demListeYetkiYok;

  /// No description provided for @demUzerindeYok.
  ///
  /// In tr, this message translates to:
  /// **'Şu an üzerinde demirbaş görünmüyor.'**
  String get demUzerindeYok;

  /// No description provided for @demAldin.
  ///
  /// In tr, this message translates to:
  /// **'Aldın: {zaman} ({sure})'**
  String demAldin(Object zaman, Object sure);

  /// No description provided for @demSureBelirsiz.
  ///
  /// In tr, this message translates to:
  /// **'bir süredir'**
  String get demSureBelirsiz;

  /// No description provided for @demSureAzOnce.
  ///
  /// In tr, this message translates to:
  /// **'az önce alındı, o zamandan beri'**
  String get demSureAzOnce;

  /// Sure parcasi (ICU cogul) — sablona {sure} olarak girer
  ///
  /// In tr, this message translates to:
  /// **'{n} dakikadır'**
  String demSureDakika(num n);

  /// Sure parcasi (ICU cogul) — sablona {sure} olarak girer
  ///
  /// In tr, this message translates to:
  /// **'{n} saattir'**
  String demSureSaat(num n);

  /// Sure parcasi (ICU cogul) — sablona {sure} olarak girer
  ///
  /// In tr, this message translates to:
  /// **'{n} gündür'**
  String demSureGun(num n);

  /// No description provided for @demOfflineUyari.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı gerekli. Zimmet kimde-olduğu ANLIK bir kayıttır; offline işlem yapılmaz (kuyruklamak yanıltıcı olurdu).'**
  String get demOfflineUyari;

  /// No description provided for @demEtiketEslesmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu etiket ({uid}) kayıtlı bir demirbaşla eşleşmiyor. Etiket panelden bir demirbaşa tanımlanmalı.'**
  String demEtiketEslesmiyor(Object uid);

  /// No description provided for @demZatenZimmetinde.
  ///
  /// In tr, this message translates to:
  /// **'Zaten zimmetindeydi ✓ (tekrar gönderim — çift kayıt yok)'**
  String get demZatenZimmetinde;

  /// No description provided for @demZimmetineAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Zimmetine alındı ✓'**
  String get demZimmetineAlindi;

  /// No description provided for @demBirakildi.
  ///
  /// In tr, this message translates to:
  /// **'Bırakıldı ✓ — zimmet kapatıldı.'**
  String get demBirakildi;

  /// No description provided for @demIslemYapilamadi.
  ///
  /// In tr, this message translates to:
  /// **'İşlem yapılamadı: {hata} Durum güncellendi — karta tekrar bakın.'**
  String demIslemYapilamadi(Object hata);

  /// No description provided for @demHataSatiri.
  ///
  /// In tr, this message translates to:
  /// **'{ad}: {hata}'**
  String demHataSatiri(Object ad, Object hata);

  /// No description provided for @karBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kargo'**
  String get karBaslik;

  /// No description provided for @karSekmeBekleyen.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen ({n})'**
  String karSekmeBekleyen(Object n);

  /// No description provided for @karSekmeTeslim.
  ///
  /// In tr, this message translates to:
  /// **'Teslim alınan ({n})'**
  String karSekmeTeslim(Object n);

  /// No description provided for @karYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kargo'**
  String get karYeni;

  /// No description provided for @karBekleyenYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Teslim bekleyen kargonuz yok.'**
  String get karBekleyenYokSakin;

  /// No description provided for @karBekleyenYok.
  ///
  /// In tr, this message translates to:
  /// **'Teslim bekleyen kargo yok.'**
  String get karBekleyenYok;

  /// No description provided for @karTeslimYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz teslim alınan kargo kaydı yok.'**
  String get karTeslimYok;

  /// No description provided for @karKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Kargo kaydedildi — daire sakinlerine bildirildi ✓'**
  String get karKaydedildi;

  /// Daire no + kayit zamani (dile duyarli bicim)
  ///
  /// In tr, this message translates to:
  /// **'Daire: {daire} · {zaman}'**
  String karDaireTarih(Object daire, Object zaman);

  /// No description provided for @karDaire.
  ///
  /// In tr, this message translates to:
  /// **'Daire: {daire}'**
  String karDaire(Object daire);

  /// No description provided for @karKayit.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt: {zaman}'**
  String karKayit(Object zaman);

  /// No description provided for @karNot.
  ///
  /// In tr, this message translates to:
  /// **'Not: {not}'**
  String karNot(Object not);

  /// No description provided for @karTeslimAlindiBildirim.
  ///
  /// In tr, this message translates to:
  /// **'Kargo teslim alındı ✓'**
  String get karTeslimAlindiBildirim;

  /// No description provided for @karIsaretlenemedi.
  ///
  /// In tr, this message translates to:
  /// **'İşaretlenemedi. Tekrar deneyin.'**
  String get karIsaretlenemedi;

  /// No description provided for @karTeslimAldim.
  ///
  /// In tr, this message translates to:
  /// **'Teslim aldım'**
  String get karTeslimAldim;

  /// No description provided for @karGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt gönderilemedi. Tekrar deneyin.'**
  String get karGonderilemedi;

  /// No description provided for @karDaireNo.
  ///
  /// In tr, this message translates to:
  /// **'Daire no * (örn. A-12)'**
  String get karDaireNo;

  /// No description provided for @karDaireNoGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Daire no gerekli'**
  String get karDaireNoGerekli;

  /// No description provided for @karFirma.
  ///
  /// In tr, this message translates to:
  /// **'Kargo firması *'**
  String get karFirma;

  /// No description provided for @karFirmaGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Kargo firması gerekli'**
  String get karFirmaGerekli;

  /// No description provided for @karPaketFotografi.
  ///
  /// In tr, this message translates to:
  /// **'Paket fotoğrafı (opsiyonel)'**
  String get karPaketFotografi;

  /// No description provided for @karKaydetVeBildir.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet ve sakinlere bildir'**
  String get karKaydetVeBildir;

  /// No description provided for @ortakTekrarDene.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get ortakTekrarDene;

  /// No description provided for @butTahakkuk.
  ///
  /// In tr, this message translates to:
  /// **'Tahakkuk'**
  String get butTahakkuk;

  /// No description provided for @butTahsilat.
  ///
  /// In tr, this message translates to:
  /// **'Tahsilat'**
  String get butTahsilat;

  /// No description provided for @butGeciken.
  ///
  /// In tr, this message translates to:
  /// **'Geciken'**
  String get butGeciken;

  /// Kapali zimmet satiri: kim · alma -> birakma
  ///
  /// In tr, this message translates to:
  /// **'{ad} · {alma} → {birakma}'**
  String demAldiBirakti(Object ad, Object alma, Object birakma);

  /// Kargo satirinda istege bagli ad eki
  ///
  /// In tr, this message translates to:
  /// **' — {ad}'**
  String karAdEki(Object ad);

  /// Kargo satirinda istege bagli zaman eki
  ///
  /// In tr, this message translates to:
  /// **' · {zaman}'**
  String karZamanEki(Object zaman);

  /// No description provided for @kuralBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Site Kuralları'**
  String get kuralBaslik;

  /// No description provided for @kuralYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kural'**
  String get kuralYeni;

  /// No description provided for @kuralAramaIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Başlıkta ara (örn. havuz)'**
  String get kuralAramaIpucu;

  /// No description provided for @kuralEklendi.
  ///
  /// In tr, this message translates to:
  /// **'Kural eklendi ✓'**
  String get kuralEklendi;

  /// No description provided for @kuralGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Kural güncellendi ✓'**
  String get kuralGuncellendi;

  /// No description provided for @kuralAramaBos.
  ///
  /// In tr, this message translates to:
  /// **'Aramayla eşleşen kural yok.'**
  String get kuralAramaBos;

  /// No description provided for @kuralYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kural yok. \"Yeni kural\" ile ekleyin.'**
  String get kuralYokYonetim;

  /// No description provided for @kuralYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kural yayınlanmamış.'**
  String get kuralYokSakin;

  /// No description provided for @kuralSilOnayBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kural silinsin mi?'**
  String get kuralSilOnayBaslik;

  /// Tirnak icindeki {baslik} kullanicinin girdigi metin
  ///
  /// In tr, this message translates to:
  /// **'\"{baslik}\" kalıcı olarak silinecek.'**
  String kuralSilOnayGovde(Object baslik);

  /// No description provided for @kuralSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Kural silindi ✓'**
  String get kuralSilindi;

  /// No description provided for @kuralDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kuralı düzenle'**
  String get kuralDuzenleBaslik;

  /// No description provided for @kuralBaslikAlan.
  ///
  /// In tr, this message translates to:
  /// **'Başlık * (örn. Havuz Saatleri)'**
  String get kuralBaslikAlan;

  /// No description provided for @kuralBaslikGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Başlık gerekli'**
  String get kuralBaslikGerekli;

  /// No description provided for @kuralMetni.
  ///
  /// In tr, this message translates to:
  /// **'Kural metni *'**
  String get kuralMetni;

  /// No description provided for @kuralMetniGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Kural metni gerekli'**
  String get kuralMetniGerekli;

  /// No description provided for @kuralSira.
  ///
  /// In tr, this message translates to:
  /// **'Sıra (küçük önce)'**
  String get kuralSira;

  /// No description provided for @kuralSiraGecersiz.
  ///
  /// In tr, this message translates to:
  /// **'Sıra 0 veya pozitif tam sayı olmalı'**
  String get kuralSiraGecersiz;

  /// No description provided for @kuralMevcutGorsel.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut görsel korunuyor'**
  String get kuralMevcutGorsel;

  /// No description provided for @kuralEkleButon.
  ///
  /// In tr, this message translates to:
  /// **'Kuralı ekle'**
  String get kuralEkleButon;

  /// No description provided for @ortakFotoOnlineTekrarDene.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklemek için internet bağlantısı gerekli. Bağlantı gelince tekrar deneyin.'**
  String get ortakFotoOnlineTekrarDene;

  /// No description provided for @ortakFotoBekleyinVeyaKaldir.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf henüz yüklenmedi. Yüklemenin bitmesini bekleyin veya fotoyu kaldırın.'**
  String get ortakFotoBekleyinVeyaKaldir;

  /// No description provided for @duyuruYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni duyuru'**
  String get duyuruYeni;

  /// No description provided for @duyuruYayinlandi.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru yayınlandı ✓'**
  String get duyuruYayinlandi;

  /// No description provided for @duyuruGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru güncellendi ✓'**
  String get duyuruGuncellendi;

  /// No description provided for @duyuruYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz duyuru yok.'**
  String get duyuruYok;

  /// No description provided for @duyuruYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim'**
  String get duyuruYonetim;

  /// Duyuru alt satiri: yazar · zaman (+ duzenlendi eki)
  ///
  /// In tr, this message translates to:
  /// **'{ad} · {zaman}{duzenlendi}'**
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi);

  /// duyuruMeta icine giren istege bagli ek
  ///
  /// In tr, this message translates to:
  /// **' · düzenlendi'**
  String get duyuruDuzenlendiEki;

  /// No description provided for @duyuruSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru silinsin mi?'**
  String get duyuruSilOnay;

  /// No description provided for @duyuruSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru silindi ✓'**
  String get duyuruSilindi;

  /// No description provided for @duyuruDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru düzenle'**
  String get duyuruDuzenleBaslik;

  /// No description provided for @duyuruBaslikZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Başlık zorunludur'**
  String get duyuruBaslikZorunlu;

  /// No description provided for @duyuruMetniAlan.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru metni'**
  String get duyuruMetniAlan;

  /// No description provided for @duyuruMetniZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru metni zorunludur'**
  String get duyuruMetniZorunlu;

  /// No description provided for @duyuruYayinla.
  ///
  /// In tr, this message translates to:
  /// **'Yayınla'**
  String get duyuruYayinla;

  /// No description provided for @ortakIslemler.
  ///
  /// In tr, this message translates to:
  /// **'İşlemler'**
  String get ortakIslemler;

  /// No description provided for @sakinBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Site Sakinleri'**
  String get sakinBaslik;

  /// No description provided for @sakinEkle.
  ///
  /// In tr, this message translates to:
  /// **'Sakin ekle'**
  String get sakinEkle;

  /// No description provided for @sakinListelenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Sakinler listelenemedi.'**
  String get sakinListelenemedi;

  /// No description provided for @sakinDaireYok.
  ///
  /// In tr, this message translates to:
  /// **'Daire atanmamış'**
  String get sakinDaireYok;

  /// No description provided for @sakinIslemleri.
  ///
  /// In tr, this message translates to:
  /// **'Sakin işlemleri'**
  String get sakinIslemleri;

  /// No description provided for @sakinSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Sakini sil?'**
  String get sakinSilOnay;

  /// No description provided for @sakinSilGovde.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" silinir. Geçmiş kaydı yoksa tamamen silinir; varsa pasifleşir. Her durumda telefon numarası serbest kalır (aynı numarayla yeniden kayıt yapılabilir).'**
  String sakinSilGovde(Object ad);

  /// No description provided for @sakinSilindi.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" silindi (numara serbest)'**
  String sakinSilindi(Object ad);

  /// No description provided for @sakinPasiflestirildi.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" pasifleştirildi — geçmişi var (numara serbest)'**
  String sakinPasiflestirildi(Object ad);

  /// No description provided for @sakinDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Sakini düzenle'**
  String get sakinDuzenleBaslik;

  /// No description provided for @sakinYeniTelefon.
  ///
  /// In tr, this message translates to:
  /// **'Yeni cep telefonu'**
  String get sakinYeniTelefon;

  /// No description provided for @sakinBosBirakDegismez.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakırsanız değişmez'**
  String get sakinBosBirakDegismez;

  /// No description provided for @sakinGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Güncellendi ✓'**
  String get sakinGuncellendi;

  /// No description provided for @ortakAdSoyad.
  ///
  /// In tr, this message translates to:
  /// **'Ad Soyad'**
  String get ortakAdSoyad;

  /// No description provided for @telefonHataEksik.
  ///
  /// In tr, this message translates to:
  /// **'Numara eksik — 10 hane girin (örn. 0543 199 29 04).'**
  String get telefonHataEksik;

  /// No description provided for @telefonHataOnEk.
  ///
  /// In tr, this message translates to:
  /// **'Cep telefonu 5 ile başlamalı (örn. 0543…). Sabit hat kabul edilmez.'**
  String get telefonHataOnEk;

  /// No description provided for @ortakCepTelefonu.
  ///
  /// In tr, this message translates to:
  /// **'Cep telefonu'**
  String get ortakCepTelefonu;

  /// No description provided for @ortakTelefonIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. 0532 111 22 03'**
  String get ortakTelefonIpucu;

  /// No description provided for @ortakTelefonZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Telefon zorunludur'**
  String get ortakTelefonZorunlu;

  /// No description provided for @sakinGirisAnahtari.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca iletişim için (isteğe bağlı).'**
  String get sakinGirisAnahtari;

  /// No description provided for @ortakDaireNoIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. A-12'**
  String get ortakDaireNoIpucu;

  /// No description provided for @sakinDaireNoZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Daire no zorunludur'**
  String get sakinDaireNoZorunlu;

  /// No description provided for @sakinEklendi.
  ///
  /// In tr, this message translates to:
  /// **'Sakin eklendi ✓'**
  String get sakinEklendi;

  /// Iki satir (\n) — bos liste durumu
  ///
  /// In tr, this message translates to:
  /// **'Henüz site sakini yok.\nSağ alttan ekleyebilirsiniz.'**
  String get sakinYok;

  /// No description provided for @girisParolaVeyaKod.
  ///
  /// In tr, this message translates to:
  /// **'Parola veya geçici kod'**
  String get girisParolaVeyaKod;

  /// No description provided for @girisIlkKodIpucu.
  ///
  /// In tr, this message translates to:
  /// **'İlk girişte yönetimden aldığınız geçici kodu yazın.'**
  String get girisIlkKodIpucu;

  /// No description provided for @girisBeniHatirla.
  ///
  /// In tr, this message translates to:
  /// **'Beni hatırla'**
  String get girisBeniHatirla;

  /// No description provided for @girisYap.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get girisYap;

  /// No description provided for @girisOturumSonaErdi.
  ///
  /// In tr, this message translates to:
  /// **'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.'**
  String get girisOturumSonaErdi;

  /// No description provided for @parolaBelirleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Parolanızı belirleyin'**
  String get parolaBelirleBaslik;

  /// No description provided for @parolaBelirleAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Geçici kodla ilk girişinizi yaptınız. Devam etmek için kendi kalıcı parolanızı oluşturun; sonraki girişlerde daire no + bu parolayı kullanacaksınız.'**
  String get parolaBelirleAciklama;

  /// No description provided for @parolaBelirleButon.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı belirle'**
  String get parolaBelirleButon;

  /// No description provided for @parolaGiriseDon.
  ///
  /// In tr, this message translates to:
  /// **'Girişe dön'**
  String get parolaGiriseDon;

  /// No description provided for @ortakParolaZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Parola zorunludur'**
  String get ortakParolaZorunlu;

  /// No description provided for @ortakYeniParola.
  ///
  /// In tr, this message translates to:
  /// **'Yeni parola'**
  String get ortakYeniParola;

  /// No description provided for @ortakYeniParolaTekrar.
  ///
  /// In tr, this message translates to:
  /// **'Yeni parola (tekrar)'**
  String get ortakYeniParolaTekrar;

  /// No description provided for @ortakYeniParolaZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Yeni parola zorunludur'**
  String get ortakYeniParolaZorunlu;

  /// No description provided for @ortakParolalarEslesmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Parolalar eşleşmiyor'**
  String get ortakParolalarEslesmiyor;

  /// No description provided for @parolaKuraliKisa.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter olmalı'**
  String get parolaKuraliKisa;

  /// No description provided for @parolaKuraliBuyukHarf.
  ///
  /// In tr, this message translates to:
  /// **'En az bir büyük harf içermeli'**
  String get parolaKuraliBuyukHarf;

  /// No description provided for @parolaKuraliRakam.
  ///
  /// In tr, this message translates to:
  /// **'En az bir rakam içermeli'**
  String get parolaKuraliRakam;

  /// Parantez ICI teknik sabit — semboller cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'En az bir sembol içermeli (! ? @ # . -)'**
  String get parolaKuraliSembol;

  /// No description provided for @profilYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Profil yüklenemedi.'**
  String get profilYuklenemedi;

  /// No description provided for @profilNumaraYok.
  ///
  /// In tr, this message translates to:
  /// **'Numara girilmemiş'**
  String get profilNumaraYok;

  /// No description provided for @profilFotoBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı'**
  String get profilFotoBaslik;

  /// No description provided for @profilFotoSec.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf seç'**
  String get profilFotoSec;

  /// No description provided for @profilFotoGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı güncellendi ✓'**
  String get profilFotoGuncellendi;

  /// No description provided for @profilFotoKaldirildi.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı kaldırıldı'**
  String get profilFotoKaldirildi;

  /// No description provided for @ortakGaleri.
  ///
  /// In tr, this message translates to:
  /// **'Galeri'**
  String get ortakGaleri;

  /// No description provided for @profilParolaDegistir.
  ///
  /// In tr, this message translates to:
  /// **'Parola değiştir'**
  String get profilParolaDegistir;

  /// No description provided for @profilMevcutParola.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut parola'**
  String get profilMevcutParola;

  /// No description provided for @profilMevcutParolaZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut parola zorunludur'**
  String get profilMevcutParolaZorunlu;

  /// No description provided for @profilParolaGuncelle.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı güncelle'**
  String get profilParolaGuncelle;

  /// No description provided for @profilParolaGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Parola güncellendi ✓'**
  String get profilParolaGuncellendi;

  /// No description provided for @profilTelefon.
  ///
  /// In tr, this message translates to:
  /// **'Telefon'**
  String get profilTelefon;

  /// No description provided for @profilTelefonIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. +905551112233'**
  String get profilTelefonIpucu;

  /// No description provided for @profilAranabilir.
  ///
  /// In tr, this message translates to:
  /// **'Aranabilir'**
  String get profilAranabilir;

  /// No description provided for @profilAranabilirAlt.
  ///
  /// In tr, this message translates to:
  /// **'Yetkili roller (rıza gerektiren arama) numaranıza ulaşabilir'**
  String get profilAranabilirAlt;

  /// No description provided for @profilIletisimKaydet.
  ///
  /// In tr, this message translates to:
  /// **'İletişimi kaydet'**
  String get profilIletisimKaydet;

  /// No description provided for @profilIletisimGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'İletişim bilgileri güncellendi ✓'**
  String get profilIletisimGuncellendi;

  /// No description provided for @personelEkle.
  ///
  /// In tr, this message translates to:
  /// **'Personel ekle'**
  String get personelEkle;

  /// No description provided for @personelDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Personel düzenle'**
  String get personelDuzenle;

  /// No description provided for @personelListelenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Personel listelenemedi.'**
  String get personelListelenemedi;

  /// No description provided for @personelPasiflestir.
  ///
  /// In tr, this message translates to:
  /// **'Pasifleştir'**
  String get personelPasiflestir;

  /// No description provided for @personelAktiflestir.
  ///
  /// In tr, this message translates to:
  /// **'Aktifleştir'**
  String get personelAktiflestir;

  /// No description provided for @personelPasiflestirildi.
  ///
  /// In tr, this message translates to:
  /// **'Pasifleştirildi ✓'**
  String get personelPasiflestirildi;

  /// No description provided for @personelAktiflestirildi.
  ///
  /// In tr, this message translates to:
  /// **'Aktifleştirildi ✓'**
  String get personelAktiflestirildi;

  /// No description provided for @personelGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Personel güncellendi ✓'**
  String get personelGuncellendi;

  /// No description provided for @personelEklendi.
  ///
  /// In tr, this message translates to:
  /// **'Personel eklendi ✓'**
  String get personelEklendi;

  /// No description provided for @personelFoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get personelFoto;

  /// No description provided for @personelTelefonOpsiyonel.
  ///
  /// In tr, this message translates to:
  /// **'Cep telefonu (opsiyonel)'**
  String get personelTelefonOpsiyonel;

  /// No description provided for @personelBosBirakDegismezNokta.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakırsanız değişmez.'**
  String get personelBosBirakDegismezNokta;

  /// Iki satir (\n) — bos liste durumu
  ///
  /// In tr, this message translates to:
  /// **'Henüz saha personeli yok.\nSağ alttan ekleyebilirsiniz.'**
  String get personelYok;

  /// No description provided for @disKisiEkle.
  ///
  /// In tr, this message translates to:
  /// **'Kişi ekle'**
  String get disKisiEkle;

  /// No description provided for @disListeAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Liste alınamadı.'**
  String get disListeAlinamadi;

  /// No description provided for @disKayitYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kayıt yok. Sağ alttan güvendiğiniz esnafı ekleyin.'**
  String get disKayitYokYonetim;

  /// No description provided for @disKayitYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz dış hizmet kaydı yok.'**
  String get disKayitYok;

  /// No description provided for @disNotEkleyin.
  ///
  /// In tr, this message translates to:
  /// **'Not ekleyin (yalnızca yönetici düzenler).'**
  String get disNotEkleyin;

  /// No description provided for @disNotuDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Notu düzenle'**
  String get disNotuDuzenle;

  /// No description provided for @disBolumNotu.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm notu'**
  String get disBolumNotu;

  /// No description provided for @disNotIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Yıllardır güvendiğimiz esnaflar; site güvenliği için yabancı kişileri içeri almayın.'**
  String get disNotIpucu;

  /// No description provided for @disNotGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Not güncellendi ✓'**
  String get disNotGuncellendi;

  /// No description provided for @disAra.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get disAra;

  /// No description provided for @disSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt silinsin mi?'**
  String get disSilOnay;

  /// No description provided for @disSilGovde.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" silinecek.'**
  String disSilGovde(Object ad);

  /// No description provided for @disSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Silindi ✓'**
  String get disSilindi;

  /// No description provided for @disYeniKisi.
  ///
  /// In tr, this message translates to:
  /// **'Yeni dış hizmet kişisi'**
  String get disYeniKisi;

  /// No description provided for @disKisiDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Kişi düzenle'**
  String get disKisiDuzenle;

  /// No description provided for @disTur.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet türü'**
  String get disTur;

  /// No description provided for @disTurIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Çilingir, Elektrik, Tesisat'**
  String get disTurIpucu;

  /// No description provided for @disTurZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Tür zorunludur'**
  String get disTurZorunlu;

  /// No description provided for @disAd.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get disAd;

  /// No description provided for @disSoyad.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get disSoyad;

  /// No description provided for @disAdGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Ad gerekli'**
  String get disAdGerekli;

  /// No description provided for @disSoyadGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Soyad gerekli'**
  String get disSoyadGerekli;

  /// No description provided for @nfcBaslik.
  ///
  /// In tr, this message translates to:
  /// **'NFC etiket okuma'**
  String get nfcBaslik;

  /// No description provided for @nfcHazir.
  ///
  /// In tr, this message translates to:
  /// **'Okumaya hazır. Başlat\'a dokunun.'**
  String get nfcHazir;

  /// No description provided for @nfcYaklastirBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Etiketi telefonun arkasına yaklaştırın...'**
  String get nfcYaklastirBekliyor;

  /// No description provided for @nfcOkundu.
  ///
  /// In tr, this message translates to:
  /// **'Etiket okundu.'**
  String get nfcOkundu;

  /// No description provided for @nfcOkumayaBasla.
  ///
  /// In tr, this message translates to:
  /// **'Okumayı başlat'**
  String get nfcOkumayaBasla;

  /// No description provided for @nfcTekrarOku.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar oku'**
  String get nfcTekrarOku;

  /// Rozet ipucu (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'{n} okutma gönderim bekliyor'**
  String nfcKuyrukBekleyen(num n);

  /// No description provided for @nfcKuyruk.
  ///
  /// In tr, this message translates to:
  /// **'Gönderim kuyruğu'**
  String get nfcKuyruk;

  /// No description provided for @nfcKaydedildiBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek.'**
  String get nfcKaydedildiBekliyor;

  /// No description provided for @nfcKaydedildiGonderiliyor.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi ✓ — gönderiliyor...'**
  String get nfcKaydedildiGonderiliyor;

  /// No description provided for @nfcGonderildiZatenVar.
  ///
  /// In tr, this message translates to:
  /// **'Gönderildi ✓ — bu okutma zaten kayıtlıydı.'**
  String get nfcGonderildiZatenVar;

  /// No description provided for @nfcGonderildi.
  ///
  /// In tr, this message translates to:
  /// **'Gönderildi ✓ — okutma kaydedildi.'**
  String get nfcGonderildi;

  /// No description provided for @nfcEslesmeYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu etiket hiçbir checkpoint ile eşleşmiyor.'**
  String get nfcEslesmeYok;

  /// No description provided for @nfcSdmBaslik.
  ///
  /// In tr, this message translates to:
  /// **'SDM (ham, doğrulanmamış)'**
  String get nfcSdmBaslik;

  /// No description provided for @nfcTipEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Tip'**
  String get nfcTipEtiket;

  /// No description provided for @nfcNoktalarAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Noktalar alınamadı: {hata}'**
  String nfcNoktalarAlinamadi(Object hata);

  /// No description provided for @nfcTestBaslik.
  ///
  /// In tr, this message translates to:
  /// **'TEST: hangi noktayı okutalım?'**
  String get nfcTestBaslik;

  /// No description provided for @nfcTestAlt.
  ///
  /// In tr, this message translates to:
  /// **'Fiziksel etiket olmadan okutmayı simüle eder.'**
  String get nfcTestAlt;

  /// No description provided for @nfcAktifNoktaYok.
  ///
  /// In tr, this message translates to:
  /// **'Aktif kontrol noktası yok.'**
  String get nfcAktifNoktaYok;

  /// No description provided for @nfcAktifNoktaYokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Önce \"Kontrol noktaları\"ndan ekleyin.'**
  String get nfcAktifNoktaYokAlt;

  /// No description provided for @nfcManuelOkut.
  ///
  /// In tr, this message translates to:
  /// **'Manuel okut (test)'**
  String get nfcManuelOkut;

  /// No description provided for @nfcTestGorunur.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca test derlemesinde görünür.'**
  String get nfcTestGorunur;

  /// Teknik alan — UID etiketi cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'UID: {uid}'**
  String nfcUidSatir(Object uid);

  /// No description provided for @nfcHataKapali.
  ///
  /// In tr, this message translates to:
  /// **'NFC kapalı. Lütfen cihaz ayarlarından NFC\'yi açın.'**
  String get nfcHataKapali;

  /// No description provided for @nfcHataDesteklenmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihaz NFC desteklemiyor.'**
  String get nfcHataDesteklenmiyor;

  /// No description provided for @nfcHataUidOkunamadi.
  ///
  /// In tr, this message translates to:
  /// **'Etiket UID okunamadı.'**
  String get nfcHataUidOkunamadi;

  /// No description provided for @nfcHataCozumlenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Etiket çözümlenemedi: {detay}'**
  String nfcHataCozumlenemedi(Object detay);

  /// No description provided for @nfcHataOturum.
  ///
  /// In tr, this message translates to:
  /// **'NFC oturumu başlatılamadı: {detay}'**
  String nfcHataOturum(Object detay);

  /// No description provided for @nfcHataOkumaIptal.
  ///
  /// In tr, this message translates to:
  /// **'Okuma iptal edildi: {detay}'**
  String nfcHataOkumaIptal(Object detay);

  /// No description provided for @nfcHataYapilandirma.
  ///
  /// In tr, this message translates to:
  /// **'NFC bu yapımda kullanılamıyor: {detay}. Uygulamanın güncellenmesi gerekiyor; tekrar denemek sonucu değiştirmez.'**
  String nfcHataYapilandirma(Object detay);

  /// No description provided for @nfcHataBilinmeyen.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmeyen bir hata oluştu.'**
  String get nfcHataBilinmeyen;

  /// iOS SISTEM sayfasinda gorunur (NFCTagReaderSession)
  ///
  /// In tr, this message translates to:
  /// **'Etiketi telefonun arkasına yaklaştırın.'**
  String get nfcIosYaklastir;

  /// iOS SISTEM sayfasinda gorunur (NFCTagReaderSession)
  ///
  /// In tr, this message translates to:
  /// **'Okundu'**
  String get nfcIosOkundu;

  /// No description provided for @nfcIosIptal.
  ///
  /// In tr, this message translates to:
  /// **'İptal edildi'**
  String get nfcIosIptal;

  /// No description provided for @nfcIosOkunamadi.
  ///
  /// In tr, this message translates to:
  /// **'Okunamadı'**
  String get nfcIosOkunamadi;

  /// No description provided for @seffafYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi. Lütfen tekrar deneyin.'**
  String get seffafYuklenemedi;

  /// No description provided for @seffafAyYayinlandi.
  ///
  /// In tr, this message translates to:
  /// **'Ay yayınlandı.'**
  String get seffafAyYayinlandi;

  /// No description provided for @seffafYayinGeriAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Yayın geri alındı.'**
  String get seffafYayinGeriAlindi;

  /// No description provided for @seffafVeriYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz finansal veri yok. Gelir/gider veya aidat girildiğinde aylar burada listelenir.'**
  String get seffafVeriYokYonetim;

  /// No description provided for @seffafVeriYok.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim henüz özet yayınlamadı.'**
  String get seffafVeriYok;

  /// No description provided for @seffafTaslakEki.
  ///
  /// In tr, this message translates to:
  /// **' • taslak'**
  String get seffafTaslakEki;

  /// No description provided for @seffafYayinla.
  ///
  /// In tr, this message translates to:
  /// **'Bu ayı yayınla'**
  String get seffafYayinla;

  /// No description provided for @seffafYayindaAlt.
  ///
  /// In tr, this message translates to:
  /// **'Sakinler bu özeti görüyor.'**
  String get seffafYayindaAlt;

  /// No description provided for @seffafOnizlemeAlt.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca yönetim görüyor (önizleme).'**
  String get seffafOnizlemeAlt;

  /// No description provided for @seffafOnizlemeUyari.
  ///
  /// In tr, this message translates to:
  /// **'Önizleme — henüz yayınlanmadı.'**
  String get seffafOnizlemeUyari;

  /// No description provided for @seffafOzetBaslik.
  ///
  /// In tr, this message translates to:
  /// **'{ay} — Özet'**
  String seffafOzetBaslik(Object ay);

  /// No description provided for @seffafToplamGelir.
  ///
  /// In tr, this message translates to:
  /// **'Toplam gelir'**
  String get seffafToplamGelir;

  /// No description provided for @seffafToplamGider.
  ///
  /// In tr, this message translates to:
  /// **'Toplam gider'**
  String get seffafToplamGider;

  /// No description provided for @seffafNet.
  ///
  /// In tr, this message translates to:
  /// **'Net'**
  String get seffafNet;

  /// No description provided for @seffafOncekiAyNet.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay net: {tutar}'**
  String seffafOncekiAyNet(Object tutar);

  /// No description provided for @seffafGiderDagilimi.
  ///
  /// In tr, this message translates to:
  /// **'Gider dağılımı'**
  String get seffafGiderDagilimi;

  /// No description provided for @seffafGiderYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay gider kaydı yok.'**
  String get seffafGiderYok;

  /// No description provided for @seffafAidatToplama.
  ///
  /// In tr, this message translates to:
  /// **'Aidat toplama'**
  String get seffafAidatToplama;

  /// No description provided for @seffafTahakkukYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay için tahakkuk yok.'**
  String get seffafTahakkukYok;

  /// Odeyen / toplam daire sayisi
  ///
  /// In tr, this message translates to:
  /// **'Ödeyen daire: {odeyen}/{toplam}'**
  String seffafOdeyenDaire(Object odeyen, Object toplam);

  /// Tahsilat/tahakkuk tutarlari + tutar orani (%)
  ///
  /// In tr, this message translates to:
  /// **'Tahsilat: {tahsilat} / {tahakkuk}  (tutar: %{yuzde})'**
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde);

  /// Geciken daire sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Gecikmede {n} daire'**
  String seffafGecikmede(num n);

  /// Yalin yuzde gosterimi; isaretin YERI dile gore degisir
  ///
  /// In tr, this message translates to:
  /// **'%{yuzde}'**
  String ortakYuzde(Object yuzde);

  /// No description provided for @entegYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get entegYeni;

  /// No description provided for @entegYokMesaj.
  ///
  /// In tr, this message translates to:
  /// **'Entegrasyon yok. \"Yeni\" ile bir dış sistem (megafon/akıllı ev/webhook) ekleyin.'**
  String get entegYokMesaj;

  /// No description provided for @entegSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Silinsin mi?'**
  String get entegSilOnay;

  /// No description provided for @entegSilGovde.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" entegrasyonu silinecek.'**
  String entegSilGovde(Object ad);

  /// No description provided for @entegSilinemedi.
  ///
  /// In tr, this message translates to:
  /// **'Silinemedi: {hata}'**
  String entegSilinemedi(Object hata);

  /// No description provided for @entegAktifKisa.
  ///
  /// In tr, this message translates to:
  /// **'aktif'**
  String get entegAktifKisa;

  /// No description provided for @entegPasifKisa.
  ///
  /// In tr, this message translates to:
  /// **'pasif'**
  String get entegPasifKisa;

  /// {kilit} istege bagli kilit simgesi (bos ya da ' 🔒')
  ///
  /// In tr, this message translates to:
  /// **'Kimlik: {tip}{kilit}'**
  String entegKimlikSatir(Object tip, Object kilit);

  /// No description provided for @entegTest.
  ///
  /// In tr, this message translates to:
  /// **'Test'**
  String get entegTest;

  /// No description provided for @entegTestBasarili.
  ///
  /// In tr, this message translates to:
  /// **'✓ Başarılı ({durum})'**
  String entegTestBasarili(Object durum);

  /// {durum} istege bagli HTTP durumu (' (500)' gibi)
  ///
  /// In tr, this message translates to:
  /// **'✗ {hata}{durum}'**
  String entegTestBasarisiz(Object hata, Object durum);

  /// No description provided for @entegBasarisiz.
  ///
  /// In tr, this message translates to:
  /// **'Başarısız'**
  String get entegBasarisiz;

  /// No description provided for @entegDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Entegrasyon düzenle'**
  String get entegDuzenleBaslik;

  /// No description provided for @entegYeniBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yeni entegrasyon'**
  String get entegYeniBaslik;

  /// No description provided for @entegPreset.
  ///
  /// In tr, this message translates to:
  /// **'Hazır şablon (preset)'**
  String get entegPreset;

  /// No description provided for @entegKanalTipi.
  ///
  /// In tr, this message translates to:
  /// **'Kanal tipi'**
  String get entegKanalTipi;

  /// No description provided for @entegUrl.
  ///
  /// In tr, this message translates to:
  /// **'Endpoint URL (http/https)'**
  String get entegUrl;

  /// No description provided for @entegUrlHelper.
  ///
  /// In tr, this message translates to:
  /// **'İç/özel adresler tetikte engellenir'**
  String get entegUrlHelper;

  /// No description provided for @entegUrlHata.
  ///
  /// In tr, this message translates to:
  /// **'http(s) ile başlamalı'**
  String get entegUrlHata;

  /// No description provided for @entegHttpMetodu.
  ///
  /// In tr, this message translates to:
  /// **'HTTP metodu'**
  String get entegHttpMetodu;

  /// No description provided for @entegKimlikDogrulama.
  ///
  /// In tr, this message translates to:
  /// **'Kimlik doğrulama'**
  String get entegKimlikDogrulama;

  /// No description provided for @entegSir.
  ///
  /// In tr, this message translates to:
  /// **'Sır (bearer token / API key)'**
  String get entegSir;

  /// No description provided for @entegSirKayitli.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı — değiştirmek için yeni değer girin'**
  String get entegSirKayitli;

  /// No description provided for @entegSirYazmaOzel.
  ///
  /// In tr, this message translates to:
  /// **'Yazma-özel; sunucudan asla dönmez'**
  String get entegSirYazmaOzel;

  /// No description provided for @entegPayload.
  ///
  /// In tr, this message translates to:
  /// **'Payload şablonu'**
  String get entegPayload;

  /// {sablonlar} teknik yer tutucular — CEVRILMEZ
  ///
  /// In tr, this message translates to:
  /// **'{sablonlar} yer tutucuları'**
  String entegPayloadHelper(Object sablonlar);

  /// No description provided for @entegTestMesaji.
  ///
  /// In tr, this message translates to:
  /// **'Test mesajı'**
  String get entegTestMesaji;

  /// No description provided for @ortakAdGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Ad gerekli'**
  String get ortakAdGerekli;

  /// No description provided for @ziyaretYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ziyaretçi'**
  String get ziyaretYeni;

  /// No description provided for @ziyaretKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi kaydedildi — daire sakinine bildirildi ✓'**
  String get ziyaretKaydedildi;

  /// No description provided for @ziyaretYokGuvenlik.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ziyaretçi kaydı yok.'**
  String get ziyaretYokGuvenlik;

  /// No description provided for @ziyaretYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Size iletilen ziyaretçi kaydı yok.'**
  String get ziyaretYokSakin;

  /// No description provided for @ziyaretBildirilenSakin.
  ///
  /// In tr, this message translates to:
  /// **'Bildirilen sakin: {ad}'**
  String ziyaretBildirilenSakin(Object ad);

  /// No description provided for @ziyaretSakiniAra.
  ///
  /// In tr, this message translates to:
  /// **'Sakini ara'**
  String get ziyaretSakiniAra;

  /// No description provided for @ziyaretGuvenligiAra.
  ///
  /// In tr, this message translates to:
  /// **'Güvenliği ara'**
  String get ziyaretGuvenligiAra;

  /// No description provided for @ziyaretBilgileriDuzenle.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileri düzenle'**
  String get ziyaretBilgileriDuzenle;

  /// No description provided for @ziyaretGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi bilgileri güncellendi ✓'**
  String get ziyaretGuncellendi;

  /// No description provided for @ziyaretOnceDaireNo.
  ///
  /// In tr, this message translates to:
  /// **'Önce daire no girin'**
  String get ziyaretOnceDaireNo;

  /// No description provided for @ziyaretSakiniSecin.
  ///
  /// In tr, this message translates to:
  /// **'Bildirilecek sakini seçin'**
  String get ziyaretSakiniSecin;

  /// No description provided for @ziyaretDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi düzenle'**
  String get ziyaretDuzenleBaslik;

  /// No description provided for @ziyaretDuzenleAlt.
  ///
  /// In tr, this message translates to:
  /// **'Ad, daire, bildirilen sakin ve notu güncelleyebilirsiniz.'**
  String get ziyaretDuzenleAlt;

  /// No description provided for @ziyaretYeniAlt.
  ///
  /// In tr, this message translates to:
  /// **'Sakine yalnızca bilgilendirme gider (onay istenmez).'**
  String get ziyaretYeniAlt;

  /// No description provided for @ziyaretAdAlan.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi adı *'**
  String get ziyaretAdAlan;

  /// No description provided for @ziyaretAdGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi adı gerekli'**
  String get ziyaretAdGerekli;

  /// No description provided for @ziyaretSakinleriGetir.
  ///
  /// In tr, this message translates to:
  /// **'Sakinleri getir'**
  String get ziyaretSakinleriGetir;

  /// No description provided for @ziyaretBildirilecekSakin.
  ///
  /// In tr, this message translates to:
  /// **'Bildirilecek sakin *'**
  String get ziyaretBildirilecekSakin;

  /// No description provided for @ziyaretKaydetVeBildir.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet ve sakine bildir'**
  String get ziyaretKaydetVeBildir;

  /// No description provided for @raporBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Aylık raporlar'**
  String get raporBaslik;

  /// No description provided for @raporOncekiAy.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get raporOncekiAy;

  /// No description provided for @raporSonrakiAy.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get raporSonrakiAy;

  /// Ay adi + yil ('Temmuz 2026')
  ///
  /// In tr, this message translates to:
  /// **'{ay} {yil}'**
  String raporAyBaslik(Object ay, Object yil);

  /// No description provided for @raporYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Aylık raporlar için yetkiniz yok. Bu ekran yönetici rolüne açıktır.'**
  String get raporYetkiYok;

  /// No description provided for @raporGorevTamamlama.
  ///
  /// In tr, this message translates to:
  /// **'Görev tamamlama'**
  String get raporGorevTamamlama;

  /// No description provided for @raporAidat.
  ///
  /// In tr, this message translates to:
  /// **'Aidat'**
  String get raporAidat;

  /// No description provided for @raporSonTamamlamalar.
  ///
  /// In tr, this message translates to:
  /// **'Son tamamlamalar (ilk 10)'**
  String get raporSonTamamlamalar;

  /// No description provided for @raporPlanlananPencere.
  ///
  /// In tr, this message translates to:
  /// **'Planlanan pencere'**
  String get raporPlanlananPencere;

  /// No description provided for @raporTamamlanmaYuzde.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlanma %{yuzde}'**
  String raporTamamlanmaYuzde(Object yuzde);

  /// No description provided for @raporPencereYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay planlanmış devriye penceresi yok.'**
  String get raporPencereYok;

  /// No description provided for @raporGorevYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay görev tamamlaması yok.'**
  String get raporGorevYok;

  /// No description provided for @raporToplamTamamlama.
  ///
  /// In tr, this message translates to:
  /// **'Toplam tamamlama'**
  String get raporToplamTamamlama;

  /// No description provided for @raporAidatKayitYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem için tahakkuk/ödeme kaydı yok.'**
  String get raporAidatKayitYok;

  /// Daire sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Tahakkuk ({n} daire)'**
  String raporTahakkukDaire(num n);

  /// Odeme sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Tahsilat ({n} ödeme)'**
  String raporTahsilatOdeme(num n);

  /// No description provided for @raporKalanBakiye.
  ///
  /// In tr, this message translates to:
  /// **'Kalan bakiye'**
  String get raporKalanBakiye;

  /// No description provided for @aidatBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Aidatım'**
  String get aidatBaslik;

  /// No description provided for @aidatYetkiYok.
  ///
  /// In tr, this message translates to:
  /// **'Aidat bilgisi yalnızca site sakini hesabına açıktır.'**
  String get aidatYetkiYok;

  /// No description provided for @aidatDaireYok.
  ///
  /// In tr, this message translates to:
  /// **'Üzerinize kayıtlı daire bulunamadı. Yönetiminizle iletişime geçin.'**
  String get aidatDaireYok;

  /// No description provided for @aidatToplamBakiye.
  ///
  /// In tr, this message translates to:
  /// **'Toplam bakiye (tüm daireler)'**
  String get aidatToplamBakiye;

  /// No description provided for @aidatBorcVar.
  ///
  /// In tr, this message translates to:
  /// **'Borç var'**
  String get aidatBorcVar;

  /// No description provided for @aidatBorcYok.
  ///
  /// In tr, this message translates to:
  /// **'Borç yok'**
  String get aidatBorcYok;

  /// No description provided for @aidatToplamTahakkuk.
  ///
  /// In tr, this message translates to:
  /// **'Toplam tahakkuk'**
  String get aidatToplamTahakkuk;

  /// No description provided for @aidatToplamOdenen.
  ///
  /// In tr, this message translates to:
  /// **'Toplam ödenen'**
  String get aidatToplamOdenen;

  /// No description provided for @aidatBakiye.
  ///
  /// In tr, this message translates to:
  /// **'Bakiye'**
  String get aidatBakiye;

  /// Seffaf hesap: tahakkuk - odenen = bakiye
  ///
  /// In tr, this message translates to:
  /// **'Tahakkuk {tahakkuk} - ödenen {odenen} = {bakiye}'**
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye);

  /// Tahakkuk sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Tahakkuklar ({n})'**
  String aidatTahakkuklar(num n);

  /// Odeme sayaci (ICU cogul)
  ///
  /// In tr, this message translates to:
  /// **'Ödemeler ({n})'**
  String aidatOdemeler(num n);

  /// No description provided for @aidatSonOdeme.
  ///
  /// In tr, this message translates to:
  /// **'Son ödeme: {tarih}'**
  String aidatSonOdeme(Object tarih);

  /// No description provided for @aidatMakbuz.
  ///
  /// In tr, this message translates to:
  /// **'Makbuz: {no}'**
  String aidatMakbuz(Object no);

  /// No description provided for @aidatOdemeDurumuNotu.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme durumu yalnızca ödeme sağlayıcısından gelen onayla güncellenir; sorularınız için yönetiminize başvurun.'**
  String get aidatOdemeDurumuNotu;

  /// No description provided for @aidatYontemElden.
  ///
  /// In tr, this message translates to:
  /// **'Elden'**
  String get aidatYontemElden;

  /// No description provided for @aidatYontemHavale.
  ///
  /// In tr, this message translates to:
  /// **'Havale/EFT'**
  String get aidatYontemHavale;

  /// No description provided for @aidatYontemKart.
  ///
  /// In tr, this message translates to:
  /// **'Kart'**
  String get aidatYontemKart;

  /// No description provided for @aidatYontemDiger.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get aidatYontemDiger;

  /// No description provided for @aidatDurumBasarili.
  ///
  /// In tr, this message translates to:
  /// **'Başarılı'**
  String get aidatDurumBasarili;

  /// No description provided for @aidatDurumIptal.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get aidatDurumIptal;

  /// No description provided for @noktaBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol Noktaları'**
  String get noktaBaslik;

  /// No description provided for @noktaEkle.
  ///
  /// In tr, this message translates to:
  /// **'Nokta ekle'**
  String get noktaEkle;

  /// No description provided for @noktaListelenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Noktalar listelenemedi.'**
  String get noktaListelenemedi;

  /// No description provided for @noktaSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Nokta silinsin mi?'**
  String get noktaSilOnay;

  /// No description provided for @noktaSilGovde.
  ///
  /// In tr, this message translates to:
  /// **'\"{ad}\" kontrol noktası silinecek.'**
  String noktaSilGovde(Object ad);

  /// No description provided for @noktaSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Nokta silindi ✓'**
  String get noktaSilindi;

  /// No description provided for @noktaUidZatenVar.
  ///
  /// In tr, this message translates to:
  /// **'Bu NFC etiketi zaten kayıtlı.'**
  String get noktaUidZatenVar;

  /// No description provided for @noktaDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Nokta düzenle'**
  String get noktaDuzenleBaslik;

  /// No description provided for @noktaYeniBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kontrol noktası'**
  String get noktaYeniBaslik;

  /// No description provided for @noktaAdIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. Giriş Kapısı'**
  String get noktaAdIpucu;

  /// No description provided for @noktaUidAlan.
  ///
  /// In tr, this message translates to:
  /// **'NFC etiket UID'**
  String get noktaUidAlan;

  /// No description provided for @noktaUidIpucu.
  ///
  /// In tr, this message translates to:
  /// **'örn. 04A2B3C4D5'**
  String get noktaUidIpucu;

  /// No description provided for @noktaUidHelper.
  ///
  /// In tr, this message translates to:
  /// **'Etiketin benzersiz kimliği (hex).'**
  String get noktaUidHelper;

  /// No description provided for @noktaEnlem.
  ///
  /// In tr, this message translates to:
  /// **'Enlem (ops.)'**
  String get noktaEnlem;

  /// No description provided for @noktaKonumGecersiz.
  ///
  /// In tr, this message translates to:
  /// **'Konum geçersiz. Örnek: 41,0082'**
  String get noktaKonumGecersiz;

  /// No description provided for @ortakSecenekYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Bazı seçenekler yüklenemedi — liste eksik olabilir.'**
  String get ortakSecenekYuklenemedi;

  /// No description provided for @noktaBoylam.
  ///
  /// In tr, this message translates to:
  /// **'Boylam (ops.)'**
  String get noktaBoylam;

  /// No description provided for @noktaPasifAlt.
  ///
  /// In tr, this message translates to:
  /// **'Pasif nokta okutmada eşleşmez'**
  String get noktaPasifAlt;

  /// No description provided for @noktaYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kontrol noktası yok.'**
  String get noktaYok;

  /// No description provided for @kuyrukHatalariTemizle.
  ///
  /// In tr, this message translates to:
  /// **'Kalıcı hataları temizle'**
  String get kuyrukHatalariTemizle;

  /// No description provided for @kuyrukBos.
  ///
  /// In tr, this message translates to:
  /// **'Kuyruk boş.'**
  String get kuyrukBos;

  /// Bekleyen + kalici hatali kayit sayilari
  ///
  /// In tr, this message translates to:
  /// **'{bekleyen} bekliyor · {hatali} kalıcı hata'**
  String kuyrukOzet(Object bekleyen, Object hatali);

  /// No description provided for @kuyrukSenkronla.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi senkronla'**
  String get kuyrukSenkronla;

  /// No description provided for @kuyrukBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get kuyrukBekliyor;

  /// No description provided for @kuyrukBekliyorDeneme.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor (deneme: {n})'**
  String kuyrukBekliyorDeneme(Object n);

  /// No description provided for @kuyrukGonderiliyor.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor...'**
  String get kuyrukGonderiliyor;

  /// No description provided for @kuyrukGonderildiZatenVar.
  ///
  /// In tr, this message translates to:
  /// **'Gönderildi (zaten kayıtlıydı)'**
  String get kuyrukGonderildiZatenVar;

  /// No description provided for @kuyrukGonderildiYeni.
  ///
  /// In tr, this message translates to:
  /// **'Gönderildi (yeni kayıt)'**
  String get kuyrukGonderildiYeni;

  /// {hata} sunucu metni ya da kimlikten cozulen metin
  ///
  /// In tr, this message translates to:
  /// **'Kalıcı hata: {hata}'**
  String kuyrukKaliciHata(Object hata);

  /// No description provided for @kuyrukEtiketEslesmedi.
  ///
  /// In tr, this message translates to:
  /// **'etiket eşleşmedi'**
  String get kuyrukEtiketEslesmedi;

  /// No description provided for @okutmaImzaGecersiz.
  ///
  /// In tr, this message translates to:
  /// **'Etiket imzası doğrulanamadı — sahte veya yanlış etiket olabilir.'**
  String get okutmaImzaGecersiz;

  /// No description provided for @okutmaTekrarEdilmis.
  ///
  /// In tr, this message translates to:
  /// **'Bu okutma daha önce işlendi.'**
  String get okutmaTekrarEdilmis;

  /// {detay} teknik istisna metni — cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'Beklenmeyen hata: {detay}'**
  String okutmaBeklenmeyenHata(Object detay);

  /// No description provided for @noktaUidZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'NFC UID zorunludur'**
  String get noktaUidZorunlu;

  /// No description provided for @hataZamanAsimi.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya bağlanırken zaman aşımı oluştu.'**
  String get hataZamanAsimi;

  /// No description provided for @hataSunucuyaUlasilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılamadı. Ağ bağlantınızı ve sunucu adresini kontrol edin.'**
  String get hataSunucuyaUlasilamadi;

  /// No description provided for @destekBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Destek'**
  String get destekBaslik;

  /// No description provided for @destekYeniTalep.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Talep'**
  String get destekYeniTalep;

  /// No description provided for @destekTalepYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz destek talebiniz yok'**
  String get destekTalepYok;

  /// {hata} teknik istisna metni — cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'Talepler yüklenemedi.\n{hata}'**
  String destekYuklenemedi(Object hata);

  /// No description provided for @destekGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Talep gönderilemedi: {hata}'**
  String destekGonderilemedi(Object hata);

  /// No description provided for @destekYeniTalepBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Destek Talebi'**
  String get destekYeniTalepBaslik;

  /// No description provided for @destekKonu.
  ///
  /// In tr, this message translates to:
  /// **'Konu'**
  String get destekKonu;

  /// No description provided for @destekGorselEkle.
  ///
  /// In tr, this message translates to:
  /// **'Görsel ekle'**
  String get destekGorselEkle;

  /// No description provided for @destekGorseliDegistir.
  ///
  /// In tr, this message translates to:
  /// **'Görseli değiştir'**
  String get destekGorseliDegistir;

  /// No description provided for @destekEkip.
  ///
  /// In tr, this message translates to:
  /// **'Yönetiyor Ekibi'**
  String get destekEkip;

  /// No description provided for @tesisKurulumBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesisinizi tanımlayın'**
  String get tesisKurulumBaslik;

  /// No description provided for @tesisKurulumAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici olarak ilk girişinizi yaptınız. Devam etmek için sitenizin/tesisinizin adını girin. Bu adı daha sonra ayarlardan değiştirebilirsiniz.'**
  String get tesisKurulumAciklama;

  /// No description provided for @tesisAdiIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Örnek Sitesi'**
  String get tesisAdiIpucu;

  /// No description provided for @tesisAdiKisa.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adı en az 2 karakter olmalı'**
  String get tesisAdiKisa;

  /// No description provided for @tesisOlustur.
  ///
  /// In tr, this message translates to:
  /// **'Tesisi oluştur'**
  String get tesisOlustur;

  /// No description provided for @tesisAdiGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adı güncellendi'**
  String get tesisAdiGuncellendi;

  /// No description provided for @tesisAdiAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Ana ekranın başlığında görünür; tüm kullanıcılar bu adı görür.'**
  String get tesisAdiAciklama;

  /// No description provided for @sikayetYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Henüz şikayet açmadınız.\nŞikayet Haritası’ndan bir daire seçip şikayet edebilirsiniz.'**
  String get sikayetYokSakin;

  /// Daire no + kategori adi
  ///
  /// In tr, this message translates to:
  /// **'Daire {daire} · {kategori}'**
  String sikayetSatirBaslik(Object daire, Object kategori);

  /// No description provided for @sikayetDurumKapandi.
  ///
  /// In tr, this message translates to:
  /// **'Kapandı'**
  String get sikayetDurumKapandi;

  /// No description provided for @vardiyaBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Vardiyalar'**
  String get vardiyaBaslik;

  /// No description provided for @vardiyaYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Vardiyalar yüklenemedi.'**
  String get vardiyaYuklenemedi;

  /// No description provided for @vardiyaTanimYok.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya tanımı yok'**
  String get vardiyaTanimYok;

  /// Baslangic-bitis saati + gun tipi etiketi
  ///
  /// In tr, this message translates to:
  /// **'{baslangic} - {bitis} • {gunTipi}'**
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi);

  /// No description provided for @vardiyaPersonelAta.
  ///
  /// In tr, this message translates to:
  /// **'Personel Ata'**
  String get vardiyaPersonelAta;

  /// No description provided for @vardiyaPersonelBaslik.
  ///
  /// In tr, this message translates to:
  /// **'{ad} — Personel'**
  String vardiyaPersonelBaslik(Object ad);

  /// No description provided for @vardiyaPersonelGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya personeli güncellendi ✓'**
  String get vardiyaPersonelGuncellendi;

  /// No description provided for @vardiyaPersonelYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Personel yüklenemedi.'**
  String get vardiyaPersonelYuklenemedi;

  /// No description provided for @vardiyaAtanabilirYok.
  ///
  /// In tr, this message translates to:
  /// **'Atanabilir personel yok'**
  String get vardiyaAtanabilirYok;

  /// No description provided for @gunTipiHaftaIci.
  ///
  /// In tr, this message translates to:
  /// **'Hafta içi'**
  String get gunTipiHaftaIci;

  /// No description provided for @gunTipiHaftaSonu.
  ///
  /// In tr, this message translates to:
  /// **'Hafta sonu'**
  String get gunTipiHaftaSonu;

  /// No description provided for @gunTipiResmiTatil.
  ///
  /// In tr, this message translates to:
  /// **'Resmî tatil'**
  String get gunTipiResmiTatil;

  /// No description provided for @gunTipiHerGun.
  ///
  /// In tr, this message translates to:
  /// **'Her gün'**
  String get gunTipiHerGun;

  /// No description provided for @yonIletisimBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici İletişim'**
  String get yonIletisimBaslik;

  /// No description provided for @yonIletisimAlinamadi.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici bilgileri alınamadı.'**
  String get yonIletisimAlinamadi;

  /// No description provided for @yonIletisimTanimliDegil.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici iletişim bilgisi tanımlı değil.'**
  String get yonIletisimTanimliDegil;

  /// No description provided for @yonIletisimMail.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim maili'**
  String get yonIletisimMail;

  /// No description provided for @yonIletisimAra.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticiyi Ara'**
  String get yonIletisimAra;

  /// No description provided for @aramaBaslatilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Arama başlatılamadı'**
  String get aramaBaslatilamadi;

  /// No description provided for @aramaYapilamiyor.
  ///
  /// In tr, this message translates to:
  /// **'Aranamıyor'**
  String get aramaYapilamiyor;

  /// No description provided for @bildirimYok.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim yok'**
  String get bildirimYok;

  /// {hata} teknik istisna metni — cevrilmez
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler yüklenemedi.\n{hata}'**
  String bildirimYuklenemedi(Object hata);

  /// No description provided for @bildirimYeniPush.
  ///
  /// In tr, this message translates to:
  /// **'Yeni bildirim'**
  String get bildirimYeniPush;

  /// No description provided for @akisDevriyeOkutma.
  ///
  /// In tr, this message translates to:
  /// **'Devriye Okutması'**
  String get akisDevriyeOkutma;

  /// No description provided for @akisGorevTamamlandi.
  ///
  /// In tr, this message translates to:
  /// **'Görev Tamamlandı'**
  String get akisGorevTamamlandi;

  /// No description provided for @akisAidatOdemesi.
  ///
  /// In tr, this message translates to:
  /// **'Aidat Ödemesi'**
  String get akisAidatOdemesi;

  /// No description provided for @akisTalepAcildi.
  ///
  /// In tr, this message translates to:
  /// **'Talep Açıldı'**
  String get akisTalepAcildi;

  /// No description provided for @akisTalepIsEmri.
  ///
  /// In tr, this message translates to:
  /// **'Talep İş Emrine Dönüştü'**
  String get akisTalepIsEmri;

  /// No description provided for @akisTalepCozuldu.
  ///
  /// In tr, this message translates to:
  /// **'Talep Çözüldü'**
  String get akisTalepCozuldu;

  /// No description provided for @akisTalepReddedildi.
  ///
  /// In tr, this message translates to:
  /// **'Talep Reddedildi'**
  String get akisTalepReddedildi;

  /// No description provided for @akisDaireSikayeti.
  ///
  /// In tr, this message translates to:
  /// **'Daire Şikayeti'**
  String get akisDaireSikayeti;

  /// No description provided for @akisAlarmKacirilanTur.
  ///
  /// In tr, this message translates to:
  /// **'Kaçırılan Tur'**
  String get akisAlarmKacirilanTur;

  /// No description provided for @akisAlarmEksikCheckpoint.
  ///
  /// In tr, this message translates to:
  /// **'Eksik Kontrol Noktası'**
  String get akisAlarmEksikCheckpoint;

  /// No description provided for @akisAlarmGecikmisOkutma.
  ///
  /// In tr, this message translates to:
  /// **'Gecikmiş Okutma'**
  String get akisAlarmGecikmisOkutma;

  /// No description provided for @akisZiyaretciGirisi.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi Girişi'**
  String get akisZiyaretciGirisi;

  /// No description provided for @akisZiyaretciCikisi.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi Çıkışı'**
  String get akisZiyaretciCikisi;

  /// No description provided for @akisKargoKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Kargo Kaydedildi'**
  String get akisKargoKaydedildi;

  /// No description provided for @akisKargoTeslimEdildi.
  ///
  /// In tr, this message translates to:
  /// **'Kargo Teslim Edildi'**
  String get akisKargoTeslimEdildi;

  /// No description provided for @akisAracGirisi.
  ///
  /// In tr, this message translates to:
  /// **'Araç Girişi'**
  String get akisAracGirisi;

  /// No description provided for @akisAracCikisi.
  ///
  /// In tr, this message translates to:
  /// **'Araç Çıkışı'**
  String get akisAracCikisi;

  /// No description provided for @akisIhlalKaydi.
  ///
  /// In tr, this message translates to:
  /// **'İhlal Kaydı'**
  String get akisIhlalKaydi;

  /// No description provided for @akisAltDaireTutar.
  ///
  /// In tr, this message translates to:
  /// **'Daire {daire} — {tutar}'**
  String akisAltDaireTutar(Object daire, Object tutar);

  /// No description provided for @akisAltDaireKategori.
  ///
  /// In tr, this message translates to:
  /// **'Daire {daire} — {kategori}'**
  String akisAltDaireKategori(Object daire, Object kategori);

  /// No description provided for @akisAltAdDaire.
  ///
  /// In tr, this message translates to:
  /// **'{ad} — Daire {daire}'**
  String akisAltAdDaire(Object ad, Object daire);

  /// No description provided for @akisAltPlakaDaire.
  ///
  /// In tr, this message translates to:
  /// **'{plaka} — Daire {daire}'**
  String akisAltPlakaDaire(Object plaka, Object daire);

  /// No description provided for @akisAltPlakaTanim.
  ///
  /// In tr, this message translates to:
  /// **'{plaka} ({tanim})'**
  String akisAltPlakaTanim(Object plaka, Object tanim);

  /// No description provided for @akisAltPlakaDaireTanim.
  ///
  /// In tr, this message translates to:
  /// **'{plaka} — Daire {daire} ({tanim})'**
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim);

  /// No description provided for @akisAltMetinKonum.
  ///
  /// In tr, this message translates to:
  /// **'{metin} — {konum}'**
  String akisAltMetinKonum(Object metin, Object konum);

  /// No description provided for @akisAltPlanAralik.
  ///
  /// In tr, this message translates to:
  /// **'{plan} · {aralik}'**
  String akisAltPlanAralik(Object plan, Object aralik);

  /// No description provided for @ortakParolayiGoster.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı göster'**
  String get ortakParolayiGoster;

  /// No description provided for @ortakParolayiGizle.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı gizle'**
  String get ortakParolayiGizle;

  /// No description provided for @ortakFotograf.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get ortakFotograf;

  /// No description provided for @ortakFotografiBuyut.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı büyüt'**
  String get ortakFotografiBuyut;

  /// No description provided for @ortakGoster.
  ///
  /// In tr, this message translates to:
  /// **'Göster'**
  String get ortakGoster;

  /// No description provided for @talepRedBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Talebi reddet'**
  String get talepRedBaslik;

  /// No description provided for @ziyaretciDaireSakinYok.
  ///
  /// In tr, this message translates to:
  /// **'Bu dairede aktif sakin yok'**
  String get ziyaretciDaireSakinYok;

  /// No description provided for @ceviriOtomatik.
  ///
  /// In tr, this message translates to:
  /// **'Bu içerik otomatik çevrilmiştir'**
  String get ceviriOtomatik;

  /// No description provided for @ceviriOtomatikKisa.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik çeviri'**
  String get ceviriOtomatikKisa;

  /// No description provided for @ceviriOrijinaliGor.
  ///
  /// In tr, this message translates to:
  /// **'Orijinali gör'**
  String get ceviriOrijinaliGor;

  /// No description provided for @ceviriCeviriyiGor.
  ///
  /// In tr, this message translates to:
  /// **'Çeviriyi gör'**
  String get ceviriCeviriyiGor;

  /// No description provided for @ceviriHazirlaniyor.
  ///
  /// In tr, this message translates to:
  /// **'Çeviri hazırlanıyor — orijinal gösteriliyor'**
  String get ceviriHazirlaniyor;

  /// No description provided for @ceviriHazirlaniyorKisa.
  ///
  /// In tr, this message translates to:
  /// **'Çeviri hazırlanıyor'**
  String get ceviriHazirlaniyorKisa;

  /// No description provided for @ceviriYapilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Çeviri yapılamadı — orijinal gösteriliyor'**
  String get ceviriYapilamadi;

  /// No description provided for @ceviriYapilamadiKisa.
  ///
  /// In tr, this message translates to:
  /// **'Çeviri yapılamadı'**
  String get ceviriYapilamadiKisa;

  /// No description provided for @modulAracGecis.
  ///
  /// In tr, this message translates to:
  /// **'Araç Geçişleri'**
  String get modulAracGecis;

  /// Ana ekran karosu — agregat otopark doluluk
  ///
  /// In tr, this message translates to:
  /// **'Otopark'**
  String get modulOtopark;

  /// Ana ekran karosu — arac/park ihlalleri
  ///
  /// In tr, this message translates to:
  /// **'İhlaller'**
  String get modulIhlaller;

  /// No description provided for @aracSuzgecTumu.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get aracSuzgecTumu;

  /// No description provided for @aracSuzgecIceride.
  ///
  /// In tr, this message translates to:
  /// **'İçeride'**
  String get aracSuzgecIceride;

  /// No description provided for @aracSuzgecCikmis.
  ///
  /// In tr, this message translates to:
  /// **'Çıkmış'**
  String get aracSuzgecCikmis;

  /// No description provided for @aracPlakaAra.
  ///
  /// In tr, this message translates to:
  /// **'Plaka ara'**
  String get aracPlakaAra;

  /// No description provided for @aracListeBos.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı araç geçişi yok'**
  String get aracListeBos;

  /// No description provided for @aracAramaBos.
  ///
  /// In tr, this message translates to:
  /// **'Bu plakayla eşleşen geçiş yok'**
  String get aracAramaBos;

  /// No description provided for @aracRozetIceride.
  ///
  /// In tr, this message translates to:
  /// **'İçeride'**
  String get aracRozetIceride;

  /// No description provided for @aracRozetCikti.
  ///
  /// In tr, this message translates to:
  /// **'Çıktı'**
  String get aracRozetCikti;

  /// No description provided for @aracRozetZiyaretci.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi'**
  String get aracRozetZiyaretci;

  /// No description provided for @aracGirisZamani.
  ///
  /// In tr, this message translates to:
  /// **'Giriş: {zaman}'**
  String aracGirisZamani(Object zaman);

  /// No description provided for @aracCikisZamani.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış: {zaman}'**
  String aracCikisZamani(Object zaman);

  /// No description provided for @aracDaire.
  ///
  /// In tr, this message translates to:
  /// **'Daire {no}'**
  String aracDaire(Object no);

  /// No description provided for @aracCikisVer.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış ver'**
  String get aracCikisVer;

  /// No description provided for @aracCikisOnayBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış verilsin mi?'**
  String get aracCikisOnayBaslik;

  /// No description provided for @aracCikisVerildi.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış kaydedildi'**
  String get aracCikisVerildi;

  /// No description provided for @aracZatenKapali.
  ///
  /// In tr, this message translates to:
  /// **'Bu geçiş zaten kapatılmış'**
  String get aracZatenKapali;

  /// No description provided for @aracYeniGiris.
  ///
  /// In tr, this message translates to:
  /// **'Yeni giriş'**
  String get aracYeniGiris;

  /// No description provided for @aracGirisKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Araç girişi kaydedildi'**
  String get aracGirisKaydedildi;

  /// No description provided for @aracPlaka.
  ///
  /// In tr, this message translates to:
  /// **'Plaka'**
  String get aracPlaka;

  /// No description provided for @aracPlakaZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Plaka zorunlu'**
  String get aracPlakaZorunlu;

  /// No description provided for @aracTanimAlani.
  ///
  /// In tr, this message translates to:
  /// **'Araç tanımı (isteğe bağlı)'**
  String get aracTanimAlani;

  /// No description provided for @aracDaireAlani.
  ///
  /// In tr, this message translates to:
  /// **'Daire no (isteğe bağlı)'**
  String get aracDaireAlani;

  /// No description provided for @aracZiyaretciMi.
  ///
  /// In tr, this message translates to:
  /// **'Ziyaretçi aracı'**
  String get aracZiyaretciMi;

  /// No description provided for @aracZatenIceride.
  ///
  /// In tr, this message translates to:
  /// **'Bu plakanın açık geçişi zaten var (araç içeride)'**
  String get aracZatenIceride;

  /// No description provided for @aracErisimYok.
  ///
  /// In tr, this message translates to:
  /// **'Araç geçiş listesi yalnız yönetim ve güvenlik içindir'**
  String get aracErisimYok;

  /// No description provided for @aracKaydeden.
  ///
  /// In tr, this message translates to:
  /// **'Kaydeden: {ad}'**
  String aracKaydeden(Object ad);

  /// No description provided for @otoparkDoluEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Dolu'**
  String get otoparkDoluEtiket;

  /// No description provided for @otoparkBosEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get otoparkBosEtiket;

  /// No description provided for @otoparkKapasiteEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Kapasite'**
  String get otoparkKapasiteEtiket;

  /// No description provided for @otoparkKapasiteTanimsiz.
  ///
  /// In tr, this message translates to:
  /// **'Kapasite tanımlı değil — yalnız içerideki araç sayısı gösterilir'**
  String get otoparkKapasiteTanimsiz;

  /// No description provided for @otoparkAracListesi.
  ///
  /// In tr, this message translates to:
  /// **'Araç geçişlerini aç'**
  String get otoparkAracListesi;

  /// No description provided for @ihlalDurumYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get ihlalDurumYeni;

  /// No description provided for @ihlalDurumInceleniyor.
  ///
  /// In tr, this message translates to:
  /// **'İnceleniyor'**
  String get ihlalDurumInceleniyor;

  /// No description provided for @ihlalDurumKapatildi.
  ///
  /// In tr, this message translates to:
  /// **'Kapatıldı'**
  String get ihlalDurumKapatildi;

  /// No description provided for @ihlalKaynakKamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get ihlalKaynakKamera;

  /// No description provided for @ihlalKaynakManuel.
  ///
  /// In tr, this message translates to:
  /// **'Manuel'**
  String get ihlalKaynakManuel;

  /// No description provided for @ihlalKaynakDevriye.
  ///
  /// In tr, this message translates to:
  /// **'Devriye'**
  String get ihlalKaynakDevriye;

  /// No description provided for @ihlalListeBos.
  ///
  /// In tr, this message translates to:
  /// **'İhlal kaydı yok'**
  String get ihlalListeBos;

  /// No description provided for @ihlalYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ihlal'**
  String get ihlalYeni;

  /// No description provided for @ihlalAcildi.
  ///
  /// In tr, this message translates to:
  /// **'İhlal kaydı açıldı'**
  String get ihlalAcildi;

  /// No description provided for @ihlalBaslikAlani.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get ihlalBaslikAlani;

  /// No description provided for @ihlalBaslikZorunlu.
  ///
  /// In tr, this message translates to:
  /// **'Başlık zorunlu'**
  String get ihlalBaslikZorunlu;

  /// No description provided for @ihlalAciklamaAlani.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (isteğe bağlı)'**
  String get ihlalAciklamaAlani;

  /// No description provided for @ihlalKonumAlani.
  ///
  /// In tr, this message translates to:
  /// **'Konum (isteğe bağlı)'**
  String get ihlalKonumAlani;

  /// No description provided for @ihlalKaynakAlani.
  ///
  /// In tr, this message translates to:
  /// **'Tespit kaynağı'**
  String get ihlalKaynakAlani;

  /// No description provided for @ihlalIncelemeyeAl.
  ///
  /// In tr, this message translates to:
  /// **'İncelemeye al'**
  String get ihlalIncelemeyeAl;

  /// No description provided for @ihlalKapat.
  ///
  /// In tr, this message translates to:
  /// **'Kaydı kapat'**
  String get ihlalKapat;

  /// No description provided for @ihlalDurumGuncellendi.
  ///
  /// In tr, this message translates to:
  /// **'İhlal durumu güncellendi'**
  String get ihlalDurumGuncellendi;

  /// No description provided for @ihlalKapatmaOnay.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt kapatılsın mı? Kapatılan ihlal yeniden açılamaz.'**
  String get ihlalKapatmaOnay;

  /// No description provided for @ihlalKapaliDegistirilemez.
  ///
  /// In tr, this message translates to:
  /// **'Kapatılmış ihlal yeniden açılamaz'**
  String get ihlalKapaliDegistirilemez;

  /// No description provided for @ihlalErisimYok.
  ///
  /// In tr, this message translates to:
  /// **'İhlal kayıtları yalnız yönetim ve güvenlik içindir'**
  String get ihlalErisimYok;

  /// No description provided for @ihlalKaydeden.
  ///
  /// In tr, this message translates to:
  /// **'Açan: {ad}'**
  String ihlalKaydeden(Object ad);

  /// No description provided for @kameraRestream.
  ///
  /// In tr, this message translates to:
  /// **'Restream adresi (isteğe bağlı)'**
  String get kameraRestream;

  /// No description provided for @kameraRestreamAlt.
  ///
  /// In tr, this message translates to:
  /// **'RTSP kamerayı oynatılabilir yapar. Frigate/go2rtc geçidinin HLS adresi.'**
  String get kameraRestreamAlt;

  /// No description provided for @kameraRestreamHata.
  ///
  /// In tr, this message translates to:
  /// **'Restream adresi http:// veya https:// ile başlamalı'**
  String get kameraRestreamHata;

  /// No description provided for @kameraRestreamRozet.
  ///
  /// In tr, this message translates to:
  /// **'Geçit üzerinden'**
  String get kameraRestreamRozet;

  /// No description provided for @modulPlakaOlaylari.
  ///
  /// In tr, this message translates to:
  /// **'Plaka Okumaları'**
  String get modulPlakaOlaylari;

  /// No description provided for @anprDurumIslendi.
  ///
  /// In tr, this message translates to:
  /// **'İşlendi'**
  String get anprDurumIslendi;

  /// No description provided for @anprDurumOnayBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get anprDurumOnayBekliyor;

  /// No description provided for @anprDurumYokSayildi.
  ///
  /// In tr, this message translates to:
  /// **'Yok sayıldı'**
  String get anprDurumYokSayildi;

  /// No description provided for @anprDurumHata.
  ///
  /// In tr, this message translates to:
  /// **'Hata'**
  String get anprDurumHata;

  /// No description provided for @anprYonGiris.
  ///
  /// In tr, this message translates to:
  /// **'Giriş'**
  String get anprYonGiris;

  /// No description provided for @anprYonCikis.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış'**
  String get anprYonCikis;

  /// No description provided for @anprYonBilinmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Yön bilinmiyor'**
  String get anprYonBilinmiyor;

  /// No description provided for @anprListeBos.
  ///
  /// In tr, this message translates to:
  /// **'Plaka okuma kaydı yok'**
  String get anprListeBos;

  /// No description provided for @anprErisimYok.
  ///
  /// In tr, this message translates to:
  /// **'Plaka okumaları yalnız yönetim ve güvenlik içindir'**
  String get anprErisimYok;

  /// No description provided for @anprGuven.
  ///
  /// In tr, this message translates to:
  /// **'Güven %{oran}'**
  String anprGuven(Object oran);

  /// No description provided for @anprOnayla.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get anprOnayla;

  /// No description provided for @anprReddet.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get anprReddet;

  /// No description provided for @anprOnayBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Okumayı onayla'**
  String get anprOnayBaslik;

  /// No description provided for @anprOnayAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Plaka yanlış okunduysa düzeltebilirsiniz. Onaylarsanız araç geçişi açılır/kapanır.'**
  String get anprOnayAciklama;

  /// No description provided for @anprKararUygulandi.
  ///
  /// In tr, this message translates to:
  /// **'Karar uygulandı'**
  String get anprKararUygulandi;

  /// No description provided for @anprOnayBeklemiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu okuma artık onay beklemiyor'**
  String get anprOnayBeklemiyor;

  /// No description provided for @anprNedenDusukGuven.
  ///
  /// In tr, this message translates to:
  /// **'Düşük güven'**
  String get anprNedenDusukGuven;

  /// No description provided for @anprNedenZatenIceride.
  ///
  /// In tr, this message translates to:
  /// **'Araç zaten içeride'**
  String get anprNedenZatenIceride;

  /// No description provided for @anprNedenAcikGecisYok.
  ///
  /// In tr, this message translates to:
  /// **'Açık geçiş yok'**
  String get anprNedenAcikGecisYok;

  /// No description provided for @anprNedenOtomatikCikisKapali.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik çıkış kapalı'**
  String get anprNedenOtomatikCikisKapali;

  /// No description provided for @anprNedenElleReddedildi.
  ///
  /// In tr, this message translates to:
  /// **'Elle reddedildi'**
  String get anprNedenElleReddedildi;

  /// No description provided for @anprNedenPlakaBicimi.
  ///
  /// In tr, this message translates to:
  /// **'Plaka okunamadı'**
  String get anprNedenPlakaBicimi;

  /// No description provided for @aracPlakaOkumalari.
  ///
  /// In tr, this message translates to:
  /// **'Plaka okumaları'**
  String get aracPlakaOkumalari;

  /// No description provided for @kategoriGoruntuKirliligi.
  ///
  /// In tr, this message translates to:
  /// **'Görüntü kirliliği'**
  String get kategoriGoruntuKirliligi;

  /// No description provided for @fabSikayetBildir.
  ///
  /// In tr, this message translates to:
  /// **'Komşu şikayeti bildir'**
  String get fabSikayetBildir;

  /// No description provided for @sakinRolTipi.
  ///
  /// In tr, this message translates to:
  /// **'İlişki tipi'**
  String get sakinRolTipi;

  /// No description provided for @sakinRolMalik.
  ///
  /// In tr, this message translates to:
  /// **'Kat maliki'**
  String get sakinRolMalik;

  /// No description provided for @sakinRolKiraci.
  ///
  /// In tr, this message translates to:
  /// **'Kiracı'**
  String get sakinRolKiraci;

  /// No description provided for @sakinRolDegisme.
  ///
  /// In tr, this message translates to:
  /// **'Değiştirme'**
  String get sakinRolDegisme;

  /// No description provided for @sakinRolAlt.
  ///
  /// In tr, this message translates to:
  /// **'Aidat kiracıya, yatırım gideri malike borçlandırılır.'**
  String get sakinRolAlt;

  /// No description provided for @sakinEposta.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get sakinEposta;

  /// No description provided for @sakinEpostaTemizle.
  ///
  /// In tr, this message translates to:
  /// **'E-postayı kaldır'**
  String get sakinEpostaTemizle;

  /// No description provided for @sakinRolBagYok.
  ///
  /// In tr, this message translates to:
  /// **'İlişki tipi için sakinin bir daireye bağlı olması gerekir'**
  String get sakinRolBagYok;

  /// No description provided for @sikayetKuyruguBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Şikayet Kuyruğu'**
  String get sikayetKuyruguBaslik;

  /// No description provided for @sikayetSekmeYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get sikayetSekmeYeni;

  /// No description provided for @sikayetSekmeTumu.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get sikayetSekmeTumu;

  /// No description provided for @sikayetOkunmamisYok.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış şikayet yok.'**
  String get sikayetOkunmamisYok;

  /// No description provided for @sikayetYokYonetim.
  ///
  /// In tr, this message translates to:
  /// **'Henüz şikayet yok.'**
  String get sikayetYokYonetim;

  /// No description provided for @sikayetOkunduIsaretle.
  ///
  /// In tr, this message translates to:
  /// **'Okundu işaretle'**
  String get sikayetOkunduIsaretle;

  /// No description provided for @sikayetOkunmamisRozet.
  ///
  /// In tr, this message translates to:
  /// **'{sayi} okunmamış şikayet'**
  String sikayetOkunmamisRozet(int sayi);

  /// No description provided for @kameraHataAdresBozuk.
  ///
  /// In tr, this message translates to:
  /// **'Yayın adresi geçersiz. Adreste boşluk ya da satır sonu kalmış olabilir.'**
  String get kameraHataAdresBozuk;

  /// No description provided for @kameraHataSemaDesteklenmiyor.
  ///
  /// In tr, this message translates to:
  /// **'Bu adres türü doğrudan oynatılamaz. Kamera için bir yeniden yayın (restream) adresi tanımlayın.'**
  String get kameraHataSemaDesteklenmiyor;

  /// No description provided for @kameraHataSifrelenmemis.
  ///
  /// In tr, this message translates to:
  /// **'Şifrelenmemiş (http) yayın cihaz tarafından engellendi. Kurumsal profil ya da VPN buna izin vermiyor olabilir.'**
  String get kameraHataSifrelenmemis;

  /// No description provided for @kameraUrlCokUzun.
  ///
  /// In tr, this message translates to:
  /// **'Yayın adresi çok uzun (en fazla {sinir} karakter).'**
  String kameraUrlCokUzun(int sinir);

  /// No description provided for @kameraUrlSifrelenmemisUyari.
  ///
  /// In tr, this message translates to:
  /// **'Bu adres şifrelenmemiş (http). Mümkünse https kullanın.'**
  String get kameraUrlSifrelenmemisUyari;

  /// No description provided for @modulDaireTanimlari.
  ///
  /// In tr, this message translates to:
  /// **'Daire Tipleri'**
  String get modulDaireTanimlari;

  /// No description provided for @daireTanimSekmeTipler.
  ///
  /// In tr, this message translates to:
  /// **'Tipler'**
  String get daireTanimSekmeTipler;

  /// No description provided for @daireTanimSekmeGruplar.
  ///
  /// In tr, this message translates to:
  /// **'Gruplar'**
  String get daireTanimSekmeGruplar;

  /// No description provided for @daireTanimAd.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get daireTanimAd;

  /// No description provided for @daireTanimAdIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Örn. 2+1, dubleks, Villa'**
  String get daireTanimAdIpucu;

  /// No description provided for @daireTanimVarsayilanAidat.
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan aidat'**
  String get daireTanimVarsayilanAidat;

  /// No description provided for @daireTanimAidatBos.
  ///
  /// In tr, this message translates to:
  /// **'Tanımsız'**
  String get daireTanimAidatBos;

  /// No description provided for @daireTanimAidatAlt.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakılırsa tanımsız kalır; 0 yazmak “muaf” demektir.'**
  String get daireTanimAidatAlt;

  /// No description provided for @daireTanimDaireSayisi.
  ///
  /// In tr, this message translates to:
  /// **'{sayi} daire'**
  String daireTanimDaireSayisi(int sayi);

  /// No description provided for @daireTanimSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'Bu tanım silinsin mi? Bağlı {sayi} daire SİLİNMEZ, yalnız sınıflandırması boşalır.'**
  String daireTanimSilOnay(int sayi);

  /// No description provided for @daireTanimSilindiEtki.
  ///
  /// In tr, this message translates to:
  /// **'Silindi. {sayi} dairenin sınıflandırması boşaldı.'**
  String daireTanimSilindiEtki(int sayi);

  /// No description provided for @daireTanimYok.
  ///
  /// In tr, this message translates to:
  /// **'Henüz tanım yok.'**
  String get daireTanimYok;

  /// No description provided for @daireTanimYeni.
  ///
  /// In tr, this message translates to:
  /// **'Yeni tanım'**
  String get daireTanimYeni;

  /// No description provided for @daireTipiSecici.
  ///
  /// In tr, this message translates to:
  /// **'Bağımsız bölüm tipi'**
  String get daireTipiSecici;

  /// No description provided for @daireGrubuSecici.
  ///
  /// In tr, this message translates to:
  /// **'Bağımsız bölüm grubu'**
  String get daireGrubuSecici;

  /// No description provided for @daireTanimSecilmedi.
  ///
  /// In tr, this message translates to:
  /// **'Seçilmedi'**
  String get daireTanimSecilmedi;

  /// No description provided for @odeBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Öde'**
  String get odeBaslik;

  /// No description provided for @odeBorcunuz.
  ///
  /// In tr, this message translates to:
  /// **'Ödenmemiş tutar'**
  String get odeBorcunuz;

  /// No description provided for @odeHavaleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Banka havalesi'**
  String get odeHavaleBaslik;

  /// No description provided for @odeHavaleAdim.
  ///
  /// In tr, this message translates to:
  /// **'IBAN’a havale yapın ve açıklamaya aşağıdaki kodu yazın. Kod olmadan ödemeniz eşleşmeyebilir.'**
  String get odeHavaleAdim;

  /// No description provided for @odeKodBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama kodunuz'**
  String get odeKodBaslik;

  /// No description provided for @odeKopyala.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get odeKopyala;

  /// No description provided for @odeKopyalandi.
  ///
  /// In tr, this message translates to:
  /// **'Kopyalandı'**
  String get odeKopyalandi;

  /// No description provided for @odeKartBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kartla öde'**
  String get odeKartBaslik;

  /// No description provided for @odeKartKapali.
  ///
  /// In tr, this message translates to:
  /// **'Kart ödemesi henüz açık değil. Şimdilik banka havalesi kullanabilirsiniz.'**
  String get odeKartKapali;

  /// No description provided for @odeHavaleKapali.
  ///
  /// In tr, this message translates to:
  /// **'Site henüz banka hesabı tanımlamamış. Yönetime başvurun.'**
  String get odeHavaleKapali;

  /// No description provided for @odeBorcYok.
  ///
  /// In tr, this message translates to:
  /// **'Ödenmemiş borcunuz yok.'**
  String get odeBorcYok;

  /// No description provided for @odeBasarili.
  ///
  /// In tr, this message translates to:
  /// **'Ödemeniz alındı.'**
  String get odeBasarili;

  /// No description provided for @nfcFotoGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Tura başlamak için fotoğraf gerekli.'**
  String get nfcFotoGerekli;

  /// No description provided for @nfcFotoCek.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek ve gönder'**
  String get nfcFotoCek;

  /// No description provided for @nfcFotoYukleniyor.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yükleniyor...'**
  String get nfcFotoYukleniyor;

  /// No description provided for @nfcFotoYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklenemedi: {hata}'**
  String nfcFotoYuklenemedi(String hata);

  /// No description provided for @nfcKonumYok.
  ///
  /// In tr, this message translates to:
  /// **'Konum alınamadı — okutma konumsuz kaydedildi.'**
  String get nfcKonumYok;

  /// No description provided for @nfcKonumIzinYok.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni verilmedi — okutma konumsuz kaydedildi.'**
  String get nfcKonumIzinYok;

  /// No description provided for @nfcKonumServisKapali.
  ///
  /// In tr, this message translates to:
  /// **'Konum servisi kapalı — okutma konumsuz kaydedildi.'**
  String get nfcKonumServisKapali;

  /// No description provided for @rolGuvenlikAmiri.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik Amiri'**
  String get rolGuvenlikAmiri;

  /// No description provided for @rolDenetci.
  ///
  /// In tr, this message translates to:
  /// **'Denetçi'**
  String get rolDenetci;

  /// No description provided for @kvkkBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma Metni'**
  String get kvkkBaslik;

  /// No description provided for @kvkkSonaKaydir.
  ///
  /// In tr, this message translates to:
  /// **'Onaylamak için metnin sonuna kadar okuyun.'**
  String get kvkkSonaKaydir;

  /// No description provided for @kvkkOnayliyorum.
  ///
  /// In tr, this message translates to:
  /// **'Okudum, onaylıyorum'**
  String get kvkkOnayliyorum;

  /// No description provided for @kvkkYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma metni yüklenemedi.'**
  String get kvkkYuklenemedi;

  /// No description provided for @kvkkTekrarDene.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get kvkkTekrarDene;

  /// No description provided for @kvkkSurumDegisti.
  ///
  /// In tr, this message translates to:
  /// **'Metin güncellendi; lütfen yeni metni okuyun.'**
  String get kvkkSurumDegisti;

  /// No description provided for @kvkkIzinBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bana özel kampanya ve teklifler'**
  String get kvkkIzinBaslik;

  /// No description provided for @kvkkIzinAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Tamamen isteğe bağlıdır; onaylamadan devam edebilirsiniz. İstediğiniz zaman Ayarlar\'dan değiştirebilirsiniz.'**
  String get kvkkIzinAciklama;

  /// No description provided for @kvkkIzinEposta.
  ///
  /// In tr, this message translates to:
  /// **'E-posta almak istiyorum'**
  String get kvkkIzinEposta;

  /// No description provided for @kvkkIzinSms.
  ///
  /// In tr, this message translates to:
  /// **'SMS almak istiyorum'**
  String get kvkkIzinSms;

  /// No description provided for @kvkkIzinArama.
  ///
  /// In tr, this message translates to:
  /// **'Aranmak istiyorum'**
  String get kvkkIzinArama;

  /// No description provided for @kvkkIzinKaydedilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Tercih kaydedilemedi.'**
  String get kvkkIzinKaydedilemedi;

  /// No description provided for @kvkkAyarlarBaslik.
  ///
  /// In tr, this message translates to:
  /// **'İzinler ve Aydınlatma Metni'**
  String get kvkkAyarlarBaslik;

  /// No description provided for @kvkkMetniGoruntule.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma metnini görüntüle'**
  String get kvkkMetniGoruntule;

  /// No description provided for @anketBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get anketBaslik;

  /// No description provided for @anketYok.
  ///
  /// In tr, this message translates to:
  /// **'Şu an açık anket yok.'**
  String get anketYok;

  /// No description provided for @anketKapali.
  ///
  /// In tr, this message translates to:
  /// **'Kapandı'**
  String get anketKapali;

  /// No description provided for @anketOyVerdiniz.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz alındı'**
  String get anketOyVerdiniz;

  /// No description provided for @anketOyVer.
  ///
  /// In tr, this message translates to:
  /// **'Oy ver'**
  String get anketOyVer;

  /// No description provided for @anketToplamOy.
  ///
  /// In tr, this message translates to:
  /// **'{sayi} oy'**
  String anketToplamOy(int sayi);

  /// No description provided for @anketOyHatasi.
  ///
  /// In tr, this message translates to:
  /// **'Oy gönderilemedi: {hata}'**
  String anketOyHatasi(String hata);

  /// No description provided for @anketSonucKapali.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar anket kapanınca görünür.'**
  String get anketSonucKapali;

  /// No description provided for @modulAnketler.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get modulAnketler;

  /// No description provided for @hesapSilBolum.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get hesapSilBolum;

  /// No description provided for @hesapSilBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı sil'**
  String get hesapSilBaslik;

  /// No description provided for @hesapSilAlt.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınızı ve kişisel verilerinizi kalıcı olarak silin'**
  String get hesapSilAlt;

  /// No description provided for @hesapSilOnayBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınızı silmek istiyor musunuz?'**
  String get hesapSilOnayBaslik;

  /// No description provided for @hesapSilOnayGovde.
  ///
  /// In tr, this message translates to:
  /// **'Adınız, telefonunuz, e-postanız ve cihaz kayıtlarınız silinir; hesabınıza bir daha giriş yapamazsınız. Aidat ve ödeme kayıtları yasal saklama yükümlülüğü nedeniyle silinemez; bu kayıtlar adınızla değil, anonim olarak saklanmaya devam eder.'**
  String get hesapSilOnayGovde;

  /// No description provided for @hesapSilParolaEtiket.
  ///
  /// In tr, this message translates to:
  /// **'Parolanız'**
  String get hesapSilParolaEtiket;

  /// No description provided for @hesapSilParolaAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik için parolanızı yeniden girin.'**
  String get hesapSilParolaAciklama;

  /// No description provided for @hesapSilOnayla.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı kalıcı olarak sil'**
  String get hesapSilOnayla;

  /// No description provided for @hesapSilSonucSilindi.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız silindi.'**
  String get hesapSilSonucSilindi;

  /// No description provided for @hesapSilSonucAnonim.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız silindi. Yasal olarak saklanması gereken kayıtlar anonim hâle getirildi.'**
  String get hesapSilSonucAnonim;

  /// No description provided for @hesapSilParolaGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için parolanızı girin.'**
  String get hesapSilParolaGerekli;

  /// No description provided for @hesapSilSiliniyor.
  ///
  /// In tr, this message translates to:
  /// **'Siliniyor...'**
  String get hesapSilSiliniyor;

  /// No description provided for @ayarlarHukuki.
  ///
  /// In tr, this message translates to:
  /// **'Yasal'**
  String get ayarlarHukuki;

  /// No description provided for @ayarlarGizlilik.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get ayarlarGizlilik;

  /// No description provided for @ayarlarKosullar.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get ayarlarKosullar;

  /// No description provided for @ayarlarBelgeAcilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa açılamadı. İnternet bağlantınızı kontrol edin.'**
  String get ayarlarBelgeAcilamadi;

  /// No description provided for @demoSimuleOkutma.
  ///
  /// In tr, this message translates to:
  /// **'Simüle okutma'**
  String get demoSimuleOkutma;

  /// No description provided for @demoSimuleOkutmaBasarili.
  ///
  /// In tr, this message translates to:
  /// **'Simüle okutma kaydedildi: {nokta}'**
  String demoSimuleOkutmaBasarili(String nokta);

  /// No description provided for @demoSimuleOkutmaHata.
  ///
  /// In tr, this message translates to:
  /// **'Simüle okutma yapılamadı.'**
  String get demoSimuleOkutmaHata;

  /// Denetci mobil girisinde: is masaustunde
  ///
  /// In tr, this message translates to:
  /// **'Denetim ekranları web\'de'**
  String get denetciWebBaslik;

  /// Denetciye web adresini soyler
  ///
  /// In tr, this message translates to:
  /// **'Denetim raporları ve mali gözetim masaüstü için tasarlandı. Bilgisayarınızdan {adres} adresine girin.'**
  String denetciWebGovde(String adres);

  /// Adresi panoya kopyala dugmesi
  ///
  /// In tr, this message translates to:
  /// **'Adresi kopyala'**
  String get denetciWebKopyala;

  /// Ana ekran karosu — vardiya cizelgesi
  ///
  /// In tr, this message translates to:
  /// **'Vardiyalar'**
  String get modulVardiyalar;

  /// No description provided for @izgaraDuzenleBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Ana ekranı düzenle'**
  String get izgaraDuzenleBaslik;

  /// No description provided for @izgaraDuzenleAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Sık kullandığınız {enCok} bölümü seçin.'**
  String izgaraDuzenleAciklama(int enCok);

  /// No description provided for @izgaraSifirla.
  ///
  /// In tr, this message translates to:
  /// **'Varsayılana dön'**
  String get izgaraSifirla;

  /// No description provided for @izgaraKaydet.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get izgaraKaydet;

  /// No description provided for @izgaraSecim.
  ///
  /// In tr, this message translates to:
  /// **'{secili}/{enCok} seçili'**
  String izgaraSecim(int secili, int enCok);

  /// Secim ekrani: tavana ulasildi
  ///
  /// In tr, this message translates to:
  /// **'Tavana ulaştınız. Yeni bir bölüm eklemek için önce birini çıkarın ({enCok} karo).'**
  String izgaraTavanUyarisi(int enCok);

  /// Dil secici modalinin basligi + simgenin erisilebilir adi
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get dilSeciciBaslik;

  /// No description provided for @talepGeriAl.
  ///
  /// In tr, this message translates to:
  /// **'Geri Al'**
  String get talepGeriAl;

  /// No description provided for @talepGeriAlOnay.
  ///
  /// In tr, this message translates to:
  /// **'Bu talebi geri almak istiyor musunuz? Geri alınan talep yönetime iletilmez ve bu işlem geri alınamaz.'**
  String get talepGeriAlOnay;

  /// No description provided for @talepGeriAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Talep geri alındı'**
  String get talepGeriAlindi;

  /// No description provided for @talepDurumGeriAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Geri Alındı'**
  String get talepDurumGeriAlindi;

  /// No description provided for @sikayetGeriAl.
  ///
  /// In tr, this message translates to:
  /// **'Şikayeti geri al'**
  String get sikayetGeriAl;

  /// No description provided for @sikayetGeriAlindi.
  ///
  /// In tr, this message translates to:
  /// **'Şikayet geri alındı'**
  String get sikayetGeriAlindi;

  /// No description provided for @izinDevam.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get izinDevam;

  /// No description provided for @izinKonumBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni neden gerekli?'**
  String get izinKonumBaslik;

  /// No description provided for @izinKonumGovde.
  ///
  /// In tr, this message translates to:
  /// **'Devriye noktasını okuttuğunuzda, turun gerçekten sahada yapıldığını doğrulamak için o anki konumunuz kaydedilir. Konumunuz YALNIZCA okutma anında alınır; uygulama sizi arka planda takip etmez.'**
  String get izinKonumGovde;

  /// No description provided for @izinKameraBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kamera izni neden gerekli?'**
  String get izinKameraBaslik;

  /// No description provided for @izinKameraGovde.
  ///
  /// In tr, this message translates to:
  /// **'Talep veya arıza bildirirken fotoğraf ekleyebilmeniz için kamera kullanılır. Fotoğraf yalnızca siz çektiğinizde alınır ve tesis yönetimine iletilir.'**
  String get izinKameraGovde;

  /// No description provided for @girisKodlaBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Parolam yok, kodla giriş yap'**
  String get girisKodlaBaslik;

  /// No description provided for @girisKodlaAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Telefonunuza altı haneli bir doğrulama kodu göndereceğiz.'**
  String get girisKodlaAciklama;

  /// No description provided for @girisKoduGonder.
  ///
  /// In tr, this message translates to:
  /// **'Kod gönder'**
  String get girisKoduGonder;

  /// No description provided for @girisKodAlani.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu'**
  String get girisKodAlani;

  /// No description provided for @hesapSilKodlaOnayla.
  ///
  /// In tr, this message translates to:
  /// **'Parolam yok, kodla onayla'**
  String get hesapSilKodlaOnayla;

  /// No description provided for @hesapSilKodAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Silme onayı için e-posta adresinize altı haneli bir kod göndereceğiz.'**
  String get hesapSilKodAciklama;

  /// No description provided for @hesapSilKodGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Onay kodunu girin'**
  String get hesapSilKodGerekli;

  /// No description provided for @kayitBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID ile giriş'**
  String get kayitBaslik;

  /// No description provided for @kayitAltBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Size uygun olanı seçiniz'**
  String get kayitAltBaslik;

  /// No description provided for @kayitRolYonetici.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get kayitRolYonetici;

  /// No description provided for @kayitRolSakin.
  ///
  /// In tr, this message translates to:
  /// **'Site sakini'**
  String get kayitRolSakin;

  /// No description provided for @kayitRolGuvenlik.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik görevlisi'**
  String get kayitRolGuvenlik;

  /// No description provided for @kayitRolTesisGorevlisi.
  ///
  /// In tr, this message translates to:
  /// **'Tesis görevlisi'**
  String get kayitRolTesisGorevlisi;

  /// No description provided for @kayitTesisKodu.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID'**
  String get kayitTesisKodu;

  /// No description provided for @kayitTesisKoduIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Yönetiminizin verdiği kod (örn. OLTU-260715)'**
  String get kayitTesisKoduIpucu;

  /// No description provided for @kayitDaireNo.
  ///
  /// In tr, this message translates to:
  /// **'Daire no'**
  String get kayitDaireNo;

  /// No description provided for @kayitBlok.
  ///
  /// In tr, this message translates to:
  /// **'Blok (varsa)'**
  String get kayitBlok;

  /// No description provided for @kayitDevam.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get kayitDevam;

  /// No description provided for @kayitKodBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu'**
  String get kayitKodBaslik;

  /// Kod gonderildi bilgisi; numara kayitli DEGILSE kod gelmez (sunucu sizdirmaz)
  ///
  /// In tr, this message translates to:
  /// **'{tesis} için {telefon} numarasına bir kod gönderildi. Numara sistemde kayıtlı değilse kod gelmez.'**
  String kayitKodAciklama(String tesis, String telefon);

  /// No description provided for @kayitKodAlani.
  ///
  /// In tr, this message translates to:
  /// **'6 haneli kod'**
  String get kayitKodAlani;

  /// No description provided for @kayitTesisKoduGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID gerekli.'**
  String get kayitTesisKoduGerekli;

  /// No description provided for @kayitDaireGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Daire no gerekli.'**
  String get kayitDaireGerekli;

  /// No description provided for @kayitKodGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Kodu girin.'**
  String get kayitKodGerekli;

  /// No description provided for @kayitYontemBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Nasıl giriş yapacaksınız?'**
  String get kayitYontemBaslik;

  /// No description provided for @kayitYontemParola.
  ///
  /// In tr, this message translates to:
  /// **'Parola oluştur'**
  String get kayitYontemParola;

  /// No description provided for @kayitGirisLinki.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabınız var mı? Giriş yapın'**
  String get kayitGirisLinki;

  /// Kayit akisi adim gostergesi
  ///
  /// In tr, this message translates to:
  /// **'Adım {n}/{toplam}'**
  String kayitAdim(String n, String toplam);

  /// No description provided for @sosyalIleDevam.
  ///
  /// In tr, this message translates to:
  /// **'{saglayici} ile devam et'**
  String sosyalIleDevam(String saglayici);

  /// No description provided for @sosyalBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınızı eşleştirin'**
  String get sosyalBaslik;

  /// No description provided for @sosyalEslesmeAciklama.
  ///
  /// In tr, this message translates to:
  /// **'{saglayici} hesabınız doğrulandı. Hesabınızı bulabilmemiz için tesis ID\'nizi ve telefon numaranızı girin.'**
  String sosyalEslesmeAciklama(String saglayici);

  /// No description provided for @sosyalRelayUyari.
  ///
  /// In tr, this message translates to:
  /// **'Apple e-posta adresinizi gizledi; bu adrese posta gönderilemez.'**
  String get sosyalRelayUyari;

  /// No description provided for @sosyalTesisKodu.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID'**
  String get sosyalTesisKodu;

  /// No description provided for @sosyalKodGonder.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama kodu gönder'**
  String get sosyalKodGonder;

  /// No description provided for @sosyalKodAciklama.
  ///
  /// In tr, this message translates to:
  /// **'{tesis} — {telefon} numarasına gönderilen kodu girin.'**
  String sosyalKodAciklama(String tesis, String telefon);

  /// No description provided for @sosyalDogrula.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula ve giriş yap'**
  String get sosyalDogrula;

  /// No description provided for @sosyalVazgec.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get sosyalVazgec;

  /// No description provided for @davetBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt'**
  String get davetBaslik;

  /// No description provided for @davetGecersizBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı çalışmıyor'**
  String get davetGecersizBaslik;

  /// No description provided for @davetSuresiDoldu.
  ///
  /// In tr, this message translates to:
  /// **'Bu davet bağlantısının süresi dolmuş.'**
  String get davetSuresiDoldu;

  /// No description provided for @davetKullanilmis.
  ///
  /// In tr, this message translates to:
  /// **'Bu davet zaten kullanılmış.'**
  String get davetKullanilmis;

  /// No description provided for @davetBulunamadi.
  ///
  /// In tr, this message translates to:
  /// **'Bu davet bağlantısı geçersiz.'**
  String get davetBulunamadi;

  /// No description provided for @davetYoneticinizeBasvurun.
  ///
  /// In tr, this message translates to:
  /// **'Yeni bir davet için yöneticinize başvurun.'**
  String get davetYoneticinizeBasvurun;

  /// No description provided for @davetOzet.
  ///
  /// In tr, this message translates to:
  /// **'{tesis} sizi {rol} olarak davet etti.'**
  String davetOzet(String tesis, String rol);

  /// No description provided for @kayitYontemEposta.
  ///
  /// In tr, this message translates to:
  /// **'E-posta ile devam et'**
  String get kayitYontemEposta;

  /// No description provided for @kayitYontemVeya.
  ///
  /// In tr, this message translates to:
  /// **'veya'**
  String get kayitYontemVeya;

  /// No description provided for @kayitBilgilerBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz'**
  String get kayitBilgilerBaslik;

  /// No description provided for @kayitAdSoyad.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad'**
  String get kayitAdSoyad;

  /// No description provided for @kayitAdGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad gerekli.'**
  String get kayitAdGerekli;

  /// No description provided for @kayitParola.
  ///
  /// In tr, this message translates to:
  /// **'Parola'**
  String get kayitParola;

  /// No description provided for @kayitParolaGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Parola en az 8 karakter olmalı.'**
  String get kayitParolaGerekli;

  /// No description provided for @kayitTesisAdBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesisinizi oluşturun'**
  String get kayitTesisAdBaslik;

  /// No description provided for @kayitTesisAd.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adını giriniz'**
  String get kayitTesisAd;

  /// No description provided for @kayitTesisAdIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Oltu Sitesi'**
  String get kayitTesisAdIpucu;

  /// No description provided for @kayitTesisAdGerekli.
  ///
  /// In tr, this message translates to:
  /// **'Tesis adı gerekli.'**
  String get kayitTesisAdGerekli;

  /// No description provided for @kayitZatenSitemVar.
  ///
  /// In tr, this message translates to:
  /// **'Zaten bir sitem var'**
  String get kayitZatenSitemVar;

  /// No description provided for @kayitTesisKoduBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesis kodunuz'**
  String get kayitTesisKoduBaslik;

  /// No description provided for @kayitTesisKoduPaylas.
  ///
  /// In tr, this message translates to:
  /// **'Bu kodu sakinlerinize ve personelinize iletin; uygulamaya bu kodla katılırlar.'**
  String get kayitTesisKoduPaylas;

  /// No description provided for @kayitKopyala.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get kayitKopyala;

  /// No description provided for @kayitKopyalandi.
  ///
  /// In tr, this message translates to:
  /// **'Kopyalandı'**
  String get kayitKopyalandi;

  /// No description provided for @kayitTamamla.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get kayitTamamla;

  /// No description provided for @kayitSosyalAdNotu.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad hesabınızdan alındı; değiştirebilirsiniz.'**
  String get kayitSosyalAdNotu;

  /// No description provided for @kayitEposta.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get kayitEposta;

  /// No description provided for @kayitEpostaGerekli.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi gerekli.'**
  String get kayitEpostaGerekli;

  /// No description provided for @kayitEpostaGecersiz.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta girin.'**
  String get kayitEpostaGecersiz;

  /// No description provided for @kayitTelefonIletisim.
  ///
  /// In tr, this message translates to:
  /// **'Telefon (isteğe bağlı)'**
  String get kayitTelefonIletisim;

  /// No description provided for @kayitTelefonNotu.
  ///
  /// In tr, this message translates to:
  /// **'Telefon yalnızca iletişim içindir; doğrulama e-posta ile yapılır.'**
  String get kayitTelefonNotu;

  /// No description provided for @kayitTesisKoduGir.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID\'nizi girin'**
  String get kayitTesisKoduGir;

  /// E-postaya kod gonderildi; adres kayitli DEGILSE kod gelmez (sunucu sizdirmaz)
  ///
  /// In tr, this message translates to:
  /// **'{tesis} için e-posta adresinize bir doğrulama kodu gönderdik. Adresiniz sistemde kayıtlı değilse kod gelmez.'**
  String kayitKodAciklamaEposta(String tesis);

  /// No description provided for @kayitOnayBekliyorBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici onayı bekleniyor'**
  String get kayitOnayBekliyorBaslik;

  /// No description provided for @kayitOnayBekliyorAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Bilgileriniz doğrulanamadı ve yöneticinizin onayına iletildi. Tesis ID\'nizi kontrol edin; sorun sürerse yöneticinize danışın. Onaylandığında giriş yapabilirsiniz.'**
  String get kayitOnayBekliyorAciklama;

  /// No description provided for @kayitGiriseDon.
  ///
  /// In tr, this message translates to:
  /// **'Girişe dön'**
  String get kayitGiriseDon;

  /// No description provided for @sosyalTamamlaBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesis ID ile tamamla'**
  String get sosyalTamamlaBaslik;

  /// No description provided for @sosyalTamamlaAciklama.
  ///
  /// In tr, this message translates to:
  /// **'{saglayici} hesabınız doğrulandı. Tamamlamak için rolünüzü ve Tesis ID\'nizi girin.'**
  String sosyalTamamlaAciklama(String saglayici);

  /// No description provided for @sosyalRol.
  ///
  /// In tr, this message translates to:
  /// **'Rolünüz'**
  String get sosyalRol;

  /// No description provided for @sosyalTamamla.
  ///
  /// In tr, this message translates to:
  /// **'Tamamla'**
  String get sosyalTamamla;

  /// No description provided for @sosyalOtpAciklama.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresinize gönderilen doğrulama kodunu girin.'**
  String get sosyalOtpAciklama;

  /// No description provided for @binaYapisalAraclar.
  ///
  /// In tr, this message translates to:
  /// **'Yapısal araçlar'**
  String get binaYapisalAraclar;

  /// No description provided for @binaKatSil.
  ///
  /// In tr, this message translates to:
  /// **'Katı sil'**
  String get binaKatSil;

  /// No description provided for @binaTopluTip.
  ///
  /// In tr, this message translates to:
  /// **'Toplu durum değiştir'**
  String get binaTopluTip;

  /// No description provided for @binaSiralama.
  ///
  /// In tr, this message translates to:
  /// **'Sıralamayı düzenle'**
  String get binaSiralama;

  /// No description provided for @binaKatSilOzet.
  ///
  /// In tr, this message translates to:
  /// **'{n} daire silinecek'**
  String binaKatSilOzet(int n);

  /// No description provided for @binaKatSilOnay.
  ///
  /// In tr, this message translates to:
  /// **'{kat}. kattaki tüm daireler kalıcı olarak silinecek. Bu işlem geri alınamaz.'**
  String binaKatSilOnay(int kat);

  /// No description provided for @binaAralikSec.
  ///
  /// In tr, this message translates to:
  /// **'Numara ile seç'**
  String get binaAralikSec;

  /// No description provided for @binaAralikUygula.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get binaAralikUygula;

  /// No description provided for @binaSeciliSayisi.
  ///
  /// In tr, this message translates to:
  /// **'{n} daire seçili'**
  String binaSeciliSayisi(int n);

  /// No description provided for @binaAralikBulunamayan.
  ///
  /// In tr, this message translates to:
  /// **'Bulunamayan: {parca}'**
  String binaAralikBulunamayan(String parca);

  /// No description provided for @ortakEminMisiniz.
  ///
  /// In tr, this message translates to:
  /// **'Emin misiniz?'**
  String get ortakEminMisiniz;

  /// No description provided for @ortakDurum.
  ///
  /// In tr, this message translates to:
  /// **'Durum'**
  String get ortakDurum;

  /// No description provided for @ortakAktif.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get ortakAktif;

  /// No description provided for @ortakPasif.
  ///
  /// In tr, this message translates to:
  /// **'Pasif'**
  String get ortakPasif;

  /// No description provided for @binaBaslangicKat.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç katı'**
  String get binaBaslangicKat;

  /// No description provided for @binaBaslangicKatIpucu.
  ///
  /// In tr, this message translates to:
  /// **'Bodrum için negatif: -2, -1, 0 (zemin), 1…'**
  String get binaBaslangicKatIpucu;

  /// No description provided for @rezSekmeGecmis.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get rezSekmeGecmis;

  /// No description provided for @rezGecmisYok.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş rezervasyon yok.'**
  String get rezGecmisYok;

  /// No description provided for @rezGecmisTamam.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get rezGecmisTamam;

  /// No description provided for @rezIptalEden.
  ///
  /// In tr, this message translates to:
  /// **'İptal eden: {ad}'**
  String rezIptalEden(String ad);

  /// No description provided for @binaKatBos.
  ///
  /// In tr, this message translates to:
  /// **'Bu katta daire yok; silmek bir kaydı etkilemez.'**
  String get binaKatBos;

  /// No description provided for @binaKatOzet.
  ///
  /// In tr, this message translates to:
  /// **'{daire} daire · {sakin} sakin · {talep} açık şikayet'**
  String binaKatOzet(int daire, int sakin, int talep);

  /// No description provided for @binaKatOzetMali.
  ///
  /// In tr, this message translates to:
  /// **'{tahakkuk} tahakkuk · {odeme} tahsilat · {rezervasyon} rezervasyon'**
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon);

  /// No description provided for @binaKatMaliUyari.
  ///
  /// In tr, this message translates to:
  /// **'Bu katta aidat kaydı var. Silinirse tahakkuk ve tahsilat kayıtları da kalıcı olarak gider; muhasebe izi geri getirilemez. Daireleri silmek yerine pasifleştirmeyi değerlendirin.'**
  String get binaKatMaliUyari;

  /// No description provided for @binaKatOnayYaz.
  ///
  /// In tr, this message translates to:
  /// **'Onaylamak için kat numarasını yazın ({kat})'**
  String binaKatOnayYaz(int kat);

  /// No description provided for @binaKatSilOzetOnay.
  ///
  /// In tr, this message translates to:
  /// **'{blok} bloğu {kat}. kat silinecek: {daire} daire, {sakin} sakin ve {kayit} bağlı kayıt kalıcı olarak gider. Bu işlem geri alınamaz.'**
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  );

  /// No description provided for @kurulumBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kurulum Sihirbazı'**
  String get kurulumBaslik;

  /// No description provided for @kurulumAlt.
  ///
  /// In tr, this message translates to:
  /// **'Tesisinizi kullanıma hazır hâle getirmek için adımları tamamlayın.'**
  String get kurulumAlt;

  /// No description provided for @kurulumIlerleme.
  ///
  /// In tr, this message translates to:
  /// **'İlerleme'**
  String get kurulumIlerleme;

  /// No description provided for @kurulumTamamlandi.
  ///
  /// In tr, this message translates to:
  /// **'Kurulum tamamlandı'**
  String get kurulumTamamlandi;

  /// No description provided for @kurulumAdimTamam.
  ///
  /// In tr, this message translates to:
  /// **'{sayi} kayıt'**
  String kurulumAdimTamam(int sayi);

  /// No description provided for @kurulumAdimAtlandi.
  ///
  /// In tr, this message translates to:
  /// **'Atlandı'**
  String get kurulumAdimAtlandi;

  /// No description provided for @kurulumAdimBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get kurulumAdimBekliyor;

  /// No description provided for @kurulumGit.
  ///
  /// In tr, this message translates to:
  /// **'Git'**
  String get kurulumGit;

  /// No description provided for @kurulumGoruntule.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüle'**
  String get kurulumGoruntule;

  /// No description provided for @kurulumAtla.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get kurulumAtla;

  /// No description provided for @kurulumAtlamayiGeriAl.
  ///
  /// In tr, this message translates to:
  /// **'Atlamayı geri al'**
  String get kurulumAtlamayiGeriAl;

  /// No description provided for @kurulumSayac.
  ///
  /// In tr, this message translates to:
  /// **'{gecilen}/{toplam} adım'**
  String kurulumSayac(int gecilen, int toplam);

  /// No description provided for @kurulumHata.
  ///
  /// In tr, this message translates to:
  /// **'Kurulum durumu yüklenemedi.'**
  String get kurulumHata;

  /// No description provided for @kurulumBlok.
  ///
  /// In tr, this message translates to:
  /// **'Bloklar'**
  String get kurulumBlok;

  /// No description provided for @kurulumBlokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Binanın bloklarını tanımlayın.'**
  String get kurulumBlokAlt;

  /// No description provided for @kurulumDaire.
  ///
  /// In tr, this message translates to:
  /// **'Daireler'**
  String get kurulumDaire;

  /// No description provided for @kurulumDaireAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kat ve daireleri toplu olarak oluşturun.'**
  String get kurulumDaireAlt;

  /// No description provided for @kurulumDaireTipi.
  ///
  /// In tr, this message translates to:
  /// **'Daire tipleri'**
  String get kurulumDaireTipi;

  /// No description provided for @kurulumDaireTipiAlt.
  ///
  /// In tr, this message translates to:
  /// **'Tip ve varsayılan aidat tutarlarını tanımlayın.'**
  String get kurulumDaireTipiAlt;

  /// No description provided for @kurulumSakin.
  ///
  /// In tr, this message translates to:
  /// **'Sakinler'**
  String get kurulumSakin;

  /// No description provided for @kurulumSakinAlt.
  ///
  /// In tr, this message translates to:
  /// **'Dairelere sakinleri ekleyin.'**
  String get kurulumSakinAlt;

  /// No description provided for @kurulumPersonel.
  ///
  /// In tr, this message translates to:
  /// **'Personel'**
  String get kurulumPersonel;

  /// No description provided for @kurulumPersonelAlt.
  ///
  /// In tr, this message translates to:
  /// **'Çalışan kayıtlarını girin.'**
  String get kurulumPersonelAlt;

  /// No description provided for @kurulumGorevAlani.
  ///
  /// In tr, this message translates to:
  /// **'Görev kategorileri'**
  String get kurulumGorevAlani;

  /// No description provided for @kurulumGorevAlaniAlt.
  ///
  /// In tr, this message translates to:
  /// **'Görevleri gruplayacağınız kategorileri oluşturun.'**
  String get kurulumGorevAlaniAlt;

  /// No description provided for @kurulumNfc.
  ///
  /// In tr, this message translates to:
  /// **'NFC noktaları'**
  String get kurulumNfc;

  /// No description provided for @kurulumNfcAlt.
  ///
  /// In tr, this message translates to:
  /// **'Devriye kontrol noktalarını tanımlayın.'**
  String get kurulumNfcAlt;

  /// No description provided for @kurulumAidat.
  ///
  /// In tr, this message translates to:
  /// **'Aidat tahakkuku'**
  String get kurulumAidat;

  /// No description provided for @kurulumAidatAlt.
  ///
  /// In tr, this message translates to:
  /// **'İlk dönemin aidatını dairelere yazın.'**
  String get kurulumAidatAlt;

  /// No description provided for @kurulumAdimWebde.
  ///
  /// In tr, this message translates to:
  /// **'Bu adım şu an yalnızca web panelinden ve platform yöneticisi (admin) hesabıyla yapılabilir.'**
  String get kurulumAdimWebde;

  /// No description provided for @kurulumHatirlaticiBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Kurulumu tamamlayın'**
  String get kurulumHatirlaticiBaslik;

  /// No description provided for @kurulumHatirlaticiMetin.
  ///
  /// In tr, this message translates to:
  /// **'Tesisinizi kullanıma hazır hâle getirmek için birkaç adım kaldı. Sihirbaz sizi tek tek ilgili ekranlara götürür.'**
  String get kurulumHatirlaticiMetin;

  /// No description provided for @kurulumHatirlaticiGit.
  ///
  /// In tr, this message translates to:
  /// **'Sihirbazı aç'**
  String get kurulumHatirlaticiGit;

  /// No description provided for @kurulumHatirlaticiSonra.
  ///
  /// In tr, this message translates to:
  /// **'Daha sonra'**
  String get kurulumHatirlaticiSonra;

  /// No description provided for @noktaYokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Kontrol noktaları, devriye turlarında okutulan NFC etiketleridir.'**
  String get noktaYokAlt;

  /// No description provided for @devriyePlanYokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Devriye planı, hangi noktaların hangi saatlerde okutulacağını belirler.'**
  String get devriyePlanYokAlt;

  /// No description provided for @personelYokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik ve tesis görevlisi hesaplarını buradan açarsınız.'**
  String get personelYokAlt;

  /// No description provided for @sakinYokAlt.
  ///
  /// In tr, this message translates to:
  /// **'Sakinleri ekleyince dairelere bağlanır ve uygulamaya giriş yapabilirler.'**
  String get sakinYokAlt;

  /// No description provided for @ortakDahaFazlaSecenek.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla seçenek'**
  String get ortakDahaFazlaSecenek;

  /// No description provided for @modulDokumanlar.
  ///
  /// In tr, this message translates to:
  /// **'Site Dokümanları'**
  String get modulDokumanlar;

  /// No description provided for @dokumanBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Site Dokümanları'**
  String get dokumanBaslik;

  /// No description provided for @dokumanAra.
  ///
  /// In tr, this message translates to:
  /// **'Doküman adında ara'**
  String get dokumanAra;

  /// No description provided for @dokumanYokSakin.
  ///
  /// In tr, this message translates to:
  /// **'Henüz paylaşılmış doküman yok.'**
  String get dokumanYokSakin;

  /// No description provided for @dokumanAramaSonucYok.
  ///
  /// In tr, this message translates to:
  /// **'Aramanızla eşleşen doküman yok.'**
  String get dokumanAramaSonucYok;

  /// No description provided for @dokumanAcilamadi.
  ///
  /// In tr, this message translates to:
  /// **'Doküman açılamadı.'**
  String get dokumanAcilamadi;

  /// Dosya boyutu (kilobayt) — sayi istemcide yuvarlanir.
  ///
  /// In tr, this message translates to:
  /// **'{kb} KB'**
  String dokumanBoyutKb(int kb);

  /// No description provided for @kvkkYasalMetinler.
  ///
  /// In tr, this message translates to:
  /// **'Yasal Metinler'**
  String get kvkkYasalMetinler;

  /// No description provided for @kvkkTurAydinlatma.
  ///
  /// In tr, this message translates to:
  /// **'Aydınlatma Metni'**
  String get kvkkTurAydinlatma;

  /// No description provided for @kvkkTurAcikRiza.
  ///
  /// In tr, this message translates to:
  /// **'Açık Rıza'**
  String get kvkkTurAcikRiza;

  /// No description provided for @kvkkTurGizlilik.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get kvkkTurGizlilik;

  /// No description provided for @kvkkTurKullanim.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get kvkkTurKullanim;

  /// No description provided for @kvkkTurCerez.
  ///
  /// In tr, this message translates to:
  /// **'Çerez Politikası'**
  String get kvkkTurCerez;

  /// No description provided for @kvkkMetinYayinlanmamis.
  ///
  /// In tr, this message translates to:
  /// **'Bu metin henüz yayınlanmamış.'**
  String get kvkkMetinYayinlanmamis;

  /// No description provided for @kvkkOnaylanmadi.
  ///
  /// In tr, this message translates to:
  /// **'Bu metni henüz onaylamadınız.'**
  String get kvkkOnaylanmadi;

  /// No description provided for @kvkkYenidenOnayBekleniyor.
  ///
  /// In tr, this message translates to:
  /// **'Güncel sürüm için onayınız bekleniyor.'**
  String get kvkkYenidenOnayBekleniyor;

  /// No description provided for @kvkkSurumEtiketi.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {n}'**
  String kvkkSurumEtiketi(int n);

  /// No description provided for @kvkkOnayladiginizSurum.
  ///
  /// In tr, this message translates to:
  /// **'Onayladığınız sürüm: {n}'**
  String kvkkOnayladiginizSurum(int n);

  /// No description provided for @kabukKisayollar.
  ///
  /// In tr, this message translates to:
  /// **'Kısayollar'**
  String get kabukKisayollar;

  /// No description provided for @ayarlarBildirimlerBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get ayarlarBildirimlerBaslik;

  /// No description provided for @ayarlarBildirimTercih.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim tercihleri'**
  String get ayarlarBildirimTercih;

  /// No description provided for @ayarlarBildirimAciklama.
  ///
  /// In tr, this message translates to:
  /// **'Hangi kanallardan işleyiş bildirimi almak istediğinizi seçin. Bu, pazarlama izinlerinden ayrıdır.'**
  String get ayarlarBildirimAciklama;

  /// No description provided for @ayarlarBildirimEposta.
  ///
  /// In tr, this message translates to:
  /// **'E-posta bildirimleri'**
  String get ayarlarBildirimEposta;

  /// No description provided for @ayarlarBildirimSms.
  ///
  /// In tr, this message translates to:
  /// **'SMS bildirimleri'**
  String get ayarlarBildirimSms;

  /// No description provided for @ayarlarBildirimMobil.
  ///
  /// In tr, this message translates to:
  /// **'Mobil bildirimler'**
  String get ayarlarBildirimMobil;

  /// No description provided for @ayarlarBildirimKaydedildi.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim tercihi güncellendi'**
  String get ayarlarBildirimKaydedildi;

  /// No description provided for @ayarlarBildirimYuklenemedi.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim tercihleri yüklenemedi'**
  String get ayarlarBildirimYuklenemedi;

  /// No description provided for @ayarlarBildirimIzinKapali.
  ///
  /// In tr, this message translates to:
  /// **'Cihaz bildirim izni kapalı. Mobil bildirimler telefonda görünmez; cihaz ayarlarından açın.'**
  String get ayarlarBildirimIzinKapali;

  /// No description provided for @ayarlarBildirimIzinBelirsiz.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimleri görmek için izin gerekiyor.'**
  String get ayarlarBildirimIzinBelirsiz;

  /// No description provided for @ayarlarBildirimIzinIste.
  ///
  /// In tr, this message translates to:
  /// **'İzin iste'**
  String get ayarlarBildirimIzinIste;

  /// (P202) Kapatilamayan zorunlu guncelleme ekraninin basligi.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme gerekli'**
  String get surumZorunluBaslik;

  /// (P202) Zorunlu guncelleme aciklamasi. Operator mesaj yazmadiysa BU gosterilir.
  ///
  /// In tr, this message translates to:
  /// **'Bu sürüm artık kullanılamıyor. Devam etmek için uygulamayı güncelleyin.'**
  String get surumZorunluMetin;

  /// (P202) Kapatilabilir onerilen guncelleme uyarisinin basligi.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sürüm var'**
  String get surumOnerilenBaslik;

  /// (P202) Onerilen guncelleme aciklamasi (operator mesaji yoksa).
  ///
  /// In tr, this message translates to:
  /// **'Daha iyi bir deneyim için uygulamayı güncelleyin.'**
  String get surumOnerilenMetin;

  /// (P202) Zorunlu ekrandaki TEK dugme.
  ///
  /// In tr, this message translates to:
  /// **'Güncelle'**
  String get surumGuncelle;

  /// (P202) Onerilen uyarisinda magazaya giden dugme.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi güncelle'**
  String get surumSimdiGuncelle;

  /// (P202) Onerilen uyarisini 24 saat susturan dugme.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get surumSonra;

  /// (P202) Magaza acilamadiginda kullaniciya ne oldugu soylenir.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza açılamadı. Uygulamayı telefonunuzun uygulama mağazasından elle güncelleyebilirsiniz.'**
  String get surumMagazaAcilamadi;

  /// (P203 §2) Coklu tesis seciciyi acan baslik.
  ///
  /// In tr, this message translates to:
  /// **'Tesis değiştir'**
  String get tesisDegistirBaslik;

  /// (P203 §2) Kullanicinin SU AN bulundugu tesisin isareti.
  ///
  /// In tr, this message translates to:
  /// **'Buradasınız'**
  String get tesisDegistirSecili;

  /// (P203 §3) Ziyaretci formunda daire ARAMA alani (eski: serbest metin daire no).
  ///
  /// In tr, this message translates to:
  /// **'Daire'**
  String get ziyaretDaireAra;

  /// (P203 §3) Gorevli numarayi bilmeyebilir; adla da aranabildigi soylenir.
  ///
  /// In tr, this message translates to:
  /// **'Daire numarası ya da sakin adı yazın'**
  String get ziyaretDaireAraIpucu;

  /// (P203 §4) Vardiya plani ekrani — vardiyaPlaniBaslik.
  ///
  /// In tr, this message translates to:
  /// **'Vardiya planı'**
  String get vardiyaPlaniBaslik;

  /// (P203 §4) Vardiya plani ekrani — vardiyaSuAnGorevde.
  ///
  /// In tr, this message translates to:
  /// **'Şu an görevde'**
  String get vardiyaSuAnGorevde;

  /// (P203 §4) Vardiya plani ekrani — vardiyaSuAnKimseYok.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda planlı görevli yok.'**
  String get vardiyaSuAnKimseYok;

  /// (P203 §4) Vardiya plani ekrani — vardiyaSiradaki.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki vardiya'**
  String get vardiyaSiradaki;

  /// (P203 §4) Vardiya plani ekrani — vardiyaSiradakiYok.
  ///
  /// In tr, this message translates to:
  /// **'Planlanmış bir sonraki vardiya yok.'**
  String get vardiyaSiradakiYok;

  /// (P203 §4) Vardiya plani ekrani — vardiyaBos.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get vardiyaBos;

  /// (P203 §4) Vardiya plani ekrani — vardiyaCikar.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get vardiyaCikar;

  /// (P203 §4) Vardiya plani ekrani — vardiyaCikarSebep.
  ///
  /// In tr, this message translates to:
  /// **'Çıkarma sebebi (hastalık, izin, acil durum)'**
  String get vardiyaCikarSebep;
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
