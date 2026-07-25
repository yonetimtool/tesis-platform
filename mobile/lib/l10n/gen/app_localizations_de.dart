// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get ortakKaydet => 'Speichern';

  @override
  String sayacBekliyor(int n) {
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
  String ortakZorunluAlan(String alan) {
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
  String kameraUrlHataHttp(String tur) {
    return '$tur-Stream-Adresse muss mit http:// oder https:// beginnen';
  }

  @override
  String get kameraUrlHataRtsp =>
      'RTSP-Stream-Adresse muss mit rtsp:// beginnen';

  @override
  String get kameraSilBaslik => 'Kamera löschen';

  @override
  String kameraSilOnay(String ad) {
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
  String kameraTurEtiket(String tur) {
    return 'Typ: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP-Streams können derzeit nicht in der App abgespielt werden. Der Eintrag bleibt im System; Wiedergabe folgt später.';

  @override
  String get kameraSeritBaslik => 'Live-Kamera';
}
