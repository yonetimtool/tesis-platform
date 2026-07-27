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

  @override
  String get gorevKategorilerTooltip => 'Kategorien';

  @override
  String get gorevYeni => 'Neue Aufgabe';

  @override
  String get gorevOlusturuldu => 'Aufgabe erstellt ✓';

  @override
  String get gorevListesiYetkiYok =>
      'Sie haben keine Berechtigung für die Aufgabenliste. Dieser Bildschirm ist für die Rollen Reinigung und Sicherheit freigegeben.';

  @override
  String get gorevBuFiltredeYok => 'Keine aktiven Aufgaben mit diesem Filter.';

  @override
  String get gorevCipBanaAtanan => 'Mir zugewiesen';

  @override
  String get gorevCipTumGorevler => 'Alle Aufgaben';

  @override
  String get gorevCipTumu => 'Alle';

  @override
  String get gorevKategoriDiger => 'Sonstige';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Geplant: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Dir zugewiesen';

  @override
  String get gorevFotoZorunlu => 'Foto erforderlich';

  @override
  String get gorevTamamlandiZatenKayitli => 'Erledigt ✓ (war bereits erfasst)';

  @override
  String get gorevTamamlandiBuOturumda => 'Erledigt ✓ (in dieser Sitzung)';

  @override
  String get gorevIslemleriTooltip => 'Aufgabenaktionen';

  @override
  String get gorevTakipGorunumu => 'Überwachungsansicht';

  @override
  String get gorevTakipGorunumuAlt =>
      'Der Abschluss erfolgt durch Außendienstmitarbeiter (Sicherheit / Haustechniker). Dieser Bildschirm dient der Überwachung.';

  @override
  String get gorevGonderiliyor => 'Wird gesendet...';

  @override
  String get gorevTamamla => 'Abschließen';

  @override
  String get gorevGuncellendi => 'Aufgabe aktualisiert ✓';

  @override
  String get gorevSilinsinMi => 'Aufgabe löschen?';

  @override
  String get gorevSilindi => 'Aufgabe gelöscht ✓';

  @override
  String get gorevNfcAciklama =>
      'Diese Aufgabe ist NFC-verifiziert: Scannen Sie vor dem Abschluss das Tag am Aufgabenpunkt.';

  @override
  String get gorevAdim1Etiket => '1. Tag scannen';

  @override
  String gorevOkundu(Object uid) {
    return 'Gelesen: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'Warte auf Tag...';

  @override
  String get gorevYenidenOkut => 'Erneut scannen';

  @override
  String get gorevEtiketiOkut => 'Tag scannen';

  @override
  String get gorevAdim2Foto => '2. Fotonachweis';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Fotonachweis (optional)';

  @override
  String get gorevYukleniyorNokta => 'Wird hochgeladen...';

  @override
  String get gorevYuklendi => 'Hochgeladen ✓';

  @override
  String get gorevKamera => 'Kamera';

  @override
  String get gorevYenidenCek => 'Neu aufnehmen';

  @override
  String get gorevGaleridenSec => 'Aus Galerie wählen';

  @override
  String get gorevTekrarYukle => 'Erneut hochladen';

  @override
  String get gorevKaldir => 'Entfernen';

  @override
  String get gorevAdim3Not => '3. Notiz (optional)';

  @override
  String get gorevNotIpucu => 'Z. B. Mülltonnen geleert';

  @override
  String get gorevZatenKayitliydi =>
      'Dieser Abschluss war bereits erfasst (erneutes Senden — kein Duplikat entstanden).';

  @override
  String get gorevTamamlandiKayit =>
      'Aufgabe abgeschlossen — Eintrag erstellt.';

  @override
  String gorevZaman(Object zaman) {
    return 'Zeit: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'Fotonachweis vorhanden';

  @override
  String get gorevNfcDogrulandi => 'NFC verifiziert';

  @override
  String get gorevYeniTamamlamaBaslat => 'Neuen Abschluss starten';

  @override
  String get gorevDuzenleBaslik => 'Aufgabe bearbeiten';

  @override
  String get gorevKategoriSilinmis => 'Kategorie (gelöscht)';

  @override
  String get gorevAtananListedeDegil =>
      'Zugewiesener Benutzer (nicht in der Liste)';

  @override
  String get gorevTipleriYukleniyor => 'Aufgabentypen werden geladen...';

  @override
  String get gorevTipi => 'Aufgabentyp';

  @override
  String get gorevTipiYokUyari =>
      'Sie haben noch keine Aufgabentypen definiert. Eigene Typen können Sie oben unter \"Kategorien\" hinzufügen; vorläufig wird \"Sonstige\" verwendet.';

  @override
  String get gorevAdi => 'Aufgabenname';

  @override
  String get gorevAdiZorunlu => 'Aufgabenname ist erforderlich';

  @override
  String get gorevAciklamaOpsiyonel => 'Beschreibung (optional)';

  @override
  String get gorevPersonelYukleniyor => 'Personalliste wird geladen...';

  @override
  String get gorevAtananPersonel => 'Zugewiesenes Personal';

  @override
  String get gorevAtanmamisHavuz => '— nicht zugewiesen (Pool-Aufgabe) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'Personalliste konnte nicht geladen werden: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel => 'Kontrollpunkt (NFC) — optional';

  @override
  String get gorevKontrolNoktasiYardim =>
      'Wenn verknüpft, wird die Aufgabe per NFC-Scan abgeschlossen';

  @override
  String get gorevNfcYok => '— kein NFC —';

  @override
  String get gorevPeriyotDakika => 'Intervall in Minuten (optional)';

  @override
  String get gorevPeriyotYardim =>
      'Für wiederkehrende Aufgaben; leer = einmalig';

  @override
  String get gorevPozitifSayi => 'Geben Sie eine positive ganze Zahl ein';

  @override
  String get gorevFotoKanitiZorunlu => 'Fotonachweis erforderlich';

  @override
  String get gorevFotoKanitiZorunluAlt =>
      'Der Abschluss wird ohne Foto nicht akzeptiert';

  @override
  String get gorevPasifAciklama =>
      'Inaktive Aufgaben erscheinen nicht in der Liste';

  @override
  String get gorevKategorileriBaslik => 'Aufgabenkategorien';

  @override
  String get gorevKategoriYeni => 'Neue Kategorie';

  @override
  String get gorevKategoriAdi => 'Kategoriename';

  @override
  String get gorevKategoriAdiIpucu => 'z. B. Poolpflege';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '\"$ad\" hinzugefügt';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'Hinzufügen fehlgeschlagen: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'Kategorie löschen?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '\"$ad\" wird deaktiviert; die Historie bestehender Aufgaben bleibt erhalten, für neue Aufgaben ist sie nicht wählbar.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '\"$ad\" gelöscht';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'Löschen fehlgeschlagen: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'Liste konnte nicht geladen werden: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'Noch keine Kategorien. Fügen Sie über \"Neue Kategorie\" eine hinzu, damit sie beim Erstellen einer Aufgabe wählbar ist.';

  @override
  String get gorevOncelikDusuk => 'Niedrig';

  @override
  String get gorevOncelikOrta => 'Mittel';

  @override
  String get gorevOncelikYuksek => 'Hoch';

  @override
  String get gorevOncelik => 'Priorität';

  @override
  String get gorevTaleptenGeldi => 'Aus einer Anfrage';

  @override
  String get gorevBagliTalep => 'Verknüpfte Anfrage';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Einheit $daire';
  }

  @override
  String get talepDurumAcik => 'Offen';

  @override
  String get talepDurumIsEmri => 'Arbeitsauftrag';

  @override
  String get talepDurumCozuldu => 'Gelöst';

  @override
  String get talepDurumReddedildi => 'Abgelehnt';

  @override
  String get gorevEtiketOkunamadi => 'Tag konnte nicht gelesen werden.';

  @override
  String get gorevFotoOnlineGerekli =>
      'Für den Foto-Upload ist eine Internetverbindung erforderlich (die Upload-Adresse ist kurzlebig). Sobald die Verbindung steht, nutzen Sie \"Erneut hochladen\".';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'Foto konnte nicht abgerufen werden: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'Für den Foto-Upload ist eine Internetverbindung erforderlich.';

  @override
  String get gorevFotoZorunluUyari =>
      'Für diese Aufgabe ist ein FOTONACHWEIS ERFORDERLICH. Machen und laden Sie vor dem Abschluss ein Foto hoch.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'Das Foto ist noch nicht hochgeladen. Warten Sie das Ende des Uploads ab, versuchen Sie \"Erneut hochladen\" oder entfernen Sie das Foto.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'Der Abschluss konnte nicht gesendet werden — eine Internetverbindung ist erforderlich. Sobald die Verbindung steht, tippen Sie erneut auf \"Abschließen\"; derselbe Eintrag wird nicht doppelt erzeugt (der Idempotency-Key bleibt gleich). Abschluss mit Foto wird offline nicht unterstützt (bekannte Einschränkung).';

  @override
  String get rolAdmin => 'Plattform-Admin';

  @override
  String get rolYonetici => 'Objektverwalter';

  @override
  String get rolGuvenlik => 'Sicherheit';

  @override
  String get rolTesisGorevlisi => 'Haustechniker';

  @override
  String get rolSakin => 'Bewohner';

  @override
  String get rolBilinmeyen => 'Unbekannte Rolle';

  @override
  String get ortakOlustur => 'Erstellen';

  @override
  String get ortakGuncelle => 'Aktualisieren';

  @override
  String get ortakYenile => 'Aktualisieren';

  @override
  String get devriyeGonderimKuyruguTooltip => 'Sendewarteschlange';

  @override
  String get sekmeGecmis => 'Verlauf';

  @override
  String get devriyeYetkiYok =>
      'Sie haben keine Berechtigung für die Daten dieses Bildschirms. Die Rundgangverfolgung ist für die Rolle Sicherheit (und Verwalter) freigegeben.';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Letzte Aktualisierung: $saat (automatisch: 60 s)';
  }

  @override
  String get devriyeTuru => 'Rundgang';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'Ende $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Zeitfenster: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen Punkte';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'Alle Punkte gescannt — der Rundgang wird abgeschlossen. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Auf dem Server sind $n Scans erfasst (Scans anderer Geräte können enthalten sein).',
      one:
          'Auf dem Server ist $n Scan erfasst (Scans anderer Geräte können enthalten sein).',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Punkt scannen (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Weitere Rundgänge heute';

  @override
  String get devriyeBugununTurlari => 'Heutige Rundgänge';

  @override
  String get devriyeDurumTamamlandi => 'Abgeschlossen';

  @override
  String get devriyeDurumKacirildi => 'Verpasst';

  @override
  String get devriyeDurumSimdiAktif => 'Jetzt aktiv';

  @override
  String get devriyeDurumYaklasan => 'Bevorstehend';

  @override
  String get devriyeDurumBitti => 'Beendet';

  @override
  String get devriyeDurumBekliyor => 'Ausstehend';

  @override
  String get devriyeDurumBilinmiyor => 'Unbekannt';

  @override
  String get devriyeDurumSuresiGecti => 'Zeit abgelaufen';

  @override
  String get devriyeBugunTurYok => 'Für heute kein Rundgang.';

  @override
  String get devriyeNoktaListesiYok =>
      'Die Punktliste dieses Plans konnte nicht geladen werden oder dem Plan sind keine Punkte zugewiesen.';

  @override
  String get devriyeKontrolNoktalari => 'Kontrollpunkte';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Punktstatus kommen vom Server; Scans aller Mitarbeiter erscheinen als ✓. Zeilen mit \"Wird gesendet\" sind noch nicht gesendete Scans dieses Geräts.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Punkt $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Gescannt ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Gescannt ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor =>
      'Gescannt ✓ — wird gesendet (in Warteschlange)';

  @override
  String get devriyePencereSuresiDoldu => 'Das Zeitfenster ist abgelaufen.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Restzeit: $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat Std $dakika Min';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika Min $saniye S';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye S';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'Sie haben keine Berechtigung für den Rundgangverlauf. Diese Liste ist für die Rollen Sicherheit und Verwalter freigegeben.';

  @override
  String get devriyeGecmisBos => 'Noch keine Rundgang-Zeitfenster erfasst.';

  @override
  String get devriyeOzetToplam => 'Gesamt';

  @override
  String get devriyePlanlariBaslik => 'Rundgangspläne';

  @override
  String get devriyePlanEkle => 'Plan hinzufügen';

  @override
  String get devriyePlanlarListelenemedi =>
      'Pläne konnten nicht aufgelistet werden.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · alle $dakika Min';
  }

  @override
  String get devriyePasif => 'Inaktiv';

  @override
  String get devriyePlanSilinsinMi => 'Plan löschen?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'Der Rundgangsplan \"$ad\" wird gelöscht.';
  }

  @override
  String get devriyePlanSilindi => 'Plan gelöscht ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Rundgangsplan bearbeiten';

  @override
  String get devriyePlanYeniBaslik => 'Neuer Rundgangsplan';

  @override
  String get devriyePlanAdi => 'Planname';

  @override
  String get devriyePlanAdiIpucu => 'z. B. Nachtrundgang';

  @override
  String get devriyeAdZorunlu => 'Name ist erforderlich';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Beginn $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'Ende $saat';
  }

  @override
  String get devriyeTurSikligi => 'Rundgangsintervall (Minuten)';

  @override
  String get devriyeTurSikligiYardim => 'z. B. 60 = ein Rundgang pro Stunde';

  @override
  String get devriyeTurSikligiPozitif =>
      'Das Rundgangsintervall (Min) muss positiv sein.';

  @override
  String get devriyeTumunuKaldir => 'Alle entfernen';

  @override
  String get devriyeTumunuSec => 'Alle auswählen';

  @override
  String get devriyeAktifNoktaYok =>
      'Keine aktiven Kontrollpunkte. Fügen Sie zuerst unter \"Kontrollpunkte\" einen hinzu.';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get devriyeKaydedilemedi =>
      'Speichern fehlgeschlagen. Versuchen Sie es erneut.';

  @override
  String get devriyePlanYokBos =>
      'Noch keine Rundgangspläne.\nFügen Sie unten rechts einen hinzu (Zeiten + Punkte).';

  @override
  String get devriyeTakibiBaslik => 'Rundgangverfolgung';

  @override
  String get sekmeBugun => 'Heute';

  @override
  String get sekmeTaramaGunlugu => 'Scan-Protokoll';

  @override
  String get devriyeTakibiYetkiYok =>
      'Sie haben keine Berechtigung für die Rundgangverfolgung. Dieser Bildschirm ist für die Rollen Verwalter und Sicherheit freigegeben.';

  @override
  String get devriyeBugunPencereYok =>
      'Für heute ist kein Rundgang-Zeitfenster geplant.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen Punkte gescannt';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi =>
      'Scan-Protokoll konnte nicht geladen werden.';

  @override
  String get devriyeGunOkutmaYok => 'Für diesen Tag keine Scans.';

  @override
  String get devriyeImzali => 'signiert ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Scans warten auf Versand',
      one: '$n Scan wartet auf Versand',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'Abbrechen';

  @override
  String get ortakNotOpsiyonel => 'Notiz (optional)';

  @override
  String get binaDuzenlemeBaslik => 'Gebäudeaufbau';

  @override
  String get binaBlokTile => 'Block';

  @override
  String get binaBlokAtanmamis => 'Kein Block zugewiesen';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Block $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Gebäudestruktur (nur Ansicht). Tippen Sie auf eine Blockkachel, um Etagen- und Wohnungsaufteilung zu sehen.';

  @override
  String get binaDuzenlemeAciklama =>
      'Fügen Sie einen Block hinzu, tippen Sie auf die Kachel und platzieren Sie Etagen und Wohnungen. Jede Wohnung gehört zu einem Block. Die Beschwerdekarte spiegelt diese Struktur.';

  @override
  String binaDaireSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wohnungen',
      one: '$n Wohnung',
    );
    return '$_temp0';
  }

  @override
  String get binaKayitsiz => 'nicht erfasst';

  @override
  String get binaBloksuzDairelerSalt =>
      'Wohnungen ohne Blockzuordnung (nur Ansicht).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Block $ad — Etagen- und Wohnungsaufteilung (nur Ansicht).';
  }

  @override
  String get binaBloksuzUyari =>
      'Diese Wohnungen sind keinem Block zugeordnet (Altdaten). Sie werden angezeigt und können bearbeitet oder gelöscht werden; für eine neue Wohnung wählen oder erstellen Sie einen Block.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Block $ad — Etagen hinzufügen, dann Wohnungen über die \"+\"-Taste jeder Etage. Wohnungen derselben Etage stehen nebeneinander.';
  }

  @override
  String get binaKatEkle => 'Etage hinzufügen';

  @override
  String get binaTopluDaireEkle => 'Wohnungen im Block anlegen';

  @override
  String get binaBloktaDaireYok => 'In diesem Block noch keine Wohnungen.';

  @override
  String get binaKatYokBos =>
      'Noch keine Etagen. Beginnen Sie mit \"Etage hinzufügen\", dann Wohnungen über das \"+\" der Etage.';

  @override
  String get binaKatYok => 'Keine Etage';

  @override
  String binaKatEtiket(Object kat) {
    return 'Etage $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Block $ad — bearbeiten';
  }

  @override
  String get binaBloguSil => 'Block löschen';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Wird mit $n Wohnungen gelöscht (Bestätigung erforderlich)',
      one: 'Wird mit $n Wohnung gelöscht (Bestätigung erforderlich)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'Block $ad löschen?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Block $ad und $n Wohnungen gelöscht.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Block $ad gelöscht.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'Block konnte nicht gelöscht werden: $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'Block konnte nicht gelöscht werden. Bitte erneut versuchen.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'Dieser Block und seine $n Wohnungen werden ENDGÜLTIG gelöscht — samt Beitrags-, Besucher-, Paket-, Reservierungs- und Beschwerdedaten. Nicht rückgängig zu machen.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'Zum Bestätigen den Blocknamen eingeben';

  @override
  String binaSilNDaire(Object n) {
    return 'Löschen ($n Wohnungen)';
  }

  @override
  String get binaBlokEtiketiGerekli =>
      'Blockbezeichnung erforderlich (z. B. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar =>
      'Diese Blockbezeichnung ist bereits vergeben.';

  @override
  String get binaBlokDuzenle => 'Block bearbeiten';

  @override
  String get binaYeniBlok => 'Neuer Block';

  @override
  String get binaBlokEtiketi => 'Blockbezeichnung';

  @override
  String get binaBlokEtiketiYardim =>
      'Kurz alphanumerisch (z. B. A, B1) — kein Bindestrich';

  @override
  String get binaDaireNoGerekli =>
      'Wohnungsnummer erforderlich (z. B. A-12, 12).';

  @override
  String get binaKatSiraTamSayi =>
      'Etage und Position müssen ganze Zahlen sein.';

  @override
  String get binaDaireNoZatenVar =>
      'Diese Wohnungsnummer ist bereits vergeben.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Wohnung $no — bearbeiten';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'Neue Wohnung · $blok';
  }

  @override
  String get binaDaireNo => 'Wohnungsnummer';

  @override
  String get binaDaireNoYardim =>
      'Alphanumerisch + Bindestrich (z. B. A-12, B3, 12)';

  @override
  String get binaSira => 'Position';

  @override
  String get binaSiraYardim => 'Position auf der Etage';

  @override
  String binaEnFazla500(Object n) {
    return 'Maximal 500 Wohnungen (aktuell $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam Wohnungen, $kat Etagen × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Etagenanzahl, Wohnungen pro Etage und Startnummer sind erforderlich.';

  @override
  String get binaTekSeferde500 => 'Höchstens 500 Wohnungen auf einmal.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n bereits vorhanden, übersprungen)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return '$n Wohnungen hinzugefügt ✓$ek';
  }

  @override
  String get binaEklenemedi => 'Hinzufügen fehlgeschlagen. Erneut versuchen.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Wohnungen im Block anlegen — Block $blok';
  }

  @override
  String get binaTopluBaslikBloksuz =>
      'Wohnungen im Block anlegen — ohne Block';

  @override
  String get binaTopluAciklama =>
      'Die Nummern laufen ab der Startnummer fortlaufend, Etage für Etage. Vorhandene werden übersprungen.';

  @override
  String get binaKatSayisi => 'Etagenanzahl';

  @override
  String get binaKatBasinaDaire => 'Wohnungen pro Etage';

  @override
  String get binaBaslangicNo => 'Startnummer';

  @override
  String get binaBaslangicNoIpucu => 'z. B. 101';

  @override
  String get binaDaireleriOlustur => 'Wohnungen anlegen';

  @override
  String get binaSilinemedi =>
      'Löschen fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get binaKaydedilemedi =>
      'Speichern fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get semaDaireYok => 'Noch keine Wohnungen.';

  @override
  String get semaYogunluk => 'Dichte:';

  @override
  String get semaYerlesimAciklama =>
      'Gebäudeaufteilung. Die Beschwerdedichte wird nur der Verwaltung angezeigt.';

  @override
  String get semaYerlesimGirilmemis => 'Aufteilung nicht auf der Karte erfasst';

  @override
  String semaDaireEtiket(Object no) {
    return 'Wohnung $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n offene Beschwerden',
      one: '$n offene Beschwerde',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Ihre Beschwerden zu dieser Wohnung';

  @override
  String get semaYogunlukYonetim =>
      'Die Beschwerdedichte wird nur der Verwaltung angezeigt.';

  @override
  String get semaBuDaireyiSikayetEt => 'Diese Wohnung melden';

  @override
  String get semaSikayetIletildi => 'Ihre Beschwerde wurde übermittelt.';

  @override
  String get semaSikayetlerYuklenemedi =>
      'Beschwerden konnten nicht geladen werden.';

  @override
  String get semaAcikSikayetYok =>
      'Keine offenen Beschwerden für diese Wohnung.';

  @override
  String get semaSikayetlerimYuklenemedi =>
      'Ihre Beschwerden konnten nicht geladen werden.';

  @override
  String get semaSikayetimYok =>
      'Sie haben keine Beschwerden zu dieser Wohnung.';

  @override
  String get semaYonetimeIletildi => 'An die Verwaltung übermittelt';

  @override
  String get semaKapatildi => 'Geschlossen';

  @override
  String get semaHaftalikSinir =>
      'Zu diesem Thema können Sie für diese Wohnung höchstens 1 Beschwerde pro Woche einreichen.';

  @override
  String get semaKendiBlok =>
      'Sie können nur Wohnungen in Ihrem eigenen Block melden.';

  @override
  String get semaGonderilemedi =>
      'Senden fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Wohnung $no — melden';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Ihre Beschwerde geht an die Verwaltung; Nachbarn sehen sie nicht.';

  @override
  String get semaSikayetiGonder => 'Beschwerde senden';

  @override
  String get kategoriGurultu => 'Lärm';

  @override
  String get kategoriKapiOnuAyakkabi => 'Türbereich / Schuhe';

  @override
  String get kategoriZararVerme => 'Sachbeschädigung';

  @override
  String talepSekmeAcik(Object n) {
    return 'Offen ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'Arbeitsauftrag ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Gelöst ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Abgelehnt ($n)';
  }

  @override
  String get talepYeni => 'Neue Anfrage';

  @override
  String get talepAcikYokSakin =>
      'Sie haben keine offenen Anfragen. Mit \"Neue Anfrage\" können Sie eine Anfrage oder Störung melden.';

  @override
  String get talepAcikYok => 'Keine offenen Anfragen.';

  @override
  String get talepIsEmriYok =>
      'Keine Anfragen, die zu einem Arbeitsauftrag wurden.';

  @override
  String get talepCozulenYok => 'Noch keine gelösten Anfragen.';

  @override
  String get talepReddedilenYok => 'Keine abgelehnten Anfragen.';

  @override
  String get talepIletildi => 'Ihre Anfrage wurde übermittelt ✓';

  @override
  String get talepDurumGecmisi => 'Statusverlauf';

  @override
  String get talepGorselYuklenemedi => 'Bild konnte nicht geladen werden';

  @override
  String get talepIsEmriAtandi => 'Zugewiesen';

  @override
  String get talepIsEmriTamamlandi => 'Abgeschlossen';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Status unbekannt';

  @override
  String get talepIsEmri => 'Arbeitsauftrag';

  @override
  String get talepYeniBaslik => 'Neue Anfrage / Störung';

  @override
  String get talepBaslikAlan => 'Titel';

  @override
  String get talepBaslikZorunlu => 'Titel ist erforderlich';

  @override
  String get talepAciklamaAlan => 'Beschreibung';

  @override
  String get talepAciklamaZorunlu => 'Beschreibung ist erforderlich';

  @override
  String get talepGonder => 'Senden';

  @override
  String get talepKategoriOpsiyonel => 'Kategorie (optional)';

  @override
  String get talepKategoriYok =>
      'Keine Kategorien definiert; die Anfrage wird als \"Sonstige\" geöffnet.';

  @override
  String get talepGorseller => 'Bilder (optional, max. 3)';

  @override
  String get talepYoneticiIslemleri => 'Verwalteraktionen';

  @override
  String get talepIsEmrineDonusturuldu =>
      'Anfrage in Arbeitsauftrag umgewandelt ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'In Arbeitsauftrag umwandeln';

  @override
  String get talepCozuldu => 'Anfrage gelöst ✓';

  @override
  String get talepCoz => 'Lösen';

  @override
  String get talepReddedildiBildirim => 'Anfrage abgelehnt ✓';

  @override
  String get talepReddet => 'Ablehnen';

  @override
  String get talepReddediliyor => 'Wird abgelehnt...';

  @override
  String get talepPersonelAlinamadiKisa =>
      'Personalliste konnte nicht geladen werden.';

  @override
  String get talepIsEmrineDonustur => 'In Arbeitsauftrag umwandeln';

  @override
  String get talepAtanabilirPersonelYok =>
      'Kein aktives Außendienstpersonal zum Zuweisen. Fügen Sie zum Umwandeln zuerst Sicherheit oder Haustechniker hinzu.';

  @override
  String get talepDonusturuluyor => 'Wird umgewandelt...';

  @override
  String get talepDonustur => 'Umwandeln';

  @override
  String get talepReddetBaslik => 'Anfrage ablehnen';

  @override
  String get talepRetSebebiNot =>
      'Der Ablehnungsgrund ist für den Antragsteller im Statusverlauf sichtbar.';

  @override
  String get talepRetSebebi => 'Ablehnungsgrund';

  @override
  String get talepCozBaslik => 'Anfrage lösen';

  @override
  String get talepCozNot =>
      'Die Anfrage wird direkt als gelöst markiert, ohne Arbeitsauftrag.';

  @override
  String get talepCozumNotu => 'Lösungsnotiz (optional)';

  @override
  String get talepKategorilerYuklenemedi =>
      'Kategorien konnten nicht geladen werden.';

  @override
  String get talepFotoYuklenemedi => 'Foto konnte nicht hochgeladen werden.';

  @override
  String get binaKat => 'Etage';

  @override
  String get binaKatYardim => '0 = Erdgeschoss';

  @override
  String get binaBloksuz => 'Ohne Block';

  @override
  String get talepAcanSakin => 'Bewohner';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Reservierungen ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Bereiche ($n)';
  }

  @override
  String get rezYokSakin =>
      'Sie haben keine Reservierungen. Wählen Sie im Tab \"Bereiche\" einen Bereich und buchen Sie einen freien Slot.';

  @override
  String get rezYok => 'Keine Reservierungen.';

  @override
  String get rezYeniAlan => 'Neuer Bereich';

  @override
  String get rezAlanEklendi => 'Gemeinschaftsbereich hinzugefügt ✓';

  @override
  String get rezAlanGuncellendi => 'Bereich aktualisiert ✓';

  @override
  String get rezOrtakAlan => 'Gemeinschaftsbereich';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi Personen';
  }

  @override
  String get rezIptalEdildi => 'Storniert';

  @override
  String get rezIptalEdilsinMi => 'Reservierung stornieren?';

  @override
  String get rezIptalUyari =>
      'Der Slot wird wieder frei; dies kann nicht rückgängig gemacht werden.';

  @override
  String get rezEvetIptalEt => 'Ja, stornieren';

  @override
  String get rezIptalEdildiBildirim => 'Reservierung storniert';

  @override
  String get rezIptalGonderilemedi =>
      'Storno konnte nicht gesendet werden. Erneut versuchen.';

  @override
  String get rezIptalEt => 'Stornieren';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Datum: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Personenanzahl: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Gebucht: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Notiz: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'Noch keine Gemeinschaftsbereiche. Fügen Sie einen über \"Neuer Bereich\" hinzu.';

  @override
  String get rezAlanYokGoruntuleme =>
      'Keine Gemeinschaftsbereiche zum Anzeigen.';

  @override
  String get rezAlanYokSakin => 'Keine buchbaren Bereiche.';

  @override
  String rezMusait(Object ozet) {
    return 'Verfügbar: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · $dakika-Min-Slots';
  }

  @override
  String get rezAcikDuzenle => 'Offen · zum Bearbeiten tippen';

  @override
  String get rezKapaliDuzenle => 'Geschlossen · zum Bearbeiten tippen';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Verfügbar: $ozet · zum Anzeigen der Slots tippen';
  }

  @override
  String get rezPasifAlan => 'Inaktiv (nicht buchbar)';

  @override
  String get rezKapanisSonra =>
      'Die Schließzeit muss nach der Öffnungszeit liegen.';

  @override
  String get rezAlanEklenemedi =>
      'Bereich konnte nicht hinzugefügt werden. Erneut versuchen.';

  @override
  String get rezAlanDuzenle => 'Bereich bearbeiten';

  @override
  String get rezYeniOrtakAlan => 'Neuer Gemeinschaftsbereich';

  @override
  String get rezAlanAdi => 'Bereichsname * (z. B. Pool)';

  @override
  String get rezAlanAdiGerekli => 'Bereichsname ist erforderlich';

  @override
  String get rezMusaitlikHerGun => 'Verfügbarkeit (täglich)';

  @override
  String rezAcilis(Object saat) {
    return 'Öffnung: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Schließung: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Slot-Länge';

  @override
  String rezSlotDakika(Object n) {
    return '$n Minuten';
  }

  @override
  String get rezAlaniEkle => 'Bereich hinzufügen';

  @override
  String get rezSlotlarYuklenemedi =>
      'Slots konnten nicht geladen werden. Erneut versuchen.';

  @override
  String get rezOnaylandi => 'Ihre Reservierung ist bestätigt ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Datum: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'Ein Slot öffnet erst weniger als 24 Stunden vor Beginn; höchstens eine Reservierung pro Tag.';

  @override
  String get rezSlotYok => 'Für diesen Bereich sind keine Slots definiert.';

  @override
  String get rezBenimAktif => 'Meine Reservierung (aktiv)';

  @override
  String get rezBenimGecti => 'Meine Reservierung (vergangen)';

  @override
  String get rezDoluBaskasi => 'Belegt (jemand anderes)';

  @override
  String get rezSizinGecti => 'Ihre Reservierung (vergangen)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n Personen';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Belegt · Wohnung $daire$kisi';
  }

  @override
  String get rezBos => 'Frei';

  @override
  String get rezDolu => 'Belegt';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Wählen';

  @override
  String get rezGonderilemedi => 'Senden fehlgeschlagen. Erneut versuchen.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — buchen';
  }

  @override
  String get rezKisiSayisiEtiket => 'Personenanzahl:';

  @override
  String get rezEt => 'Buchen';

  @override
  String get rezDurumOnayli => 'Bestätigt';

  @override
  String get rezSebepDolu => 'belegt';

  @override
  String get rezSebepGecti => 'vergangen';

  @override
  String get rezSebepCokErken => 'öffnet in 24 Std';

  @override
  String get rezSebepGunluk => 'Tageslimit erreicht';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'Bevorstehend ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Vergangen ($n)';
  }

  @override
  String get etkYeni => 'Neue Veranstaltung';

  @override
  String get etkYaklasanYokYonetim =>
      'Keine bevorstehenden Veranstaltungen. Kündigen Sie eine über \"Neue Veranstaltung\" an.';

  @override
  String get etkYaklasanYok => 'Keine bevorstehenden Veranstaltungen.';

  @override
  String get etkGecmisYok => 'Keine vergangenen Veranstaltungen.';

  @override
  String get etkDuyuruldu =>
      'Veranstaltung angekündigt — Bewohner benachrichtigt ✓';

  @override
  String get etkGuncellendi => 'Veranstaltung aktualisiert ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nehmen teil',
      one: '$n nimmt teil',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nehmen nicht teil',
      one: '$n nimmt nicht teil',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Ihre Teilnahme: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Ihre Antwort wurde gespeichert: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi =>
      'Antwort konnte nicht gesendet werden. Erneut versuchen.';

  @override
  String get etkKatiliyorum => 'Ich nehme teil';

  @override
  String get etkKatilmiyorum => 'Ich nehme nicht teil';

  @override
  String etkZaman(Object aralik) {
    return 'Zeit: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Ort: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Angekündigt von: $ad';
  }

  @override
  String get etkSilinsinMi => 'Veranstaltung löschen?';

  @override
  String etkSilOnay(Object baslik) {
    return '\"$baslik\" und alle Teilnahmeantworten werden gelöscht.';
  }

  @override
  String get etkSilindi => 'Veranstaltung gelöscht ✓';

  @override
  String get etkBitisSonra => 'Das Ende muss nach dem Beginn liegen';

  @override
  String get etkKaydedilemedi => 'Speichern fehlgeschlagen. Erneut versuchen.';

  @override
  String get etkDuzenleBaslik => 'Veranstaltung bearbeiten';

  @override
  String get etkBaslikAlan => 'Titel * (z. B. Spielabend)';

  @override
  String get etkBaslikGerekli => 'Titel ist erforderlich';

  @override
  String get etkAciklamaAlan => 'Beschreibung *';

  @override
  String get etkAciklamaGerekli => 'Beschreibung ist erforderlich';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Zeit: $zaman';
  }

  @override
  String get etkBitisEkle => 'Ende hinzufügen (optional)';

  @override
  String etkBitis(Object zaman) {
    return 'Ende: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Ende entfernen';

  @override
  String get etkYerAlan => 'Ort (optional)';

  @override
  String get etkGorselAlan => 'Bild (optional)';

  @override
  String get etkDuyurVeBildir => 'Ankündigen und Bewohner benachrichtigen';

  @override
  String get izinBaslik => 'Anzeigeberechtigung';

  @override
  String get izinTumDairelere => 'Berechtigung für alle Wohnungen anfragen';

  @override
  String get izinYeniIstek => 'Neue Anfrage';

  @override
  String get izinIstekYokYonetim =>
      'Sie haben noch keine Berechtigungsanfragen. Nutzen Sie \"Neue Anfrage\" für eine Wohnung oder oben \"Alle Wohnungen\" für alle.';

  @override
  String get izinIstekYokSakin => 'Keine Anzeigeanfragen für Ihre Wohnung.';

  @override
  String get izinTumDaireUyari =>
      'Für jede Wohnung mit Bewohner wird eine Anzeigeanfrage gesendet. Jede Wohnung hängt von der Zustimmung ihres Bewohners ab — Sie sehen nur Daten zustimmender Wohnungen.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n bereits offen)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'Anfragen für $n Wohnungen gesendet$atlandi — warten auf Zustimmungen der Bewohner';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'Senden fehlgeschlagen: $hata';
  }

  @override
  String get izinIsteBaslik => 'Anzeigeberechtigung anfragen';

  @override
  String get izinDaireNo => 'Wohnungsnummer (z. B. A-12)';

  @override
  String get izinIstekGonder => 'Anfrage senden';

  @override
  String get izinIstekGonderildi =>
      'Anfrage gesendet — warten auf Zustimmung des Bewohners';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Anzeigeanfrage für Wohnung$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'Angefragt von: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'Die Berechtigung wurde genutzt (einmalig). Für erneute Ansicht neue Anfrage stellen.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Anzeigbare Wohnungen ($n)';
  }

  @override
  String get izinKullanildi => 'Genutzt';

  @override
  String get izinOnayli => 'Genehmigt';

  @override
  String get izinVerildi => 'Berechtigung erteilt';

  @override
  String get izinOnayla => 'Genehmigen';

  @override
  String get izinKargolar => 'Pakete';

  @override
  String izinKayitBaslik(Object baslik, Object daire) {
    return '$baslik$daire';
  }

  @override
  String izinDaireEki(Object daire) {
    return ' — $daire';
  }

  @override
  String get izinSuresiDoldu =>
      'Die Berechtigung wurde genutzt oder ist abgelaufen (einmalig). Stellen Sie für erneute Ansicht eine neue Anfrage.';

  @override
  String get izinTekSeferlikUyari =>
      'Ansicht mit Einmal-Berechtigung — beim Aktualisieren endet der Zugriff.';

  @override
  String get izinKayitYok => 'Keine Daten für diese Wohnung.';

  @override
  String izinHedef(Object ad) {
    return 'Empfänger: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Erfasst von: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Status: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Genehmigt';

  @override
  String get kargoDurumTeslimAlindi => 'Übergeben';

  @override
  String get rezSizin => 'Ihre Reservierung';

  @override
  String get butBaslik => 'Budget';

  @override
  String get butSekmeOzet => 'Übersicht';

  @override
  String get butSekmeHareketler => 'Buchungen';

  @override
  String get butSekmeKategoriler => 'Kategorien';

  @override
  String get butTumZamanlar => 'Gesamtzeitraum';

  @override
  String get butDonem => 'Zeitraum';

  @override
  String get butGelir => 'Einnahmen';

  @override
  String get butGider => 'Ausgaben';

  @override
  String get butKasa => 'Kasse';

  @override
  String get butKategoriKirilimi => 'Aufschlüsselung nach Kategorie';

  @override
  String get butYeniHareket => 'Neue Buchung';

  @override
  String get butHareketYok => 'Noch keine Buchungen.';

  @override
  String get butKategori => 'Kategorie';

  @override
  String get butOtomatik => 'Automatisch';

  @override
  String get butKategoriSecin => 'Kategorie wählen';

  @override
  String get butTutar => 'Betrag (TL)';

  @override
  String get butTutarIpucu => 'z. B. 1.250,50';

  @override
  String get butTutarGecersiz =>
      'Geben Sie einen gültigen Betrag ein (z. B. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Datum: $tarih';
  }

  @override
  String get butYeniKategori => 'Neue Kategorie';

  @override
  String get butKategoriYok => 'Noch keine Kategorien.';

  @override
  String get butKategoriAdi => 'Kategoriename';

  @override
  String get butKategoriAdiIpucu => 'z. B. Gartenpflege';

  @override
  String get butAdZorunlu => 'Name ist erforderlich';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · inaktiv (keine neuen Buchungen)';

  @override
  String get butBeklenmeyenKisa =>
      'Ein unerwarteter Fehler ist aufgetreten. Erneut versuchen.';

  @override
  String get butFinansalOzet => 'Finanzübersicht';

  @override
  String get butAidatTahsilati => 'Beitragseinzug';

  @override
  String get butEnYuksekGiderler => 'Größte Ausgaben';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Einzug $yuzde %';
  }

  @override
  String get butTahakkukYok =>
      'Für diesen Zeitraum keine Sollstellungen erfasst.';

  @override
  String get butSiteBaslik => 'Objektbudget';

  @override
  String get butKategoriToplamlari => 'Kategoriesummen';

  @override
  String get butSeffaflikNotu =>
      'Dieser Bildschirm zeigt Einnahmen und Ausgaben der Objektverwaltung als Übersicht — zur Transparenz. Personen- und wohnungsbezogene Details werden nicht angezeigt; bei Fragen wenden Sie sich an die Verwaltung.';

  @override
  String get demBaslik => 'Inventar';

  @override
  String get demEtiketOkut => 'Tag scannen';

  @override
  String get demBaskaEtiketOkut => 'Anderes Tag scannen';

  @override
  String demUzerimdekiler(Object ek) {
    return 'Bei mir$ek';
  }

  @override
  String get demNfcAciklama =>
      'Scannen Sie beim Ausleihen oder Zurückgeben das NFC-Tag am Gerät. Die App erkennt es und zeigt, wer es hat.';

  @override
  String get demTaniniyor => 'Gerät wird erkannt...';

  @override
  String get demKimsedeDegil => 'Bei niemandem — verfügbar.';

  @override
  String demSende(Object sure) {
    return 'BEI DIR — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'Bei $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'Scheint bei jemand anderem zu sein.';

  @override
  String get demBakimda => 'In Wartung — derzeit nicht ausleihbar.';

  @override
  String get demZorlaDevralmaYok =>
      'Keine erzwungene Übernahme — der aktuelle Inhaber muss es zurückgeben.';

  @override
  String get demZimmetineAl => 'Übernehmen';

  @override
  String get demBirak => 'Zurückgeben';

  @override
  String get demBirakKisa => 'Zurückgeben';

  @override
  String get demSonHareketler => 'Letzte Bewegungen';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad hat es genommen — $zaman (noch in Besitz)';
  }

  @override
  String get demListeYetkiYok =>
      'Sie haben keine Berechtigung für die Inventarliste.';

  @override
  String get demUzerindeYok => 'Derzeit haben Sie kein Inventar.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Genommen: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'seit einer Weile';

  @override
  String get demSureAzOnce => 'gerade erst';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'seit $n Minuten',
      one: 'seit $n Minute',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'seit $n Stunden',
      one: 'seit $n Stunde',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'seit $n Tagen',
      one: 'seit $n Tag',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'Eine Internetverbindung ist erforderlich. Der Besitz ist ein Echtzeit-Eintrag; offline wird nicht verarbeitet (eine Warteschlange wäre irreführend).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'Dieses Tag ($uid) passt zu keinem erfassten Gerät. Das Tag muss im Panel einem Gerät zugewiesen werden.';
  }

  @override
  String get demZatenZimmetinde =>
      'War bereits an Sie ausgegeben ✓ (erneutes Senden — kein Duplikat)';

  @override
  String get demZimmetineAlindi => 'Übernommen ✓';

  @override
  String get demBirakildi => 'Zurückgegeben ✓ — Ausgabe geschlossen.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'Aktion fehlgeschlagen: $hata Status aktualisiert — sehen Sie erneut auf die Karte.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Pakete';

  @override
  String karSekmeBekleyen(Object n) {
    return 'Ausstehend ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Abgeholt ($n)';
  }

  @override
  String get karYeni => 'Neues Paket';

  @override
  String get karBekleyenYokSakin => 'Sie haben keine abzuholenden Pakete.';

  @override
  String get karBekleyenYok => 'Keine abzuholenden Pakete.';

  @override
  String get karTeslimYok => 'Noch keine abgeholten Pakete erfasst.';

  @override
  String get karKaydedildi =>
      'Paket erfasst — Bewohner der Wohnung benachrichtigt ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Wohnung: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Wohnung: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Erfasst: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Notiz: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Paket als abgeholt markiert ✓';

  @override
  String get karIsaretlenemedi => 'Markieren fehlgeschlagen. Erneut versuchen.';

  @override
  String get karTeslimAldim => 'Ich habe es abgeholt';

  @override
  String get karGonderilemedi =>
      'Eintrag konnte nicht gesendet werden. Erneut versuchen.';

  @override
  String get karDaireNo => 'Wohnungsnummer * (z. B. A-12)';

  @override
  String get karDaireNoGerekli => 'Wohnungsnummer ist erforderlich';

  @override
  String get karFirma => 'Versanddienst *';

  @override
  String get karFirmaGerekli => 'Versanddienst ist erforderlich';

  @override
  String get karPaketFotografi => 'Paketfoto (optional)';

  @override
  String get karKaydetVeBildir => 'Speichern und Bewohner benachrichtigen';

  @override
  String get ortakTekrarDene => 'Erneut versuchen';

  @override
  String get butTahakkuk => 'Sollstellung';

  @override
  String get butTahsilat => 'Einzug';

  @override
  String get butGeciken => 'Überfällig';

  @override
  String demAldiBirakti(Object ad, Object alma, Object birakma) {
    return '$ad · $alma → $birakma';
  }

  @override
  String karAdEki(Object ad) {
    return ' — $ad';
  }

  @override
  String karZamanEki(Object zaman) {
    return ' · $zaman';
  }
}
