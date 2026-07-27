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
  String devriyeNoktaSayaci(Object beklenen, Object okutulan) {
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
  String sureSaatDakika(Object dakika, Object saat) {
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
  String devriyeNoktaOkutuldu(Object beklenen, Object okutulan) {
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
}
