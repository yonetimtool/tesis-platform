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

  /// No description provided for @otoparkDoluKapasite.
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

  /// No description provided for @anaDaireAltBaslik.
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
