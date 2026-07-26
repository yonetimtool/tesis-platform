// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cipYeni => 'New';

  @override
  String get cipAktif => 'Active';

  @override
  String get bolumVardiyaDurumu => 'Shift status';

  @override
  String get bolumSonHareketler => 'Recent activity';

  @override
  String get bolumHizliOzet => 'Quick summary';

  @override
  String get bolumDuyurular => 'Announcements';

  @override
  String get bolumSiteKurallari => 'Site rules';

  @override
  String get bolumEtkinlikler => 'Events';

  @override
  String get bolumOdemeAidat => 'Payments and dues';

  @override
  String get bolumTumModuller => 'All modules';

  @override
  String get kartVardiyaDurum => 'Shift';

  @override
  String get kartKargo => 'Parcels';

  @override
  String get kartZiyaretci => 'Visitors';

  @override
  String get kartAracPlaka => 'Vehicles';

  @override
  String get kartIhlaller => 'Violations';

  @override
  String get kartGorevlerim => 'My tasks';

  @override
  String get kartDemirbas => 'Assets';

  @override
  String get kartTurlarim => 'My patrols';

  @override
  String get kartTalepAriza => 'Requests';

  @override
  String get kartZiyaretciler => 'Visitors';

  @override
  String get kartKargolarim => 'My parcels';

  @override
  String get kartAidatBilgileri => 'Dues';

  @override
  String get kartGurultuSikayeti => 'Noise complaint';

  @override
  String get kartGeriBildirim => 'Feedback';

  @override
  String get kartSikayetlerim => 'My complaints';

  @override
  String get kartSiteRaporlari => 'Site reports';

  @override
  String get kartGorevler => 'Tasks';

  @override
  String get kartAidatDurumu => 'Dues status';

  @override
  String get kartOtoparkKullanimi => 'Parking use';

  @override
  String get kartSikayetler => 'Complaints';

  @override
  String get kartRaporlar => 'Reports';

  @override
  String get kartYonetici => 'Manager';

  @override
  String get kartGonderimKuyrugu => 'Upload queue';

  @override
  String get etiketAylikOzet => 'Monthly summary';

  @override
  String get etiketDevriye => 'Patrol';

  @override
  String get etiketKurallar => 'Rules';

  @override
  String get etiketIletisim => 'Contact';

  @override
  String sayacAktif(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n active',
      one: '$n active',
    );
    return '$_temp0';
  }

  @override
  String sayacIceride(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n inside',
      one: '$n inside',
    );
    return '$_temp0';
  }

  @override
  String sayacGiris(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entries',
      one: '$n entry',
    );
    return '$_temp0';
  }

  @override
  String sayacYeni(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n new',
      one: '$n new',
    );
    return '$_temp0';
  }

  @override
  String sayacAcik(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n open',
      one: '$n open',
    );
    return '$_temp0';
  }

  @override
  String sayacZimmetli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n checked out',
      one: '$n checked out',
    );
    return '$_temp0';
  }

  @override
  String sayacKayit(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n records',
      one: '$n record',
    );
    return '$_temp0';
  }

  @override
  String sayacYaklasan(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n upcoming',
      one: '$n upcoming',
    );
    return '$_temp0';
  }

  @override
  String sayacDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n units',
      one: '$n unit',
    );
    return '$_temp0';
  }

  @override
  String sayacArac(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n vehicles',
      one: '$n vehicle',
    );
    return '$_temp0';
  }

  @override
  String sayacGorevli(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n officers',
      one: '$n officer',
    );
    return '$_temp0';
  }

  @override
  String sayacBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n waiting',
      one: '$n waiting',
    );
    return '$_temp0';
  }

  @override
  String get ozetToplamDaire => 'Total units';

  @override
  String get ozetToplamTahsilat => 'Total collected';

  @override
  String get ozetTahsilatOrani => 'Dues collection rate';

  @override
  String get ozetOtoparkDoluluk => 'Parking occupancy';

  @override
  String get ozetTumSite => 'Whole site';

  @override
  String get ozetBuAy => 'This month';

  @override
  String get ozetSuAn => 'Right now';

  @override
  String otoparkDoluKapasite(Object dolu, Object kapasite) {
    return '$dolu / $kapasite';
  }

  @override
  String yuzdeDeger(Object oran) {
    return '$oran%';
  }

  @override
  String anaSelam(Object ad) {
    return 'Hello, $ad';
  }

  @override
  String get anaYoneticiPaneli => 'Manager panel';

  @override
  String anaDaireAltBaslik(Object daireler, Object rol) {
    return 'Unit $daireler  •  $rol';
  }

  @override
  String get anaDun => 'Yesterday';

  @override
  String get anaOnline => 'Online';

  @override
  String get anaVardiyaAktif => 'Active';

  @override
  String get anaVardiyaPlanlandi => 'Scheduled';

  @override
  String get anaEtkinlikSuruyor => 'Ongoing';

  @override
  String get anaEtkinlikYaklasan => 'Upcoming';

  @override
  String get anaOdendi => 'Paid';

  @override
  String get anaOdenmedi => 'Unpaid';

  @override
  String get anaBorcVar => 'Balance due';

  @override
  String get anaBorcYok => 'No balance';

  @override
  String get anaBuAykiAidat => 'This month\'s dues';

  @override
  String anaSonOdemeTarih(Object tarih) {
    return 'Last payment: $tarih';
  }

  @override
  String get anaGelecekOdeme => 'Next payment';

  @override
  String get anaGecmisOdemeler => 'Payment history';

  @override
  String get anaAidatKaydiYok => 'No dues record found';

  @override
  String get anaBildirimlerYakinda => 'Notifications coming soon';

  @override
  String get anaBildirimlerRolYok =>
      'Notifications are not available for this role';

  @override
  String get anaRaporlarYakinda => 'Reports coming soon';

  @override
  String get sekmeAnaSayfa => 'Home';

  @override
  String get sekmeBildirimler => 'Notifications';

  @override
  String get sekmeRaporlar => 'Reports';

  @override
  String get sekmeAyarlar => 'Settings';

  @override
  String get kabukProfil => 'Profile';

  @override
  String get kabukCikisYap => 'Sign out';

  @override
  String get fabOlayBildir => 'Report incident';

  @override
  String get fabTalepBildir => 'Request / report';

  @override
  String get fabTalepArizaBildir => 'Report request or fault';

  @override
  String get fabRezervasyonYap => 'Make a booking';

  @override
  String get fabDuyuruYayinla => 'Publish announcement';

  @override
  String get fabGorevOlustur => 'Create task';

  @override
  String get fabDestekTalebi => 'Support request';

  @override
  String get modulDuyurular => 'Announcements';

  @override
  String get modulTurlarim => 'My patrols';

  @override
  String get modulDevriyeTakibi => 'Patrol tracking';

  @override
  String get modulGorevlerim => 'My tasks';

  @override
  String get modulGorevYonetimi => 'Task management';

  @override
  String get modulDemirbas => 'Assets';

  @override
  String get modulNfcOkutma => 'NFC scan';

  @override
  String get modulGonderimKuyrugu => 'Upload queue';

  @override
  String get modulAylikRaporlar => 'Monthly reports';

  @override
  String get modulButce => 'Budget';

  @override
  String get modulFinansalOzet => 'Financial summary';

  @override
  String get modulSeffaflik => 'Transparency';

  @override
  String get modulSiteButcesi => 'Site budget';

  @override
  String get modulAidatim => 'My dues';

  @override
  String get modulSikayetOneri => 'Complaint / suggestion';

  @override
  String get modulZiyaretciler => 'Visitors';

  @override
  String get modulKargo => 'Parcels';

  @override
  String get modulGoruntulemeIzni => 'Viewing permission';

  @override
  String get modulRezervasyon => 'Booking';

  @override
  String get modulEtkinlikler => 'Events';

  @override
  String get modulSiteKurallari => 'Site rules';

  @override
  String get modulDisHizmetler => 'External services';

  @override
  String get modulEntegrasyonlar => 'Integrations';

  @override
  String get modulPersonel => 'Field staff';

  @override
  String get modulSakinler => 'Residents';

  @override
  String get modulBinaYapisi => 'Building structure';

  @override
  String get modulSikayetHaritasi => 'Complaint map';

  @override
  String get modulSikayetlerim => 'My complaints';

  @override
  String get modulYoneticiIletisim => 'Manager contact';

  @override
  String get ortakKaydet => 'Save';

  @override
  String sayacBekliyor(num n) {
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
  String ortakZorunluAlan(Object alan) {
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
  String kameraUrlHataHttp(Object tur) {
    return '$tur stream URL must start with http:// or https://';
  }

  @override
  String get kameraUrlHataRtsp => 'RTSP stream URL must start with rtsp://';

  @override
  String get kameraSilBaslik => 'Delete camera';

  @override
  String kameraSilOnay(Object ad) {
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
  String kameraTurEtiket(Object tur) {
    return 'Type: $tur';
  }

  @override
  String get kameraRtspBilgi =>
      'RTSP streams can\'t be played in the app right now. The record is kept in the system; playback support will be added later.';

  @override
  String get kameraSeritBaslik => 'Live camera';

  @override
  String anaKarsilama(String ad) {
    return 'Hello, $ad';
  }
}
