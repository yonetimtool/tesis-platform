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

  /// No description provided for @sekmeAyarlar.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get sekmeAyarlar;

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
