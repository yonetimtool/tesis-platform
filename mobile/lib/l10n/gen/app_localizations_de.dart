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

  @override
  String get kuralBaslik => 'Hausordnung';

  @override
  String get kuralYeni => 'Neue Regel';

  @override
  String get kuralAramaIpucu => 'In Titeln suchen (z. B. Pool)';

  @override
  String get kuralEklendi => 'Regel hinzugefügt ✓';

  @override
  String get kuralGuncellendi => 'Regel aktualisiert ✓';

  @override
  String get kuralAramaBos => 'Keine Regel passt zur Suche.';

  @override
  String get kuralYokYonetim =>
      'Noch keine Regeln. Über \"Neue Regel\" hinzufügen.';

  @override
  String get kuralYokSakin => 'Noch keine Regeln veröffentlicht.';

  @override
  String get kuralSilOnayBaslik => 'Regel löschen?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" wird endgültig gelöscht.';
  }

  @override
  String get kuralSilindi => 'Regel gelöscht ✓';

  @override
  String get kuralDuzenleBaslik => 'Regel bearbeiten';

  @override
  String get kuralBaslikAlan => 'Titel * (z. B. Pool-Zeiten)';

  @override
  String get kuralBaslikGerekli => 'Titel ist erforderlich';

  @override
  String get kuralMetni => 'Regeltext *';

  @override
  String get kuralMetniGerekli => 'Regeltext ist erforderlich';

  @override
  String get kuralSira => 'Reihenfolge (kleinste zuerst)';

  @override
  String get kuralSiraGecersiz =>
      'Reihenfolge muss 0 oder eine positive ganze Zahl sein';

  @override
  String get kuralMevcutGorsel => 'Vorhandenes Bild bleibt erhalten';

  @override
  String get kuralEkleButon => 'Regel hinzufügen';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'Zum Hochladen eines Fotos ist eine Internetverbindung nötig. Versuchen Sie es erneut, sobald Sie online sind.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'Das Foto ist noch nicht hochgeladen. Warten Sie das Ende des Uploads ab oder entfernen Sie das Foto.';

  @override
  String get duyuruYeni => 'Neue Ankündigung';

  @override
  String get duyuruYayinlandi => 'Ankündigung veröffentlicht ✓';

  @override
  String get duyuruGuncellendi => 'Ankündigung aktualisiert ✓';

  @override
  String get duyuruYok => 'Noch keine Ankündigungen.';

  @override
  String get duyuruYonetim => 'Verwaltung';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · bearbeitet';

  @override
  String get duyuruSilOnay => 'Ankündigung löschen?';

  @override
  String get duyuruSilindi => 'Ankündigung gelöscht ✓';

  @override
  String get duyuruDuzenleBaslik => 'Ankündigung bearbeiten';

  @override
  String get duyuruBaslikZorunlu => 'Titel ist Pflicht';

  @override
  String get duyuruMetniAlan => 'Text der Ankündigung';

  @override
  String get duyuruMetniZorunlu => 'Text der Ankündigung ist Pflicht';

  @override
  String get duyuruYayinla => 'Veröffentlichen';

  @override
  String get ortakIslemler => 'Aktionen';

  @override
  String get sakinBaslik => 'Bewohner';

  @override
  String get sakinEkle => 'Bewohner hinzufügen';

  @override
  String get sakinListelenemedi => 'Bewohner konnten nicht geladen werden.';

  @override
  String get sakinDaireYok => 'Keine Wohnung zugewiesen';

  @override
  String get sakinIslemleri => 'Bewohner-Aktionen';

  @override
  String get sakinParolaSifirla => 'Passwort zurücksetzen';

  @override
  String get sakinParolaSifirlaOnay => 'Passwort zurücksetzen?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'Für \"$ad\" wird ein neuer temporärer Code erzeugt; das alte Passwort wird ungültig. Der Nutzer meldet sich mit Telefon + neuem Code an und legt dann ein Passwort fest.';
  }

  @override
  String get sakinSifirla => 'Zurücksetzen';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'Neuer temporärer Code für \"$ad\". Geben Sie ihn dem Bewohner; er meldet sich mit Telefon + diesem Code an und legt ein Passwort fest.';
  }

  @override
  String get sakinSilOnay => 'Bewohner löschen?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" wird entfernt. Ohne Verlauf wird der Eintrag vollständig gelöscht, sonst inaktiv gesetzt. In jedem Fall wird die Telefonnummer frei (sie kann erneut registriert werden).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" gelöscht (Nummer frei)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" deaktiviert — hat Verlauf (Nummer frei)';
  }

  @override
  String get sakinDuzenleBaslik => 'Bewohner bearbeiten';

  @override
  String get sakinYeniTelefon => 'Neue Mobilnummer';

  @override
  String get sakinBosBirakDegismez =>
      'Leer lassen, um es unverändert zu lassen';

  @override
  String get sakinGuncellendi => 'Aktualisiert ✓';

  @override
  String get ortakAdSoyad => 'Vor- und Nachname';

  @override
  String get ortakCepTelefonu => 'Mobilnummer';

  @override
  String get ortakTelefonIpucu => 'z. B. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Telefon ist Pflicht';

  @override
  String get sakinGirisAnahtari => 'Anmeldeschlüssel (global eindeutig).';

  @override
  String get ortakDaireNoIpucu => 'z. B. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Wohnungsnummer ist Pflicht';

  @override
  String get sakinParolaOpsiyonel => 'Passwort (optional)';

  @override
  String get sakinBosBirakKod =>
      'Leer lassen, um einen temporären Code zu erzeugen';

  @override
  String get sakinEklendiKod =>
      'Bewohner hinzugefügt. Geben Sie ihm diesen Code; er meldet sich mit Telefon + diesem Code an und legt dann ein Passwort fest.';

  @override
  String get sakinEklendi => 'Bewohner hinzugefügt ✓';

  @override
  String get sakinYok => 'Noch keine Bewohner.\nUnten rechts hinzufügen.';

  @override
  String get ortakGeciciKodBaslik => 'Temporärer Anmeldecode';

  @override
  String get ortakKopyala => 'Kopieren';

  @override
  String get ortakKopyalandi => 'Kopiert';

  @override
  String get girisParolaVeyaKod => 'Passwort oder temporärer Code';

  @override
  String get girisIlkKodIpucu =>
      'Geben Sie bei der ersten Anmeldung den von der Verwaltung erhaltenen temporären Code ein.';

  @override
  String get girisBeniHatirla => 'Angemeldet bleiben';

  @override
  String get girisYap => 'Anmelden';

  @override
  String get girisOturumSonaErdi =>
      'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.';

  @override
  String get parolaBelirleBaslik => 'Legen Sie Ihr Passwort fest';

  @override
  String get parolaBelirleAciklama =>
      'Sie haben sich erstmals mit einem temporären Code angemeldet. Legen Sie zum Fortfahren ein eigenes dauerhaftes Passwort fest; künftig melden Sie sich mit Wohnungsnummer + diesem Passwort an.';

  @override
  String get parolaBelirleButon => 'Passwort festlegen';

  @override
  String get parolaGiriseDon => 'Zurück zur Anmeldung';

  @override
  String get ortakParolaZorunlu => 'Passwort ist Pflicht';

  @override
  String get ortakYeniParola => 'Neues Passwort';

  @override
  String get ortakYeniParolaTekrar => 'Neues Passwort (wiederholen)';

  @override
  String get ortakYeniParolaZorunlu => 'Neues Passwort ist Pflicht';

  @override
  String get ortakParolalarEslesmiyor => 'Passwörter stimmen nicht überein';

  @override
  String get parolaKuraliKisa => 'Muss mindestens 8 Zeichen haben';

  @override
  String get parolaKuraliBuyukHarf =>
      'Muss mindestens einen Großbuchstaben enthalten';

  @override
  String get parolaKuraliRakam => 'Muss mindestens eine Ziffer enthalten';

  @override
  String get parolaKuraliSembol =>
      'Muss mindestens ein Sonderzeichen enthalten (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'Profil konnte nicht geladen werden.';

  @override
  String get profilNumaraYok => 'Keine Nummer angegeben';

  @override
  String get profilFotoBaslik => 'Profilfoto';

  @override
  String get profilFotoSec => 'Foto wählen';

  @override
  String get profilFotoGuncellendi => 'Profilfoto aktualisiert ✓';

  @override
  String get profilFotoKaldirildi => 'Profilfoto entfernt';

  @override
  String get ortakGaleri => 'Galerie';

  @override
  String get profilParolaDegistir => 'Passwort ändern';

  @override
  String get profilMevcutParola => 'Aktuelles Passwort';

  @override
  String get profilMevcutParolaZorunlu => 'Aktuelles Passwort ist Pflicht';

  @override
  String get profilParolaGuncelle => 'Passwort aktualisieren';

  @override
  String get profilParolaGuncellendi => 'Passwort aktualisiert ✓';

  @override
  String get profilTelefon => 'Telefon';

  @override
  String get profilTelefonIpucu => 'z. B. +905551112233';

  @override
  String get profilAranabilir => 'Telefonisch erreichbar';

  @override
  String get profilAranabilirAlt =>
      'Berechtigte Rollen (Anruf mit Zustimmung) können Ihre Nummer erreichen';

  @override
  String get profilIletisimKaydet => 'Kontaktdaten speichern';

  @override
  String get profilIletisimGuncellendi => 'Kontaktdaten aktualisiert ✓';

  @override
  String get personelEkle => 'Mitarbeiter hinzufügen';

  @override
  String get personelDuzenle => 'Mitarbeiter bearbeiten';

  @override
  String get personelListelenemedi =>
      'Mitarbeiter konnten nicht geladen werden.';

  @override
  String get personelPasiflestir => 'Deaktivieren';

  @override
  String get personelAktiflestir => 'Aktivieren';

  @override
  String get personelPasiflestirildi => 'Deaktiviert ✓';

  @override
  String get personelAktiflestirildi => 'Aktiviert ✓';

  @override
  String personelSifirlaGovde(Object ad) {
    return 'Für $ad wird ein neuer temporärer Code erzeugt; das alte Passwort wird ungültig.';
  }

  @override
  String get personelYeniKodMesaji =>
      'Neuer temporärer Code. Geben Sie ihn dem Mitarbeiter; er meldet sich mit Telefon + diesem Code an und legt dann ein Passwort fest.';

  @override
  String get personelGuncellendi => 'Mitarbeiter aktualisiert ✓';

  @override
  String get personelEklendi => 'Mitarbeiter hinzugefügt ✓';

  @override
  String get personelEklendiKod =>
      'Mitarbeiter hinzugefügt. Geben Sie ihm diesen Code; er meldet sich mit Telefon + diesem Code an und legt dann ein Passwort fest.';

  @override
  String get personelFoto => 'Foto';

  @override
  String get personelTelefonOpsiyonel => 'Mobilnummer (optional)';

  @override
  String get personelBosBirakDegismezNokta =>
      'Leer lassen, um es unverändert zu lassen.';

  @override
  String get personelYok =>
      'Noch kein Außendienstpersonal.\nUnten rechts hinzufügen.';

  @override
  String get disKisiEkle => 'Kontakt hinzufügen';

  @override
  String get disListeAlinamadi => 'Liste konnte nicht geladen werden.';

  @override
  String get disKayitYokYonetim =>
      'Noch keine Einträge. Fügen Sie unten rechts einen Handwerker hinzu, dem Sie vertrauen.';

  @override
  String get disKayitYok => 'Noch keine externen Dienstleister erfasst.';

  @override
  String get disNotEkleyin =>
      'Notiz hinzufügen (nur die Verwaltung kann bearbeiten).';

  @override
  String get disNotuDuzenle => 'Notiz bearbeiten';

  @override
  String get disBolumNotu => 'Abschnittsnotiz';

  @override
  String get disNotIpucu =>
      'z. B. Handwerker, denen wir seit Jahren vertrauen; lassen Sie zur Sicherheit keine Fremden herein.';

  @override
  String get disNotGuncellendi => 'Notiz aktualisiert ✓';

  @override
  String get disAra => 'Anrufen';

  @override
  String get disSilOnay => 'Eintrag löschen?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" wird gelöscht.';
  }

  @override
  String get disSilindi => 'Gelöscht ✓';

  @override
  String get disYeniKisi => 'Neuer externer Kontakt';

  @override
  String get disKisiDuzenle => 'Kontakt bearbeiten';

  @override
  String get disTur => 'Art der Dienstleistung';

  @override
  String get disTurIpucu => 'z. B. Schlüsseldienst, Elektrik, Sanitär';

  @override
  String get disTurZorunlu => 'Art ist Pflicht';

  @override
  String get disAd => 'Vorname';

  @override
  String get disSoyad => 'Nachname';

  @override
  String get disAdGerekli => 'Vorname erforderlich';

  @override
  String get disSoyadGerekli => 'Nachname erforderlich';

  @override
  String get nfcBaslik => 'NFC-Tag lesen';

  @override
  String get nfcHazir => 'Bereit zum Lesen. Auf Start tippen.';

  @override
  String get nfcYaklastirBekliyor =>
      'Halten Sie das Tag an die Rückseite des Telefons...';

  @override
  String get nfcOkundu => 'Tag gelesen.';

  @override
  String get nfcOkumayaBasla => 'Lesen starten';

  @override
  String get nfcTekrarOku => 'Erneut lesen';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Scans warten auf Versand',
      one: '$n Scan wartet auf Versand',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'Sende-Warteschlange';

  @override
  String get nfcKaydedildiBekliyor =>
      'Gespeichert ✓ — wird automatisch gesendet, sobald Verbindung besteht.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Gespeichert ✓ — wird gesendet...';

  @override
  String get nfcGonderildiZatenVar =>
      'Gesendet ✓ — dieser Scan war bereits erfasst.';

  @override
  String get nfcGonderildi => 'Gesendet ✓ — Scan erfasst.';

  @override
  String get nfcEslesmeYok => 'Dieses Tag passt zu keinem Kontrollpunkt.';

  @override
  String get nfcSdmBaslik => 'SDM (roh, nicht verifiziert)';

  @override
  String get nfcTipEtiket => 'Typ';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'Kontrollpunkte konnten nicht geladen werden: $hata';
  }

  @override
  String get nfcTestBaslik => 'TEST: welchen Punkt scannen?';

  @override
  String get nfcTestAlt => 'Simuliert einen Scan ohne physisches Tag.';

  @override
  String get nfcAktifNoktaYok => 'Keine aktiven Kontrollpunkte.';

  @override
  String get nfcAktifNoktaYokAlt =>
      'Fügen Sie zuerst unter \"Kontrollpunkte\" einen hinzu.';

  @override
  String get nfcManuelOkut => 'Manueller Scan (Test)';

  @override
  String get nfcTestGorunur => 'Nur in Test-Builds sichtbar.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'NFC ist aus. Bitte aktivieren Sie NFC in den Geräteeinstellungen.';

  @override
  String get nfcHataDesteklenmiyor => 'Dieses Gerät unterstützt NFC nicht.';

  @override
  String get nfcHataUidOkunamadi => 'Die Tag-UID konnte nicht gelesen werden.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'Das Tag konnte nicht ausgewertet werden: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'Die NFC-Sitzung konnte nicht gestartet werden: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Lesen abgebrochen: $detay';
  }

  @override
  String get nfcHataBilinmeyen => 'Ein unbekannter Fehler ist aufgetreten.';

  @override
  String get nfcIosYaklastir =>
      'Halten Sie das Tag an die Rückseite des Telefons.';

  @override
  String get nfcIosOkundu => 'Gelesen';

  @override
  String get nfcIosIptal => 'Abgebrochen';

  @override
  String get nfcIosOkunamadi => 'Nicht lesbar';

  @override
  String get seffafYuklenemedi =>
      'Laden fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get seffafAyYayinlandi => 'Monat veröffentlicht.';

  @override
  String get seffafYayinGeriAlindi => 'Veröffentlichung zurückgezogen.';

  @override
  String get seffafVeriYokYonetim =>
      'Noch keine Finanzdaten. Monate erscheinen hier, sobald Einnahmen/Ausgaben oder Beiträge erfasst sind.';

  @override
  String get seffafVeriYok =>
      'Die Verwaltung hat noch keine Übersicht veröffentlicht.';

  @override
  String get seffafTaslakEki => ' • Entwurf';

  @override
  String get seffafYayinla => 'Diesen Monat veröffentlichen';

  @override
  String get seffafYayindaAlt => 'Bewohner sehen diese Übersicht.';

  @override
  String get seffafOnizlemeAlt => 'Nur die Verwaltung sieht es (Vorschau).';

  @override
  String get seffafOnizlemeUyari => 'Vorschau — noch nicht veröffentlicht.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — Übersicht';
  }

  @override
  String get seffafToplamGelir => 'Gesamteinnahmen';

  @override
  String get seffafToplamGider => 'Gesamtausgaben';

  @override
  String get seffafNet => 'Netto';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Netto Vormonat: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Ausgabenverteilung';

  @override
  String get seffafGiderYok => 'Diesen Monat keine Ausgaben erfasst.';

  @override
  String get seffafAidatToplama => 'Beitragseinzug';

  @override
  String get seffafTahakkukYok => 'Für diesen Monat keine Sollstellung.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Bezahlte Wohnungen: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Eingezogen: $tahsilat / $tahakkuk  (Betrag: $yuzde %)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wohnungen überfällig',
      one: '$n Wohnung überfällig',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde %';
  }

  @override
  String get entegYeni => 'Neu';

  @override
  String get entegYokMesaj =>
      'Keine Integrationen. Fügen Sie über \"Neu\" ein externes System (Lautsprecher/Smart Home/Webhook) hinzu.';

  @override
  String get entegSilOnay => 'Löschen?';

  @override
  String entegSilGovde(Object ad) {
    return 'Die Integration \"$ad\" wird gelöscht.';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'Löschen fehlgeschlagen: $hata';
  }

  @override
  String get entegAktifKisa => 'aktiv';

  @override
  String get entegPasifKisa => 'inaktiv';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Auth: $tip$kilit';
  }

  @override
  String get entegTest => 'Test';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Erfolgreich ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Fehlgeschlagen';

  @override
  String get entegDuzenleBaslik => 'Integration bearbeiten';

  @override
  String get entegYeniBaslik => 'Neue Integration';

  @override
  String get entegPreset => 'Fertige Vorlage (Preset)';

  @override
  String get entegKanalTipi => 'Kanaltyp';

  @override
  String get entegUrl => 'Endpoint-URL (http/https)';

  @override
  String get entegUrlHelper =>
      'Interne/private Adressen werden beim Auslösen blockiert';

  @override
  String get entegUrlHata => 'Muss mit http(s) beginnen';

  @override
  String get entegHttpMetodu => 'HTTP-Methode';

  @override
  String get entegKimlikDogrulama => 'Authentifizierung';

  @override
  String get entegSir => 'Geheimnis (Bearer-Token / API-Key)';

  @override
  String get entegSirKayitli => 'Gespeichert — zum Ändern neuen Wert eingeben';

  @override
  String get entegSirYazmaOzel =>
      'Nur schreibbar; wird vom Server nie zurückgegeben';

  @override
  String get entegPayload => 'Payload-Vorlage';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return '$sablonlar Platzhalter';
  }

  @override
  String get entegTestMesaji => 'Testnachricht';

  @override
  String get ortakAdGerekli => 'Name erforderlich';

  @override
  String get ziyaretYeni => 'Neuer Besucher';

  @override
  String get ziyaretKaydedildi =>
      'Besucher erfasst — Bewohner benachrichtigt ✓';

  @override
  String get ziyaretYokGuvenlik => 'Noch keine Besuchereinträge.';

  @override
  String get ziyaretYokSakin => 'Ihnen wurden keine Besuchereinträge gemeldet.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Benachrichtigter Bewohner: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Bewohner anrufen';

  @override
  String get ziyaretGuvenligiAra => 'Sicherheit anrufen';

  @override
  String get ziyaretBilgileriDuzenle => 'Daten bearbeiten';

  @override
  String get ziyaretGuncellendi => 'Besucherdaten aktualisiert ✓';

  @override
  String get ziyaretOnceDaireNo => 'Geben Sie zuerst die Wohnungsnummer ein';

  @override
  String get ziyaretSakiniSecin =>
      'Wählen Sie den zu benachrichtigenden Bewohner';

  @override
  String get ziyaretDuzenleBaslik => 'Besucher bearbeiten';

  @override
  String get ziyaretDuzenleAlt =>
      'Sie können Name, Wohnung, benachrichtigten Bewohner und Notiz aktualisieren.';

  @override
  String get ziyaretYeniAlt =>
      'Der Bewohner erhält nur eine Benachrichtigung (keine Zustimmung nötig).';

  @override
  String get ziyaretAdAlan => 'Besuchername *';

  @override
  String get ziyaretAdGerekli => 'Besuchername ist erforderlich';

  @override
  String get ziyaretSakinleriGetir => 'Bewohner laden';

  @override
  String get ziyaretBildirilecekSakin => 'Zu benachrichtigender Bewohner *';

  @override
  String get ziyaretKaydetVeBildir => 'Speichern und Bewohner benachrichtigen';

  @override
  String get raporBaslik => 'Monatsberichte';

  @override
  String get raporOncekiAy => 'Vormonat';

  @override
  String get raporSonrakiAy => 'Nächster Monat';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'Sie haben keine Berechtigung für Monatsberichte. Dieser Bildschirm ist der Objektverwalter-Rolle vorbehalten.';

  @override
  String get raporGorevTamamlama => 'Aufgabenerledigung';

  @override
  String get raporAidat => 'Beiträge';

  @override
  String get raporSonTamamlamalar => 'Letzte Erledigungen (erste 10)';

  @override
  String get raporPlanlananPencere => 'Geplante Fenster';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Erledigung $yuzde %';
  }

  @override
  String get raporPencereYok => 'Diesen Monat keine Rundgangsfenster geplant.';

  @override
  String get raporGorevYok => 'Diesen Monat keine erledigten Aufgaben.';

  @override
  String get raporToplamTamamlama => 'Erledigungen insgesamt';

  @override
  String get raporAidatKayitYok =>
      'Für diesen Zeitraum keine Soll-/Zahlungseinträge.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sollstellung ($n Wohnungen)',
      one: 'Sollstellung ($n Wohnung)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Einzug ($n Zahlungen)',
      one: 'Einzug ($n Zahlung)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'Restsaldo';

  @override
  String get aidatBaslik => 'Meine Beiträge';

  @override
  String get aidatYetkiYok =>
      'Beitragsinformationen sind nur für Bewohnerkonten verfügbar.';

  @override
  String get aidatDaireYok =>
      'Auf Sie ist keine Wohnung registriert. Wenden Sie sich an die Verwaltung.';

  @override
  String get aidatToplamBakiye => 'Gesamtsaldo (alle Wohnungen)';

  @override
  String get aidatBorcVar => 'Offener Betrag';

  @override
  String get aidatBorcYok => 'Kein offener Betrag';

  @override
  String get aidatToplamTahakkuk => 'Sollstellung gesamt';

  @override
  String get aidatToplamOdenen => 'Bezahlt gesamt';

  @override
  String get aidatBakiye => 'Saldo';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Sollstellung $tahakkuk - bezahlt $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sollstellungen ($n)',
      one: 'Sollstellung ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Zahlungen ($n)',
      one: 'Zahlung ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Fällig am: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Belegnr.: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'Der Zahlungsstatus wird nur durch die Bestätigung des Zahlungsdienstleisters aktualisiert; bei Fragen wenden Sie sich an die Verwaltung.';

  @override
  String get aidatYontemElden => 'Barzahlung';

  @override
  String get aidatYontemHavale => 'Banküberweisung';

  @override
  String get aidatYontemKart => 'Karte';

  @override
  String get aidatYontemDiger => 'Sonstiges';

  @override
  String get aidatDurumBasarili => 'Erfolgreich';

  @override
  String get aidatDurumIptal => 'Storniert';

  @override
  String get noktaBaslik => 'Kontrollpunkte';

  @override
  String get noktaEkle => 'Punkt hinzufügen';

  @override
  String get noktaListelenemedi =>
      'Kontrollpunkte konnten nicht geladen werden.';

  @override
  String get noktaSilOnay => 'Kontrollpunkt löschen?';

  @override
  String noktaSilGovde(Object ad) {
    return 'Der Kontrollpunkt \"$ad\" wird gelöscht.';
  }

  @override
  String get noktaSilindi => 'Kontrollpunkt gelöscht ✓';

  @override
  String get noktaUidZatenVar => 'Dieses NFC-Tag ist bereits erfasst.';

  @override
  String get noktaDuzenleBaslik => 'Kontrollpunkt bearbeiten';

  @override
  String get noktaYeniBaslik => 'Neuer Kontrollpunkt';

  @override
  String get noktaAdIpucu => 'z. B. Haupteingang';

  @override
  String get noktaUidAlan => 'NFC-Tag-UID';

  @override
  String get noktaUidIpucu => 'z. B. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'Die eindeutige Kennung des Tags (hex).';

  @override
  String get noktaEnlem => 'Breitengrad (opt.)';

  @override
  String get noktaBoylam => 'Längengrad (opt.)';

  @override
  String get noktaPasifAlt =>
      'Ein inaktiver Punkt wird beim Scannen nicht erkannt';

  @override
  String get noktaYok =>
      'Noch keine Kontrollpunkte.\nUnten rechts einen NFC-Punkt hinzufügen.';

  @override
  String get kuyrukHatalariTemizle => 'Dauerhafte Fehler löschen';

  @override
  String get kuyrukBos => 'Die Warteschlange ist leer.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen ausstehend · $hatali dauerhafte Fehler';
  }

  @override
  String get kuyrukSenkronla => 'Jetzt synchronisieren';

  @override
  String get kuyrukBekliyor => 'Ausstehend';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'Ausstehend (Versuch: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Wird gesendet...';

  @override
  String get kuyrukGonderildiZatenVar => 'Gesendet (war bereits erfasst)';

  @override
  String get kuyrukGonderildiYeni => 'Gesendet (neuer Eintrag)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Dauerhafter Fehler: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'Tag passte nicht';

  @override
  String get okutmaImzaGecersiz =>
      'Die Tag-Signatur konnte nicht verifiziert werden — evtl. ein gefälschtes oder falsches Tag.';

  @override
  String get okutmaTekrarEdilmis => 'Dieser Scan wurde bereits verarbeitet.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Unerwarteter Fehler: $detay';
  }

  @override
  String get noktaUidZorunlu => 'NFC-UID ist Pflicht';

  @override
  String get hataZamanAsimi =>
      'Zeitüberschreitung bei der Verbindung zum Server.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'Der Server ist nicht erreichbar. Prüfen Sie Netzwerkverbindung und Serveradresse.';

  @override
  String get destekBaslik => 'Support';

  @override
  String get destekYeniTalep => 'Neue Anfrage';

  @override
  String get destekTalepYok => 'Sie haben noch keine Support-Anfragen';

  @override
  String destekYuklenemedi(Object hata) {
    return 'Anfragen konnten nicht geladen werden.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'Anfrage konnte nicht gesendet werden: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'Neue Support-Anfrage';

  @override
  String get destekKonu => 'Betreff';

  @override
  String get destekGorselEkle => 'Bild hinzufügen';

  @override
  String get destekGorseliDegistir => 'Bild ändern';

  @override
  String get destekEkip => 'Das Yönetio-Team';

  @override
  String get tesisKurulumBaslik => 'Richten Sie Ihr Objekt ein';

  @override
  String get tesisKurulumAciklama =>
      'Sie haben sich erstmals als Verwalter angemeldet. Geben Sie zum Fortfahren den Namen Ihres Objekts ein; Sie können ihn später in den Einstellungen ändern.';

  @override
  String get tesisAdiIpucu => 'z. B. Beispiel-Anlage';

  @override
  String get tesisAdiKisa => 'Der Objektname muss mindestens 2 Zeichen haben';

  @override
  String get tesisOlustur => 'Objekt anlegen';

  @override
  String get tesisAdiGuncellendi => 'Objektname aktualisiert';

  @override
  String get tesisAdiAciklama =>
      'Erscheint im Titel des Startbildschirms; alle Nutzer sehen diesen Namen.';

  @override
  String get sikayetYokSakin =>
      'Sie haben noch keine Beschwerde eröffnet.\nWählen Sie auf der Beschwerdekarte eine Wohnung aus.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Wohnung $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Geschlossen';

  @override
  String get vardiyaBaslik => 'Schichten';

  @override
  String get vardiyaYuklenemedi => 'Schichten konnten nicht geladen werden.';

  @override
  String get vardiyaTanimYok => 'Keine Schichten definiert';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Personal zuweisen';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — Personal';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Schichtpersonal aktualisiert ✓';

  @override
  String get vardiyaPersonelYuklenemedi =>
      'Personal konnte nicht geladen werden.';

  @override
  String get vardiyaAtanabilirYok => 'Kein zuweisbares Personal';

  @override
  String get gunTipiHaftaIci => 'Wochentags';

  @override
  String get gunTipiHaftaSonu => 'Am Wochenende';

  @override
  String get gunTipiResmiTatil => 'Gesetzliche Feiertage';

  @override
  String get gunTipiHerGun => 'Täglich';

  @override
  String get yonIletisimBaslik => 'Verwaltungskontakte';

  @override
  String get yonIletisimAlinamadi =>
      'Verwaltungsdaten konnten nicht geladen werden.';

  @override
  String get yonIletisimTanimliDegil =>
      'Es sind keine Verwaltungskontakte definiert.';

  @override
  String get yonIletisimMail => 'Verwaltungs-E-Mail';

  @override
  String get yonIletisimAra => 'Verwalter anrufen';

  @override
  String get aramaBaslatilamadi => 'Anruf konnte nicht gestartet werden';

  @override
  String get aramaYapilamiyor => 'Nicht anrufbar';

  @override
  String get bildirimYok => 'Keine Benachrichtigungen';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'Benachrichtigungen konnten nicht geladen werden.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'Neue Benachrichtigung';

  @override
  String get akisDevriyeOkutma => 'Rundgang-Scan';

  @override
  String get akisGorevTamamlandi => 'Aufgabe abgeschlossen';

  @override
  String get akisAidatOdemesi => 'Beitragszahlung';

  @override
  String get akisTalepAcildi => 'Anfrage eröffnet';

  @override
  String get akisTalepIsEmri => 'Anfrage in Arbeitsauftrag umgewandelt';

  @override
  String get akisTalepCozuldu => 'Anfrage gelöst';

  @override
  String get akisTalepReddedildi => 'Anfrage abgelehnt';

  @override
  String get akisDaireSikayeti => 'Beschwerde über Wohneinheit';

  @override
  String get akisAlarmKacirilanTur => 'Verpasster Rundgang';

  @override
  String get akisAlarmEksikCheckpoint => 'Fehlender Kontrollpunkt';

  @override
  String get akisAlarmGecikmisOkutma => 'Verspäteter Scan';

  @override
  String get akisZiyaretciGirisi => 'Besucher-Eintritt';

  @override
  String get akisZiyaretciCikisi => 'Besucher-Austritt';

  @override
  String get akisKargoKaydedildi => 'Paket erfasst';

  @override
  String get akisKargoTeslimEdildi => 'Paket ausgehändigt';

  @override
  String get akisAracGirisi => 'Fahrzeugeinfahrt';

  @override
  String get akisAracCikisi => 'Fahrzeugausfahrt';

  @override
  String get akisIhlalKaydi => 'Verstoßeintrag';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Einheit $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Einheit $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — Einheit $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — Einheit $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — Einheit $daire ($tanim)';
  }

  @override
  String akisAltMetinKonum(Object metin, Object konum) {
    return '$metin — $konum';
  }

  @override
  String akisAltPlanAralik(Object plan, Object aralik) {
    return '$plan · $aralik';
  }

  @override
  String get ortakParolayiGoster => 'Passwort anzeigen';

  @override
  String get ortakParolayiGizle => 'Passwort verbergen';

  @override
  String get ortakFotograf => 'Foto';

  @override
  String get ortakFotografiBuyut => 'Foto vergrößern';

  @override
  String get ortakGoster => 'Anzeigen';

  @override
  String get talepRedBaslik => 'Anfrage ablehnen';

  @override
  String get ziyaretciDaireSakinYok =>
      'Kein aktiver Bewohner in dieser Einheit';

  @override
  String get ceviriOtomatik => 'Dieser Inhalt wurde automatisch übersetzt';

  @override
  String get ceviriOtomatikKisa => 'Automatisch übersetzt';

  @override
  String get ceviriOrijinaliGor => 'Original anzeigen';

  @override
  String get ceviriCeviriyiGor => 'Übersetzung anzeigen';

  @override
  String get ceviriHazirlaniyor =>
      'Übersetzung wird erstellt — Original wird angezeigt';

  @override
  String get ceviriHazirlaniyorKisa => 'Wird übersetzt';

  @override
  String get ceviriYapilamadi =>
      'Übersetzung fehlgeschlagen — Original wird angezeigt';

  @override
  String get ceviriYapilamadiKisa => 'Übersetzung fehlgeschlagen';

  @override
  String get modulAracGecis => 'Fahrzeugdurchfahrten';

  @override
  String get modulOtopark => 'Parkplatz';

  @override
  String get modulIhlaller => 'Verstöße';

  @override
  String get aracSuzgecTumu => 'Alle';

  @override
  String get aracSuzgecIceride => 'Drinnen';

  @override
  String get aracSuzgecCikmis => 'Ausgefahren';

  @override
  String get aracPlakaAra => 'Kennzeichen suchen';

  @override
  String get aracListeBos => 'Keine Fahrzeugdurchfahrten erfasst';

  @override
  String get aracAramaBos => 'Keine Durchfahrt zu diesem Kennzeichen';

  @override
  String get aracRozetIceride => 'Drinnen';

  @override
  String get aracRozetCikti => 'Ausgefahren';

  @override
  String get aracRozetZiyaretci => 'Besucher';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Einfahrt: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Ausfahrt: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Wohnung $no';
  }

  @override
  String get aracCikisVer => 'Ausfahrt buchen';

  @override
  String get aracCikisOnayBaslik => 'Ausfahrt buchen?';

  @override
  String get aracCikisVerildi => 'Ausfahrt erfasst';

  @override
  String get aracZatenKapali => 'Diese Durchfahrt ist bereits abgeschlossen';

  @override
  String get aracYeniGiris => 'Neue Einfahrt';

  @override
  String get aracGirisKaydedildi => 'Fahrzeugeinfahrt erfasst';

  @override
  String get aracPlaka => 'Kennzeichen';

  @override
  String get aracPlakaZorunlu => 'Kennzeichen ist erforderlich';

  @override
  String get aracTanimAlani => 'Fahrzeugbeschreibung (optional)';

  @override
  String get aracDaireAlani => 'Wohnungsnr. (optional)';

  @override
  String get aracZiyaretciMi => 'Besucherfahrzeug';

  @override
  String get aracZatenIceride =>
      'Für dieses Kennzeichen existiert bereits eine offene Durchfahrt (Fahrzeug ist drinnen)';

  @override
  String get aracErisimYok =>
      'Die Durchfahrtsliste ist Verwaltung und Sicherheit vorbehalten';

  @override
  String aracKaydeden(Object ad) {
    return 'Erfasst von: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Belegt';

  @override
  String get otoparkBosEtiket => 'Frei';

  @override
  String get otoparkKapasiteEtiket => 'Kapazität';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Kapazität nicht festgelegt — es wird nur die Anzahl der Fahrzeuge im Objekt angezeigt';

  @override
  String get otoparkAracListesi => 'Fahrzeugdurchfahrten öffnen';

  @override
  String get ihlalDurumYeni => 'Neu';

  @override
  String get ihlalDurumInceleniyor => 'In Prüfung';

  @override
  String get ihlalDurumKapatildi => 'Geschlossen';

  @override
  String get ihlalKaynakKamera => 'Kamera';

  @override
  String get ihlalKaynakManuel => 'Manuell';

  @override
  String get ihlalKaynakDevriye => 'Rundgang';

  @override
  String get ihlalListeBos => 'Keine Verstoßmeldungen';

  @override
  String get ihlalYeni => 'Neuer Verstoß';

  @override
  String get ihlalAcildi => 'Verstoßmeldung angelegt';

  @override
  String get ihlalBaslikAlani => 'Titel';

  @override
  String get ihlalBaslikZorunlu => 'Titel ist erforderlich';

  @override
  String get ihlalAciklamaAlani => 'Beschreibung (optional)';

  @override
  String get ihlalKonumAlani => 'Ort (optional)';

  @override
  String get ihlalKaynakAlani => 'Erfassungsquelle';

  @override
  String get ihlalIncelemeyeAl => 'Prüfung starten';

  @override
  String get ihlalKapat => 'Meldung schließen';

  @override
  String get ihlalDurumGuncellendi => 'Status des Verstoßes aktualisiert';

  @override
  String get ihlalKapatmaOnay =>
      'Meldung schließen? Ein geschlossener Verstoß kann nicht wieder geöffnet werden.';

  @override
  String get ihlalKapaliDegistirilemez =>
      'Ein geschlossener Verstoß kann nicht wieder geöffnet werden';

  @override
  String get ihlalErisimYok =>
      'Verstoßmeldungen sind Verwaltung und Sicherheit vorbehalten';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Eröffnet von: $ad';
  }

  @override
  String get kameraRestream => 'Restream-Adresse (optional)';

  @override
  String get kameraRestreamAlt =>
      'Macht eine RTSP-Kamera abspielbar. Die HLS-Adresse des Frigate/go2rtc-Gateways.';

  @override
  String get kameraRestreamHata =>
      'Die Restream-Adresse muss mit http:// oder https:// beginnen';

  @override
  String get kameraRestreamRozet => 'Über Gateway';

  @override
  String get modulPlakaOlaylari => 'Kennzeichenlesungen';

  @override
  String get anprDurumIslendi => 'Verarbeitet';

  @override
  String get anprDurumOnayBekliyor => 'Wartet auf Freigabe';

  @override
  String get anprDurumYokSayildi => 'Ignoriert';

  @override
  String get anprDurumHata => 'Fehler';

  @override
  String get anprYonGiris => 'Einfahrt';

  @override
  String get anprYonCikis => 'Ausfahrt';

  @override
  String get anprYonBilinmiyor => 'Richtung unbekannt';

  @override
  String get anprListeBos => 'Keine Kennzeichenlesungen';

  @override
  String get anprErisimYok =>
      'Kennzeichenlesungen sind Verwaltung und Sicherheit vorbehalten';

  @override
  String anprGuven(Object oran) {
    return 'Konfidenz $oran %';
  }

  @override
  String get anprOnayla => 'Freigeben';

  @override
  String get anprReddet => 'Ablehnen';

  @override
  String get anprOnayBaslik => 'Lesung freigeben';

  @override
  String get anprOnayAciklama =>
      'Sie können das Kennzeichen korrigieren, falls es falsch gelesen wurde. Eine Freigabe öffnet oder schließt die Durchfahrt.';

  @override
  String get anprKararUygulandi => 'Entscheidung angewendet';

  @override
  String get anprOnayBeklemiyor =>
      'Diese Lesung wartet nicht mehr auf Freigabe';

  @override
  String get anprNedenDusukGuven => 'Geringe Konfidenz';

  @override
  String get anprNedenZatenIceride => 'Fahrzeug ist bereits drinnen';

  @override
  String get anprNedenAcikGecisYok => 'Keine offene Durchfahrt';

  @override
  String get anprNedenOtomatikCikisKapali => 'Automatische Ausfahrt ist aus';

  @override
  String get anprNedenElleReddedildi => 'Manuell abgelehnt';

  @override
  String get anprNedenPlakaBicimi => 'Kennzeichen nicht lesbar';

  @override
  String get aracPlakaOkumalari => 'Kennzeichenlesungen';

  @override
  String get kategoriGoruntuKirliligi => 'Optische Verschmutzung';

  @override
  String get fabSikayetBildir => 'Nachbarschaftsbeschwerde melden';
}
