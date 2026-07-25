// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ortakKaydet => 'Save';

  @override
  String sayacBekliyor(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pending',
      one: '$n pending',
    );
    return '$_temp0';
  }

  @override
  String get ortakKaydediliyor => 'Saving...';

  @override
  String get ortakVazgec => 'Cancel';

  @override
  String get ortakSil => 'Delete';

  @override
  String get ortakDuzenle => 'Edit';

  @override
  String get ortakEkle => 'Add';

  @override
  String get ortakTamam => 'OK';

  @override
  String get ortakKapat => 'Close';

  @override
  String get ortakTumunuGor => 'See all';

  @override
  String get ortakYuklenemedi => 'Couldn\'t load';

  @override
  String get ortakYenidenDene => 'Try again';

  @override
  String get ortakYakinda => 'Coming soon';

  @override
  String get ortakBolumYakinda => 'This section is coming soon';

  @override
  String get ortakBeklenmeyenHata =>
      'An unexpected error occurred. Please try again.';

  @override
  String ortakZorunluAlan(String alan) {
    return '$alan is required';
  }

  @override
  String get ayarlarBaslik => 'Settings';

  @override
  String get ayarlarTesis => 'Facility';

  @override
  String get ayarlarYonetim => 'Management';

  @override
  String get ayarlarGorunum => 'Appearance';

  @override
  String get ayarlarTema => 'Theme';

  @override
  String get ayarlarTemaSistem => 'System';

  @override
  String get ayarlarTemaAcik => 'Light';

  @override
  String get ayarlarTemaKoyu => 'Dark';

  @override
  String get ayarlarTemaAciklama =>
      'Dark theme applies to every screen; “System” follows the device setting.';

  @override
  String get ayarlarTesisAdi => 'Facility name';

  @override
  String get ayarlarTesisAdiAciklama =>
      'The name shown on the home screen and in reports.';

  @override
  String get ayarlarTesisAdiGuncellendi => 'Facility name updated';

  @override
  String get ayarlarKameralar => 'Cameras';

  @override
  String get ayarlarKameralarAlt => 'Add, edit and delete cameras';

  @override
  String get ayarlarDil => 'Language';

  @override
  String get dilSecBaslik => 'App language';

  @override
  String get kameraBaslik => 'Cameras';

  @override
  String get kameraEkle => 'Add camera';

  @override
  String get kameraYeni => 'New camera';

  @override
  String get kameraDuzenleBaslik => 'Edit camera';

  @override
  String get kameraAd => 'Name';

  @override
  String get kameraKonum => 'Location (optional)';

  @override
  String get kameraTur => 'Type';

  @override
  String get kameraUrl => 'Stream URL';

  @override
  String get kameraAktif => 'Active';

  @override
  String get kameraAktifAlt => 'Hidden from all lists when off';

  @override
  String get kameraSakinGorebilir => 'Visible to residents';

  @override
  String get kameraSakinGorebilirAlt =>
      'When off, only management and security can see the camera';

  @override
  String get kameraRtspFormUyari =>
      'RTSP streams can\'t be played in the app yet. The record is kept; playback support will be added later.';

  @override
  String get kameraUrlZorunlu => 'Stream URL is required';

  @override
  String kameraUrlHataHttp(String tur) {
    return '$tur stream URL must start with http:// or https://';
  }

  @override
  String get kameraUrlHataRtsp => 'RTSP stream URL must start with rtsp://';

  @override
  String get kameraSilBaslik => 'Delete camera';

  @override
  String kameraSilOnay(String ad) {
    return 'Delete “$ad”?';
  }

  @override
  String get kameraBosYonetim =>
      'No cameras yet. Add one from the bottom right.';

  @override
  String get kameraBosSakin => 'No cameras are shared with you.';

  @override
  String get kameraListeHata => 'Cameras couldn\'t be loaded.';

  @override
  String get kameraCanli => 'Live';

  @override
  String get kameraOynatilamiyor => 'Not playable';

  @override
  String get kameraYayinAcilamadi => 'Stream couldn\'t be opened';

  @override
  String get kameraYayinAcilamadiAlt =>
      'The camera may be off, or the network cannot reach the stream.';

  @override
  String kameraTurEtiket(String tur) {
    return 'Type: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP streams can\'t be played in the app right now. The record is kept in the system; playback support will be added later.';

  @override
  String get kameraSeritBaslik => 'Live camera';
}
