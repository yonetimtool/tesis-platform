// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get cipYeni => 'Neu';

  @override
  String get cipAktif => 'Aktiv';

  @override
  String get bolumVardiyaDurumu => 'Schichtstatus';

  @override
  String get bolumSonHareketler => 'Letzte Aktivitäten';

  @override
  String get bolumHizliOzet => 'Kurzübersicht';

  @override
  String get bolumDuyurular => 'Ankündigungen';

  @override
  String get bolumSiteKurallari => 'Hausordnung';

  @override
  String get bolumEtkinlikler => 'Veranstaltungen';

  @override
  String get bolumOdemeAidat => 'Zahlungen und Hausgeld';

  @override
  String get bolumTumModuller => 'Alle Module';

  @override
  String get kartVardiyaDurum => 'Schicht';

  @override
  String get kartKargo => 'Pakete';

  @override
  String get kartZiyaretci => 'Besucher';

  @override
  String get kartAracPlaka => 'Fahrzeuge';

  @override
  String get kartIhlaller => 'Verstöße';

  @override
  String get kartGorevlerim => 'Meine Aufgaben';

  @override
  String get kartDemirbas => 'Inventar';

  @override
  String get kartTurlarim => 'Meine Rundgänge';

  @override
  String get kartTalepAriza => 'Anfragen';

  @override
  String get kartZiyaretciler => 'Besucher';

  @override
  String get kartKargolarim => 'Meine Pakete';

  @override
  String get kartAidatBilgileri => 'Hausgeld';

  @override
  String get kartGurultuSikayeti => 'Lärmbeschwerde';

  @override
  String get kartGeriBildirim => 'Rückmeldung';

  @override
  String get kartSikayetlerim => 'Meine Beschwerden';

  @override
  String get kartSiteRaporlari => 'Site-Berichte';

  @override
  String get kartGorevler => 'Aufgaben';

  @override
  String get kartAidatDurumu => 'Hausgeld-Status';

  @override
  String get kartOtoparkKullanimi => 'Parkplatznutzung';

  @override
  String get kartSikayetler => 'Beschwerden';

  @override
  String get kartRaporlar => 'Berichte';

  @override
  String get kartYonetici => 'Verwalter';

  @override
  String get kartGonderimKuyrugu => 'Sende-Warteschlange';

  @override
  String get etiketAylikOzet => 'Monatsübersicht';

  @override
  String get etiketDevriye => 'Rundgang';

  @override
  String get etiketKurallar => 'Regeln';

  @override
  String get etiketIletisim => 'Kontakt';

  @override
  String sayacAktif(num n) {
    return '$n aktiv';
  }

  @override
  String sayacIceride(num n) {
    return '$n im Gebäude';
  }

  @override
  String sayacGiris(num n) {
    return '$n Einfahrten';
  }

  @override
  String sayacYeni(num n) {
    return '$n neu';
  }

  @override
  String sayacAcik(num n) {
    return '$n offen';
  }

  @override
  String sayacZimmetli(num n) {
    return '$n ausgegeben';
  }

  @override
  String sayacKayit(num n) {
    return '$n Einträge';
  }

  @override
  String sayacYaklasan(num n) {
    return '$n bevorstehend';
  }

  @override
  String sayacDaire(num n) {
    return '$n Wohnungen';
  }

  @override
  String sayacArac(num n) {
    return '$n Fahrzeuge';
  }

  @override
  String sayacGorevli(num n) {
    return '$n Mitarbeitende';
  }

  @override
  String sayacBekleyen(num n) {
    return '$n wartend';
  }

  @override
  String get ozetToplamDaire => 'Wohnungen insgesamt';

  @override
  String get ozetToplamTahsilat => 'Gesamteinnahmen';

  @override
  String get ozetTahsilatOrani => 'Einzugsquote';

  @override
  String get ozetOtoparkDoluluk => 'Parkplatzbelegung';

  @override
  String get ozetTumSite => 'Gesamte Anlage';

  @override
  String get ozetBuAy => 'Diesen Monat';

  @override
  String get ozetSuAn => 'Jetzt';

  @override
  String otoparkDoluKapasite(Object dolu, Object kapasite) {
    return '$dolu / $kapasite';
  }

  @override
  String yuzdeDeger(Object oran) {
    return '$oran %';
  }

  @override
  String anaSelam(Object ad) {
    return 'Hallo, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Verwalter-Panel';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Wohnung $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Gestern';

  @override
  String get anaOnline => 'Online';

  @override
  String get anaVardiyaAktif => 'Aktiv';

  @override
  String get anaVardiyaPlanlandi => 'Geplant';

  @override
  String get anaEtkinlikSuruyor => 'Läuft';

  @override
  String get anaEtkinlikYaklasan => 'Bevorstehend';

  @override
  String get anaOdendi => 'Bezahlt';

  @override
  String get anaOdenmedi => 'Offen';

  @override
  String get anaBorcVar => 'Offener Betrag';

  @override
  String get anaBorcYok => 'Kein offener Betrag';

  @override
  String get anaBuAykiAidat => 'Hausgeld diesen Monat';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Letzte Zahlung: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Nächste Zahlung';

  @override
  String get anaGecmisOdemeler => 'Zahlungsverlauf';

  @override
  String get anaAidatKaydiYok => 'Kein Hausgeld-Eintrag gefunden';

  @override
  String get anaBildirimlerYakinda => 'Benachrichtigungen folgen bald';

  @override
  String get anaBildirimlerRolYok =>
      'Benachrichtigungen sind für diese Rolle nicht verfügbar';

  @override
  String get anaRaporlarYakinda => 'Berichte folgen bald';

  @override
  String get sekmeAnaSayfa => 'Start';

  @override
  String get sekmeBildirimler => 'Mitteilungen';

  @override
  String get sekmeRaporlar => 'Berichte';

  @override
  String get sekmeAyarlar => 'Einstellungen';

  @override
  String get kabukProfil => 'Profil';

  @override
  String get kabukCikisYap => 'Abmelden';

  @override
  String get fabOlayBildir => 'Vorfall melden';

  @override
  String get fabTalepBildir => 'Anfrage / Meldung';

  @override
  String get fabTalepArizaBildir => 'Anfrage / Störung melden';

  @override
  String get fabRezervasyonYap => 'Reservieren';

  @override
  String get fabDuyuruYayinla => 'Ankündigung veröffentlichen';

  @override
  String get fabGorevOlustur => 'Aufgabe erstellen';

  @override
  String get fabDestekTalebi => 'Support-Anfrage';

  @override
  String get modulDuyurular => 'Ankündigungen';

  @override
  String get modulTurlarim => 'Meine Rundgänge';

  @override
  String get modulDevriyeTakibi => 'Rundgang-Verfolgung';

  @override
  String get modulGorevlerim => 'Meine Aufgaben';

  @override
  String get modulGorevYonetimi => 'Aufgabenverwaltung';

  @override
  String get modulDemirbas => 'Inventar';

  @override
  String get modulNfcOkutma => 'NFC-Scan';

  @override
  String get modulGonderimKuyrugu => 'Sende-Warteschlange';

  @override
  String get modulAylikRaporlar => 'Monatsberichte';

  @override
  String get modulButce => 'Budget';

  @override
  String get modulFinansalOzet => 'Finanzübersicht';

  @override
  String get modulSeffaflik => 'Transparenz';

  @override
  String get modulSiteButcesi => 'Site-Budget';

  @override
  String get modulAidatim => 'Mein Hausgeld';

  @override
  String get modulSikayetOneri => 'Beschwerde / Vorschlag';

  @override
  String get modulZiyaretciler => 'Besucher';

  @override
  String get modulKargo => 'Pakete';

  @override
  String get modulGoruntulemeIzni => 'Einsichtsberechtigung';

  @override
  String get modulRezervasyon => 'Reservierung';

  @override
  String get modulEtkinlikler => 'Veranstaltungen';

  @override
  String get modulSiteKurallari => 'Hausordnung';

  @override
  String get modulDisHizmetler => 'Externe Dienste';

  @override
  String get modulEntegrasyonlar => 'Integrationen';

  @override
  String get modulPersonel => 'Außendienst-Personal';

  @override
  String get modulSakinler => 'Bewohner';

  @override
  String get modulBinaYapisi => 'Gebäudestruktur';

  @override
  String get modulSikayetHaritasi => 'Beschwerde-Karte';

  @override
  String get modulSikayetlerim => 'Meine Beschwerden';

  @override
  String get modulYoneticiIletisim => 'Verwalter-Kontakt';

  @override
  String get ortakKaydet => 'Speichern';

  @override
  String sayacBekliyor(num n) {
    return '$n offen';
  }

  @override
  String get ortakKaydediliyor => 'Wird gespeichert...';

  @override
  String get ortakVazgec => 'Abbrechen';

  @override
  String get ortakSil => 'Löschen';

  @override
  String get ortakDuzenle => 'Bearbeiten';

  @override
  String get ortakEkle => 'Hinzufügen';

  @override
  String get ortakTamam => 'OK';

  @override
  String get ortakKapat => 'Schließen';

  @override
  String get ortakTumunuGor => 'Alle anzeigen';

  @override
  String get ortakYuklenemedi => 'Konnte nicht geladen werden';

  @override
  String get ortakYenidenDene => 'Erneut versuchen';

  @override
  String get ortakYakinda => 'Demnächst';

  @override
  String get ortakBolumYakinda => 'Dieser Bereich kommt bald';

  @override
  String get ortakBeklenmeyenHata =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte erneut versuchen.';

  @override
  String ortakZorunluAlan(Object alan) {
    return '$alan ist erforderlich';
  }

  @override
  String get ayarlarBaslik => 'Einstellungen';

  @override
  String get ayarlarTesis => 'Anlage';

  @override
  String get ayarlarYonetim => 'Verwaltung';

  @override
  String get ayarlarGorunum => 'Darstellung';

  @override
  String get ayarlarTema => 'Design';

  @override
  String get ayarlarTemaSistem => 'System';

  @override
  String get ayarlarTemaAcik => 'Hell';

  @override
  String get ayarlarTemaKoyu => 'Dunkel';

  @override
  String get ayarlarTemaAciklama =>
      'Das dunkle Design gilt für alle Bildschirme; „System“ folgt der Geräteeinstellung.';

  @override
  String get ayarlarTesisAdi => 'Name der Anlage';

  @override
  String get ayarlarTesisAdiAciklama =>
      'Der Name, der auf dem Startbildschirm und in Berichten erscheint.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'Name der Anlage aktualisiert';

  @override
  String get ayarlarKameralar => 'Kameras';

  @override
  String get ayarlarKameralarAlt => 'Kameras hinzufügen, bearbeiten, löschen';

  @override
  String get ayarlarDil => 'Sprache / Language';

  @override
  String get dilSecBaslik => 'App-Sprache';

  @override
  String get kameraBaslik => 'Kameras';

  @override
  String get kameraEkle => 'Kamera hinzufügen';

  @override
  String get kameraYeni => 'Neue Kamera';

  @override
  String get kameraDuzenleBaslik => 'Kamera bearbeiten';

  @override
  String get kameraAd => 'Name';

  @override
  String get kameraKonum => 'Standort (optional)';

  @override
  String get kameraTur => 'Typ';

  @override
  String get kameraUrl => 'Stream-URL';

  @override
  String get kameraAktif => 'Aktiv';

  @override
  String get kameraAktifAlt => 'Ausgeschaltet in keiner Liste sichtbar';

  @override
  String get kameraSakinGorebilir => 'Für Bewohner sichtbar';

  @override
  String get kameraSakinGorebilirAlt =>
      'Ausgeschaltet sehen nur Verwaltung und Sicherheit die Kamera';

  @override
  String get kameraRtspFormUyari =>
      'RTSP-Streams können in der App noch nicht abgespielt werden. Der Eintrag wird gespeichert; Wiedergabe folgt später.';

  @override
  String get kameraUrlZorunlu => 'Stream-Adresse ist erforderlich';

  @override
  String kameraUrlHataHttp(Object tur) {
    return '$tur-Stream-Adresse muss mit http:// oder https:// beginnen';
  }

  @override
  String get kameraUrlHataRtsp =>
      'RTSP-Stream-Adresse muss mit rtsp:// beginnen';

  @override
  String get kameraSilBaslik => 'Kamera löschen';

  @override
  String kameraSilOnay(Object ad) {
    return '„$ad“ löschen?';
  }

  @override
  String get kameraBosYonetim => 'Noch keine Kameras. Unten rechts hinzufügen.';

  @override
  String get kameraBosSakin => 'Für Sie ist keine Kamera freigegeben.';

  @override
  String get kameraListeHata => 'Kameras konnten nicht geladen werden.';

  @override
  String get kameraCanli => 'Live';

  @override
  String get kameraOynatilamiyor => 'Nicht abspielbar';

  @override
  String get kameraYayinAcilamadi => 'Stream konnte nicht geöffnet werden';

  @override
  String get kameraYayinAcilamadiAlt =>
      'Die Kamera ist möglicherweise aus oder das Netzwerk erreicht den Stream nicht.';

  @override
  String kameraTurEtiket(Object tur) {
    return 'Typ: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP-Streams können derzeit nicht in der App abgespielt werden. Der Eintrag bleibt im System; Wiedergabe folgt später.';

  @override
  String get kameraSeritBaslik => 'Live-Kamera';

  @override
  String anaKarsilama(String ad) {
    return 'Hallo, $ad';
  }
}
