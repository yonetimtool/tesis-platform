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

  @override
  String get gorevKategorilerTooltip => 'Categories';

  @override
  String get gorevYeni => 'New task';

  @override
  String get gorevOlusturuldu => 'Task created ✓';

  @override
  String get gorevListesiYetkiYok =>
      'You are not authorized to view the task list. This screen is open to the cleaning and security roles.';

  @override
  String get gorevBuFiltredeYok => 'No active tasks with this filter.';

  @override
  String get gorevCipBanaAtanan => 'Assigned to me';

  @override
  String get gorevCipTumGorevler => 'All tasks';

  @override
  String get gorevCipTumu => 'All';

  @override
  String get gorevKategoriDiger => 'Other';

  @override
  String gorevPlanlanan(Object zaman) {
    return 'Scheduled: $zaman';
  }

  @override
  String get gorevSanaAtanmis => 'Assigned to you';

  @override
  String get gorevFotoZorunlu => 'Photo required';

  @override
  String get gorevTamamlandiZatenKayitli =>
      'Completed ✓ (was already recorded)';

  @override
  String get gorevTamamlandiBuOturumda => 'Completed ✓ (in this session)';

  @override
  String get gorevIslemleriTooltip => 'Task actions';

  @override
  String get gorevTakipGorunumu => 'Monitoring view';

  @override
  String get gorevTakipGorunumuAlt =>
      'Completion is done by field staff (security / facility officer). This screen is for monitoring.';

  @override
  String get gorevGonderiliyor => 'Submitting...';

  @override
  String get gorevTamamla => 'Complete';

  @override
  String get gorevGuncellendi => 'Task updated ✓';

  @override
  String get gorevSilinsinMi => 'Delete task?';

  @override
  String get gorevSilindi => 'Task deleted ✓';

  @override
  String get gorevNfcAciklama =>
      'This task is NFC-verified: scan the tag at the task point before completing.';

  @override
  String get gorevAdim1Etiket => '1. Scan the tag';

  @override
  String gorevOkundu(Object uid) {
    return 'Scanned: $uid';
  }

  @override
  String get gorevEtiketBekleniyor => 'Waiting for tag...';

  @override
  String get gorevYenidenOkut => 'Scan again';

  @override
  String get gorevEtiketiOkut => 'Scan tag';

  @override
  String get gorevAdim2Foto => '2. Photo evidence';

  @override
  String get gorevAdim2FotoOpsiyonel => '2. Photo evidence (optional)';

  @override
  String get gorevYukleniyorNokta => 'Uploading...';

  @override
  String get gorevYuklendi => 'Uploaded ✓';

  @override
  String get gorevKamera => 'Camera';

  @override
  String get gorevYenidenCek => 'Retake';

  @override
  String get gorevGaleridenSec => 'Choose from gallery';

  @override
  String get gorevTekrarYukle => 'Upload again';

  @override
  String get gorevKaldir => 'Remove';

  @override
  String get gorevAdim3Not => '3. Note (optional)';

  @override
  String get gorevNotIpucu => 'E.g. waste containers emptied';

  @override
  String get gorevZatenKayitliydi =>
      'This completion was already recorded (resubmission — no duplicate was created).';

  @override
  String get gorevTamamlandiKayit => 'Task completed — record created.';

  @override
  String gorevZaman(Object zaman) {
    return 'Time: $zaman';
  }

  @override
  String get gorevFotoKanitiVar => 'photo evidence attached';

  @override
  String get gorevNfcDogrulandi => 'NFC verified';

  @override
  String get gorevYeniTamamlamaBaslat => 'Start a new completion';

  @override
  String get gorevDuzenleBaslik => 'Edit task';

  @override
  String get gorevKategoriSilinmis => 'Category (deleted)';

  @override
  String get gorevAtananListedeDegil => 'Assignee (not in list)';

  @override
  String get gorevTipleriYukleniyor => 'Loading task types...';

  @override
  String get gorevTipi => 'Task type';

  @override
  String get gorevTipiYokUyari =>
      'You have not defined any task types yet. You can add your own from the \"Categories\" screen above; \"Other\" is used for now.';

  @override
  String get gorevAdi => 'Task name';

  @override
  String get gorevAdiZorunlu => 'Task name is required';

  @override
  String get gorevAciklamaOpsiyonel => 'Description (optional)';

  @override
  String get gorevPersonelYukleniyor => 'Loading staff list...';

  @override
  String get gorevAtananPersonel => 'Assigned staff';

  @override
  String get gorevAtanmamisHavuz => '— unassigned (pool task) —';

  @override
  String gorevPersonelAlinamadi(Object hata) {
    return 'Could not load staff list: $hata';
  }

  @override
  String get gorevKontrolNoktasiOpsiyonel => 'Checkpoint (NFC) — optional';

  @override
  String get gorevKontrolNoktasiYardim =>
      'If linked, the task is completed by scanning NFC';

  @override
  String get gorevNfcYok => '— no NFC —';

  @override
  String get gorevPeriyotDakika => 'Period in minutes (optional)';

  @override
  String get gorevPeriyotYardim => 'For recurring tasks; empty = one-off';

  @override
  String get gorevPozitifSayi => 'Enter a positive whole number';

  @override
  String get gorevFotoKanitiZorunlu => 'Photo evidence required';

  @override
  String get gorevFotoKanitiZorunluAlt =>
      'Completion is not accepted without a photo';

  @override
  String get gorevPasifAciklama => 'Inactive tasks are hidden from the list';

  @override
  String get gorevKategorileriBaslik => 'Task categories';

  @override
  String get gorevKategoriYeni => 'New category';

  @override
  String get gorevKategoriAdi => 'Category name';

  @override
  String get gorevKategoriAdiIpucu => 'e.g. Pool maintenance';

  @override
  String gorevKategoriEklendi(Object ad) {
    return '\"$ad\" added';
  }

  @override
  String gorevKategoriEklenemedi(Object hata) {
    return 'Could not add: $hata';
  }

  @override
  String get gorevKategoriSilinsinMi => 'Delete category?';

  @override
  String gorevKategoriSilOnay(Object ad) {
    return '\"$ad\" will be deactivated; the history of existing tasks is kept, but it cannot be selected for new tasks.';
  }

  @override
  String gorevKategoriSilindi(Object ad) {
    return '\"$ad\" deleted';
  }

  @override
  String gorevKategoriSilinemedi(Object hata) {
    return 'Could not delete: $hata';
  }

  @override
  String gorevKategoriListeAlinamadi(Object hata) {
    return 'Could not load list: $hata';
  }

  @override
  String get gorevKategoriYokBos =>
      'No categories yet. Add one with \"New category\" so it can be chosen when creating a task.';

  @override
  String get gorevOncelikDusuk => 'Low';

  @override
  String get gorevOncelikOrta => 'Medium';

  @override
  String get gorevOncelikYuksek => 'High';

  @override
  String get gorevOncelik => 'Priority';

  @override
  String get gorevTaleptenGeldi => 'From a request';

  @override
  String get gorevBagliTalep => 'Linked request';

  @override
  String gorevDaireEtiket(Object daire) {
    return 'Unit $daire';
  }

  @override
  String get talepDurumAcik => 'Open';

  @override
  String get talepDurumIsEmri => 'Work Order';

  @override
  String get talepDurumCozuldu => 'Resolved';

  @override
  String get talepDurumReddedildi => 'Rejected';

  @override
  String get gorevEtiketOkunamadi => 'Could not read the tag.';

  @override
  String get gorevFotoOnlineGerekli =>
      'An internet connection is required to upload a photo (the upload address is short-lived). When you are back online, use \"Upload again\".';

  @override
  String gorevFotoAlinamadi(Object hata) {
    return 'Could not get the photo: $hata';
  }

  @override
  String get gorevFotoOnlineGerekliKisa =>
      'An internet connection is required to upload a photo.';

  @override
  String get gorevFotoZorunluUyari =>
      'PHOTO EVIDENCE IS REQUIRED for this task. Take and upload a photo before completing.';

  @override
  String get gorevFotoHenuzYuklenmedi =>
      'The photo has not been uploaded yet. Wait for the upload to finish, try \"Upload again\", or remove the photo.';

  @override
  String get gorevTamamlamaOfflineUyari =>
      'The completion could not be sent — an internet connection is required. When you are back online, press \"Complete\" again; the same record will not be duplicated (the Idempotency-Key is fixed). Completion with a photo is not supported offline (known limitation).';

  @override
  String get rolAdmin => 'Platform Admin';

  @override
  String get rolYonetici => 'Site Manager';

  @override
  String get rolGuvenlik => 'Security';

  @override
  String get rolTesisGorevlisi => 'Facility Officer';

  @override
  String get rolSakin => 'Resident';

  @override
  String get rolBilinmeyen => 'Unknown role';

  @override
  String get ortakOlustur => 'Create';

  @override
  String get ortakGuncelle => 'Update';

  @override
  String get ortakYenile => 'Refresh';

  @override
  String get devriyeGonderimKuyruguTooltip => 'Upload queue';

  @override
  String get sekmeGecmis => 'History';

  @override
  String get devriyeYetkiYok =>
      'You are not authorized for the data on this screen. Round tracking is open to the security (and manager) role.';

  @override
  String devriyeSonGuncelleme(Object saat) {
    return 'Last update: $saat (auto-refresh: 60 s)';
  }

  @override
  String get devriyeTuru => 'Patrol round';

  @override
  String devriyeBitisEtiket(Object saat) {
    return 'ends $saat';
  }

  @override
  String devriyePencere(Object baslangic, Object bitis) {
    return 'Window: $baslangic – $bitis';
  }

  @override
  String devriyeNoktaSayaci(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen points';
  }

  @override
  String get devriyeTumNoktalarOkutuldu =>
      'All points scanned — the round is completing. ✓';

  @override
  String devriyeSunucudaOkutma(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n scans are recorded on the server (scans from other devices may be included).',
      one:
          '$n scan is recorded on the server (scans from other devices may be included).',
    );
    return '$_temp0';
  }

  @override
  String get devriyeNoktaOkutNfc => 'Scan point (NFC)';

  @override
  String get devriyeBugununDigerTurlari => 'Today\'s other rounds';

  @override
  String get devriyeBugununTurlari => 'Today\'s rounds';

  @override
  String get devriyeDurumTamamlandi => 'Completed';

  @override
  String get devriyeDurumKacirildi => 'Missed';

  @override
  String get devriyeDurumSimdiAktif => 'Active now';

  @override
  String get devriyeDurumYaklasan => 'Upcoming';

  @override
  String get devriyeDurumBitti => 'Ended';

  @override
  String get devriyeDurumBekliyor => 'Pending';

  @override
  String get devriyeDurumBilinmiyor => 'Unknown';

  @override
  String get devriyeDurumSuresiGecti => 'Expired';

  @override
  String get devriyeBugunTurYok => 'No patrol round for today.';

  @override
  String get devriyeNoktaListesiYok =>
      'The point list for this plan could not be loaded, or no points are assigned to the plan.';

  @override
  String get devriyeKontrolNoktalari => 'Checkpoints';

  @override
  String get devriyeNoktaDurumAciklama =>
      'Point statuses come from the server; scans by all officers appear as ✓. Rows marked \"Sending\" are scans from this device that have not been sent yet.';

  @override
  String devriyeNoktaAdiYedek(Object kisaId) {
    return 'Point $kisaId';
  }

  @override
  String get devriyeOkutuldu => 'Scanned ✓';

  @override
  String devriyeOkutulduZamanli(Object saat) {
    return 'Scanned ✓ · $saat';
  }

  @override
  String get devriyeOkutulduGonderiliyor => 'Scanned ✓ — sending (queued)';

  @override
  String get devriyePencereSuresiDoldu => 'The window has expired.';

  @override
  String devriyeKalanSure(Object sure) {
    return 'Time left: $sure';
  }

  @override
  String sureSaatDakika(Object saat, Object dakika) {
    return '$saat h $dakika min';
  }

  @override
  String sureDakikaSaniye(Object dakika, Object saniye) {
    return '$dakika min $saniye s';
  }

  @override
  String sureSaniye(Object saniye) {
    return '$saniye s';
  }

  @override
  String get devriyeGecmisYetkiYok =>
      'You are not authorized for the round history. This list is open to the security and manager roles.';

  @override
  String get devriyeGecmisBos => 'No round window records yet.';

  @override
  String get devriyeOzetToplam => 'Total';

  @override
  String get devriyePlanlariBaslik => 'Patrol Plans';

  @override
  String get devriyePlanEkle => 'Add plan';

  @override
  String get devriyePlanlarListelenemedi => 'Plans could not be listed.';

  @override
  String devriyePlanAralik(Object baslangic, Object bitis, Object dakika) {
    return '$baslangic–$bitis · every $dakika min';
  }

  @override
  String get devriyePasif => 'Inactive';

  @override
  String get devriyePlanSilinsinMi => 'Delete plan?';

  @override
  String devriyePlanSilOnay(Object ad) {
    return 'The patrol plan \"$ad\" will be deleted.';
  }

  @override
  String get devriyePlanSilindi => 'Plan deleted ✓';

  @override
  String get devriyePlanDuzenleBaslik => 'Edit patrol plan';

  @override
  String get devriyePlanYeniBaslik => 'New patrol plan';

  @override
  String get devriyePlanAdi => 'Plan name';

  @override
  String get devriyePlanAdiIpucu => 'e.g. Night patrol';

  @override
  String get devriyeAdZorunlu => 'Name is required';

  @override
  String devriyeBaslangicSaat(Object saat) {
    return 'Start $saat';
  }

  @override
  String devriyeBitisSaat(Object saat) {
    return 'End $saat';
  }

  @override
  String get devriyeTurSikligi => 'Round frequency (minutes)';

  @override
  String get devriyeTurSikligiYardim => 'e.g. 60 = one round per hour';

  @override
  String get devriyeTurSikligiPozitif =>
      'Round frequency (min) must be positive.';

  @override
  String get devriyeTumunuKaldir => 'Clear all';

  @override
  String get devriyeTumunuSec => 'Select all';

  @override
  String get devriyeAktifNoktaYok =>
      'No active checkpoints. Add one from \"Checkpoints\" first.';

  @override
  String devriyeUidEtiket(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get devriyeKaydedilemedi => 'Could not save. Try again.';

  @override
  String get devriyePlanYokBos =>
      'No patrol plans yet.\nAdd one from the bottom right (hours + points).';

  @override
  String get devriyeTakibiBaslik => 'Patrol tracking';

  @override
  String get sekmeBugun => 'Today';

  @override
  String get sekmeTaramaGunlugu => 'Scan log';

  @override
  String get devriyeTakibiYetkiYok =>
      'You are not authorized for patrol tracking. This screen is open to the manager and security roles.';

  @override
  String get devriyeBugunPencereYok => 'No patrol window scheduled for today.';

  @override
  String devriyeNoktaOkutuldu(Object okutulan, Object beklenen) {
    return '$okutulan/$beklenen points scanned';
  }

  @override
  String get devriyeTaramaGunluguAlinamadi => 'Could not load the scan log.';

  @override
  String get devriyeGunOkutmaYok => 'No scans for this day.';

  @override
  String get devriyeImzali => 'signed ✓';

  @override
  String devriyeOkutmaBekliyor(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n scans waiting to be sent',
      one: '$n scan waiting to be sent',
    );
    return '$_temp0';
  }

  @override
  String get ortakIptal => 'Cancel';

  @override
  String get ortakNotOpsiyonel => 'Note (optional)';

  @override
  String get binaDuzenlemeBaslik => 'Building Layout';

  @override
  String get binaBlokTile => 'Block';

  @override
  String get binaBlokAtanmamis => 'No block assigned';

  @override
  String binaBlokEtiket(Object ad) {
    return 'Block $ad';
  }

  @override
  String get binaSaltGoruntulemeAciklama =>
      'Building structure (read-only). Tap a block tile to see its floor and unit layout.';

  @override
  String get binaDuzenlemeAciklama =>
      'Add a block, tap its tile and place floors and units inside. Every unit belongs to a block. The Complaint Map mirrors this structure.';

  @override
  String binaDaireSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n units',
      one: '$n unit',
    );
    return '$_temp0';
  }

  @override
  String get binaKayitsiz => 'unregistered';

  @override
  String get binaBloksuzDairelerSalt =>
      'Units not assigned to a block (read-only).';

  @override
  String binaBlokYerlesimSalt(Object ad) {
    return 'Block $ad — floor and unit layout (read-only).';
  }

  @override
  String get binaBloksuzUyari =>
      'These units are not assigned to a block (legacy records). They are shown and can be edited or deleted; for a new unit pick or create a block.';

  @override
  String binaBlokYerlesimYardim(Object ad) {
    return 'Block $ad — add floors, then add units with each floor\'s \"+\" button. Units on the same floor are laid out side by side.';
  }

  @override
  String get binaKatEkle => 'Add floor';

  @override
  String get binaTopluDaireEkle => 'Bulk add units';

  @override
  String get binaBloktaDaireYok => 'No units in this block yet.';

  @override
  String get binaKatYokBos =>
      'No floors yet. Start with \"Add floor\", then add units with the \"+\" on the floor.';

  @override
  String get binaKatYok => 'No floor';

  @override
  String binaKatEtiket(Object kat) {
    return 'Floor $kat';
  }

  @override
  String binaBlokDuzenleBaslik(Object ad) {
    return 'Block $ad — edit';
  }

  @override
  String get binaBloguSil => 'Delete block';

  @override
  String binaBloguSilAlt(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted together with $n units (confirmation required)',
      one: 'Deleted together with $n unit (confirmation required)',
    );
    return '$_temp0';
  }

  @override
  String binaBlokSilinsinMi(Object ad) {
    return 'Delete block $ad?';
  }

  @override
  String binaBlokVeDaireSilindi(Object ad, Object n) {
    return 'Block $ad and $n units deleted.';
  }

  @override
  String binaBlokSilindi(Object ad) {
    return 'Block $ad deleted.';
  }

  @override
  String binaBlokSilinemedi(Object hata) {
    return 'Could not delete block: $hata';
  }

  @override
  String get binaBlokSilinemediGenel =>
      'Could not delete the block. Please try again.';

  @override
  String binaKaliciSilmeUyari(Object n) {
    return 'This block and its $n units will be PERMANENTLY deleted together with their dues, visitor, parcel, reservation and complaint records. This cannot be undone.';
  }

  @override
  String get binaOnayIcinBlokAdi => 'Type the block name to confirm';

  @override
  String binaSilNDaire(Object n) {
    return 'Delete ($n units)';
  }

  @override
  String get binaBlokEtiketiGerekli =>
      'A block label is required (e.g. A, B1).';

  @override
  String get binaBlokEtiketiZatenVar =>
      'This block label is already registered.';

  @override
  String get binaBlokDuzenle => 'Edit block';

  @override
  String get binaYeniBlok => 'New block';

  @override
  String get binaBlokEtiketi => 'Block label';

  @override
  String get binaBlokEtiketiYardim =>
      'Short alphanumeric (e.g. A, B1) — no dashes';

  @override
  String get binaDaireNoGerekli => 'A unit number is required (e.g. A-12, 12).';

  @override
  String get binaKatSiraTamSayi => 'Floor and position must be whole numbers.';

  @override
  String get binaDaireNoZatenVar => 'This unit number is already registered.';

  @override
  String binaDaireDuzenleBaslik(Object no) {
    return 'Unit $no — edit';
  }

  @override
  String binaYeniDaire(Object blok) {
    return 'New unit · $blok';
  }

  @override
  String get binaDaireNo => 'Unit number';

  @override
  String get binaDaireNoYardim => 'Alphanumeric + dash (e.g. A-12, B3, 12)';

  @override
  String get binaSira => 'Position';

  @override
  String get binaSiraYardim => 'Position on the floor';

  @override
  String binaEnFazla500(Object n) {
    return 'At most 500 units (currently $n).';
  }

  @override
  String binaTopluOnizleme(
    Object bas,
    Object bitis,
    Object toplam,
    Object kat,
    Object adet,
  ) {
    return '$bas … $bitis  ($toplam units, $kat floors × $adet)';
  }

  @override
  String get binaTopluAlanlarGerekli =>
      'Floor count, units per floor and starting number are required.';

  @override
  String get binaTekSeferde500 => 'At most 500 units at a time.';

  @override
  String binaAtlananEk(Object n) {
    return ' ($n already existed, skipped)';
  }

  @override
  String binaDaireEklendi(Object n, Object ek) {
    return '$n units added ✓$ek';
  }

  @override
  String get binaEklenemedi => 'Could not add. Try again.';

  @override
  String binaTopluBaslik(Object blok) {
    return 'Bulk add units — Block $blok';
  }

  @override
  String get binaTopluBaslikBloksuz => 'Bulk add units — No block';

  @override
  String get binaTopluAciklama =>
      'Numbers run consecutively from the start, filling floor by floor. Existing ones are skipped.';

  @override
  String get binaKatSayisi => 'Number of floors';

  @override
  String get binaKatBasinaDaire => 'Units per floor';

  @override
  String get binaBaslangicNo => 'Starting number';

  @override
  String get binaBaslangicNoIpucu => 'e.g. 101';

  @override
  String get binaDaireleriOlustur => 'Create units';

  @override
  String get binaSilinemedi => 'Could not delete. Please try again.';

  @override
  String get binaKaydedilemedi => 'Could not save. Please try again.';

  @override
  String get semaDaireYok => 'No units yet.';

  @override
  String get semaYogunluk => 'Density:';

  @override
  String get semaYerlesimAciklama =>
      'Building layout. Complaint density is shown to management only.';

  @override
  String get semaYerlesimGirilmemis => 'Layout not entered on the map';

  @override
  String semaDaireEtiket(Object no) {
    return 'Unit $no';
  }

  @override
  String semaAcikSikayet(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n open complaints',
      one: '$n open complaint',
    );
    return '$_temp0';
  }

  @override
  String get semaBuDaireSikayetlerim => 'Your complaints for this unit';

  @override
  String get semaYogunlukYonetim =>
      'Complaint density is shown to management only.';

  @override
  String get semaBuDaireyiSikayetEt => 'Report this unit';

  @override
  String get semaSikayetIletildi => 'Your complaint has been submitted.';

  @override
  String get semaSikayetlerYuklenemedi => 'Complaints could not be loaded.';

  @override
  String get semaAcikSikayetYok => 'No open complaints for this unit.';

  @override
  String get semaSikayetlerimYuklenemedi =>
      'Your complaints could not be loaded.';

  @override
  String get semaSikayetimYok => 'You have no complaints about this unit.';

  @override
  String get semaYonetimeIletildi => 'Sent to management';

  @override
  String get semaKapatildi => 'Closed';

  @override
  String get semaHaftalikSinir =>
      'You can open at most 1 complaint per week on this topic for this unit.';

  @override
  String get semaKendiBlok => 'You can only report units in your own block.';

  @override
  String get semaGonderilemedi => 'Could not send. Please try again.';

  @override
  String semaSikayetEtBaslik(Object no) {
    return 'Unit $no — report';
  }

  @override
  String get semaSikayetAnonimNot =>
      'Your complaint goes to management; it is not shown to your neighbours.';

  @override
  String get semaSikayetiGonder => 'Send complaint';

  @override
  String get kategoriGurultu => 'Noise';

  @override
  String get kategoriKapiOnuAyakkabi => 'Doorway / shoes';

  @override
  String get kategoriZararVerme => 'Damage';

  @override
  String talepSekmeAcik(Object n) {
    return 'Open ($n)';
  }

  @override
  String talepSekmeIsEmri(Object n) {
    return 'Work Order ($n)';
  }

  @override
  String talepSekmeCozulen(Object n) {
    return 'Resolved ($n)';
  }

  @override
  String talepSekmeReddedilen(Object n) {
    return 'Rejected ($n)';
  }

  @override
  String get talepYeni => 'New request';

  @override
  String get talepAcikYokSakin =>
      'You have no open requests. Use \"New request\" to report a request or fault.';

  @override
  String get talepAcikYok => 'No open requests.';

  @override
  String get talepIsEmriYok => 'No requests converted to a work order.';

  @override
  String get talepCozulenYok => 'No resolved requests yet.';

  @override
  String get talepReddedilenYok => 'No rejected requests.';

  @override
  String get talepIletildi => 'Your request has been submitted ✓';

  @override
  String get talepDurumGecmisi => 'Status history';

  @override
  String get talepGorselYuklenemedi => 'Image could not be loaded';

  @override
  String get talepIsEmriAtandi => 'Assigned';

  @override
  String get talepIsEmriTamamlandi => 'Completed';

  @override
  String get talepIsEmriDurumBilinmiyor => 'Status unknown';

  @override
  String get talepIsEmri => 'Work order';

  @override
  String get talepYeniBaslik => 'New request / fault';

  @override
  String get talepBaslikAlan => 'Title';

  @override
  String get talepBaslikZorunlu => 'Title is required';

  @override
  String get talepAciklamaAlan => 'Description';

  @override
  String get talepAciklamaZorunlu => 'Description is required';

  @override
  String get talepGonder => 'Send';

  @override
  String get talepKategoriOpsiyonel => 'Category (optional)';

  @override
  String get talepKategoriYok =>
      'No categories defined; the request will be opened as \"Other\".';

  @override
  String get talepGorseller => 'Images (optional, up to 3)';

  @override
  String get talepYoneticiIslemleri => 'Manager actions';

  @override
  String get talepIsEmrineDonusturuldu => 'Request converted to a work order ✓';

  @override
  String get talepIsEmrineDonusturBuyuk => 'Convert to Work Order';

  @override
  String get talepCozuldu => 'Request resolved ✓';

  @override
  String get talepCoz => 'Resolve';

  @override
  String get talepReddedildiBildirim => 'Request rejected ✓';

  @override
  String get talepReddet => 'Reject';

  @override
  String get talepReddediliyor => 'Rejecting...';

  @override
  String get talepPersonelAlinamadiKisa => 'Could not load the staff list.';

  @override
  String get talepIsEmrineDonustur => 'Convert to work order';

  @override
  String get talepAtanabilirPersonelYok =>
      'No active field staff available to assign. Add a security or facility officer first in order to convert.';

  @override
  String get talepDonusturuluyor => 'Converting...';

  @override
  String get talepDonustur => 'Convert';

  @override
  String get talepReddetBaslik => 'Reject request';

  @override
  String get talepRetSebebiNot =>
      'The rejection reason is visible to the requester in the status history.';

  @override
  String get talepRetSebebi => 'Rejection reason';

  @override
  String get talepCozBaslik => 'Resolve request';

  @override
  String get talepCozNot =>
      'The request is marked resolved directly, without opening a work order.';

  @override
  String get talepCozumNotu => 'Resolution note (optional)';

  @override
  String get talepKategorilerYuklenemedi => 'Categories could not be loaded.';

  @override
  String get talepFotoYuklenemedi => 'The photo could not be uploaded.';

  @override
  String get binaKat => 'Floor';

  @override
  String get binaKatYardim => '0 = ground floor';

  @override
  String get binaBloksuz => 'No block';

  @override
  String get talepAcanSakin => 'Resident';

  @override
  String rezSekmeRezervasyonlar(Object n) {
    return 'Reservations ($n)';
  }

  @override
  String rezSekmeAlanlar(Object n) {
    return 'Areas ($n)';
  }

  @override
  String get rezYokSakin =>
      'You have no reservations. Pick an area on the \"Areas\" tab and book a free slot.';

  @override
  String get rezYok => 'No reservations.';

  @override
  String get rezYeniAlan => 'New area';

  @override
  String get rezAlanEklendi => 'Common area added ✓';

  @override
  String get rezAlanGuncellendi => 'Area updated ✓';

  @override
  String get rezOrtakAlan => 'Common area';

  @override
  String rezSatirOzet(
    Object tarih,
    Object baslangic,
    Object bitis,
    Object kisi,
  ) {
    return '$tarih · $baslangic-$bitis · $kisi people';
  }

  @override
  String get rezIptalEdildi => 'Cancelled';

  @override
  String get rezIptalEdilsinMi => 'Cancel the reservation?';

  @override
  String get rezIptalUyari =>
      'The slot becomes free again; this cannot be undone.';

  @override
  String get rezEvetIptalEt => 'Yes, cancel';

  @override
  String get rezIptalEdildiBildirim => 'Reservation cancelled';

  @override
  String get rezIptalGonderilemedi =>
      'Could not send the cancellation. Try again.';

  @override
  String get rezIptalEt => 'Cancel';

  @override
  String rezDetayTarih(Object tarih, Object baslangic, Object bitis) {
    return 'Date: $tarih · $baslangic-$bitis';
  }

  @override
  String rezDetayKisi(Object n) {
    return 'Number of people: $n';
  }

  @override
  String rezDetayRezerve(Object zaman) {
    return 'Booked: $zaman';
  }

  @override
  String rezDetayNot(Object not) {
    return 'Note: $not';
  }

  @override
  String get rezAlanYokYonetim =>
      'No common areas yet. Add one with \"New area\".';

  @override
  String get rezAlanYokGoruntuleme => 'No common areas to show.';

  @override
  String get rezAlanYokSakin => 'No bookable areas.';

  @override
  String rezMusait(Object ozet) {
    return 'Available: $ozet';
  }

  @override
  String rezMusaitOzeti(Object acilis, Object kapanis, Object dakika) {
    return '$acilis–$kapanis · $dakika min slots';
  }

  @override
  String get rezAcikDuzenle => 'Open · tap to edit';

  @override
  String get rezKapaliDuzenle => 'Closed · tap to edit';

  @override
  String rezMusaitSlotlariGor(Object ozet) {
    return 'Available: $ozet · tap to see slots';
  }

  @override
  String get rezPasifAlan => 'Inactive (not bookable)';

  @override
  String get rezKapanisSonra =>
      'The closing time must be after the opening time.';

  @override
  String get rezAlanEklenemedi => 'Could not add the area. Try again.';

  @override
  String get rezAlanDuzenle => 'Edit area';

  @override
  String get rezYeniOrtakAlan => 'New common area';

  @override
  String get rezAlanAdi => 'Area name * (e.g. Pool)';

  @override
  String get rezAlanAdiGerekli => 'Area name is required';

  @override
  String get rezMusaitlikHerGun => 'Availability (every day)';

  @override
  String rezAcilis(Object saat) {
    return 'Opening: $saat';
  }

  @override
  String rezKapanis(Object saat) {
    return 'Closing: $saat';
  }

  @override
  String get rezSlotUzunlugu => 'Slot length';

  @override
  String rezSlotDakika(Object n) {
    return '$n minutes';
  }

  @override
  String get rezAlaniEkle => 'Add area';

  @override
  String get rezSlotlarYuklenemedi => 'Could not load the slots. Try again.';

  @override
  String get rezOnaylandi => 'Your reservation is confirmed ✓';

  @override
  String rezTarihEtiket(Object tarih) {
    return 'Date: $tarih';
  }

  @override
  String get rezSlotKurali =>
      'A slot opens only within 24 hours of its start; you can make at most one reservation per day.';

  @override
  String get rezSlotYok => 'No slots defined for this area.';

  @override
  String get rezBenimAktif => 'My reservation (active)';

  @override
  String get rezBenimGecti => 'My reservation (past)';

  @override
  String get rezDoluBaskasi => 'Booked (someone else)';

  @override
  String get rezSizinGecti => 'Your reservation (past)';

  @override
  String rezKisiEki(Object n) {
    return ' · $n people';
  }

  @override
  String rezDoluDaire(Object daire, Object kisi) {
    return 'Booked · Unit $daire$kisi';
  }

  @override
  String get rezBos => 'Free';

  @override
  String get rezDolu => 'Booked';

  @override
  String rezSlotAralik(Object baslangic, Object bitis) {
    return '$baslangic – $bitis';
  }

  @override
  String get rezSec => 'Select';

  @override
  String get rezGonderilemedi => 'Could not send. Try again.';

  @override
  String rezEtBaslik(Object ad) {
    return '$ad — book';
  }

  @override
  String get rezKisiSayisiEtiket => 'Number of people:';

  @override
  String get rezEt => 'Book';

  @override
  String get rezDurumOnayli => 'Confirmed';

  @override
  String get rezSebepDolu => 'booked';

  @override
  String get rezSebepGecti => 'past';

  @override
  String get rezSebepCokErken => 'opens within 24h';

  @override
  String get rezSebepGunluk => 'daily limit reached';

  @override
  String etkSekmeYaklasan(Object n) {
    return 'Upcoming ($n)';
  }

  @override
  String etkSekmeGecmis(Object n) {
    return 'Past ($n)';
  }

  @override
  String get etkYeni => 'New event';

  @override
  String get etkYaklasanYokYonetim =>
      'No upcoming events. Announce one with \"New event\".';

  @override
  String get etkYaklasanYok => 'No upcoming events.';

  @override
  String get etkGecmisYok => 'No past events.';

  @override
  String get etkDuyuruldu => 'Event announced — residents notified ✓';

  @override
  String get etkGuncellendi => 'Event updated ✓';

  @override
  String etkKatiliyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n attending',
      one: '$n attending',
    );
    return '$_temp0';
  }

  @override
  String etkKatilmiyorSayisi(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n not attending',
      one: '$n not attending',
    );
    return '$_temp0';
  }

  @override
  String etkKatiliminiz(Object durum) {
    return 'Your RSVP: $durum';
  }

  @override
  String etkBeyanKaydedildi(Object durum) {
    return 'Your RSVP is saved: $durum ✓';
  }

  @override
  String get etkBeyanGonderilemedi => 'Could not send the RSVP. Try again.';

  @override
  String get etkKatiliyorum => 'Attending';

  @override
  String get etkKatilmiyorum => 'Not attending';

  @override
  String etkZaman(Object aralik) {
    return 'Time: $aralik';
  }

  @override
  String etkYer(Object konum) {
    return 'Location: $konum';
  }

  @override
  String etkDuyuran(Object ad) {
    return 'Announced by: $ad';
  }

  @override
  String get etkSilinsinMi => 'Delete the event?';

  @override
  String etkSilOnay(Object baslik) {
    return '\"$baslik\" and all RSVPs will be deleted.';
  }

  @override
  String get etkSilindi => 'Event deleted ✓';

  @override
  String get etkBitisSonra => 'The end must be after the start';

  @override
  String get etkKaydedilemedi => 'Could not save. Try again.';

  @override
  String get etkDuzenleBaslik => 'Edit event';

  @override
  String get etkBaslikAlan => 'Title * (e.g. Match viewing night)';

  @override
  String get etkBaslikGerekli => 'Title is required';

  @override
  String get etkAciklamaAlan => 'Description *';

  @override
  String get etkAciklamaGerekli => 'Description is required';

  @override
  String etkZamanSecim(Object zaman) {
    return 'Time: $zaman';
  }

  @override
  String get etkBitisEkle => 'Add an end time (optional)';

  @override
  String etkBitis(Object zaman) {
    return 'End: $zaman';
  }

  @override
  String get etkBitisiKaldir => 'Remove the end time';

  @override
  String get etkYerAlan => 'Location (optional)';

  @override
  String get etkGorselAlan => 'Image (optional)';

  @override
  String get etkDuyurVeBildir => 'Announce and notify residents';

  @override
  String get izinBaslik => 'View permission';

  @override
  String get izinTumDairelere => 'Request permission for all units';

  @override
  String get izinYeniIstek => 'New request';

  @override
  String get izinIstekYokYonetim =>
      'You have no permission requests yet. Use \"New request\" for a single unit, or \"All units\" above for every unit.';

  @override
  String get izinIstekYokSakin => 'No view requests for your unit.';

  @override
  String get izinTumDaireUyari =>
      'A view-permission request will be sent for every unit that has a resident. Each unit depends on its own resident\'s approval — you can only see records of the units that approve.';

  @override
  String izinAtlandiEki(Object n) {
    return ' ($n already open)';
  }

  @override
  String izinTopluGonderildi(Object n, Object atlandi) {
    return 'Requests sent for $n units$atlandi — awaiting resident approvals';
  }

  @override
  String izinGonderilemedi(Object hata) {
    return 'Could not send: $hata';
  }

  @override
  String get izinIsteBaslik => 'Request view permission';

  @override
  String get izinDaireNo => 'Unit number (e.g. A-12)';

  @override
  String get izinIstekGonder => 'Send request';

  @override
  String get izinIstekGonderildi =>
      'Request sent — awaiting the resident\'s approval';

  @override
  String izinDaireIstegi(Object daire) {
    return 'Unit view request$daire';
  }

  @override
  String izinIsteyen(Object ad) {
    return 'Requested by: $ad';
  }

  @override
  String get izinKullanildiUyari =>
      'The permission has been used (single use). Open a new request to view again.';

  @override
  String izinGoruntulenebilirDaireler(Object n) {
    return 'Viewable units ($n)';
  }

  @override
  String get izinKullanildi => 'Used';

  @override
  String get izinOnayli => 'Approved';

  @override
  String get izinVerildi => 'Permission granted';

  @override
  String get izinOnayla => 'Approve';

  @override
  String get izinKargolar => 'Parcels';

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
      'The permission was used or has expired (single use). Open a new permission request to view again.';

  @override
  String get izinTekSeferlikUyari =>
      'Viewing with a single-use permission — access closes on refresh.';

  @override
  String get izinKayitYok => 'No records for this unit.';

  @override
  String izinHedef(Object ad) {
    return 'Recipient: $ad';
  }

  @override
  String izinKaydeden(Object ad) {
    return 'Recorded by: $ad';
  }

  @override
  String izinDurumEtiket(Object durum) {
    return 'Status: $durum';
  }

  @override
  String get izinDurumOnaylandi => 'Approved';

  @override
  String get kargoDurumTeslimAlindi => 'Delivered';

  @override
  String get rezSizin => 'Your reservation';

  @override
  String get butBaslik => 'Budget';

  @override
  String get butSekmeOzet => 'Summary';

  @override
  String get butSekmeHareketler => 'Entries';

  @override
  String get butSekmeKategoriler => 'Categories';

  @override
  String get butTumZamanlar => 'All time';

  @override
  String get butDonem => 'Period';

  @override
  String get butGelir => 'Income';

  @override
  String get butGider => 'Expense';

  @override
  String get butKasa => 'Balance';

  @override
  String get butKategoriKirilimi => 'Breakdown by category';

  @override
  String get butYeniHareket => 'New entry';

  @override
  String get butHareketYok => 'No entries yet.';

  @override
  String get butKategori => 'Category';

  @override
  String get butOtomatik => 'Automatic';

  @override
  String get butKategoriSecin => 'Select a category';

  @override
  String get butTutar => 'Amount (TL)';

  @override
  String get butTutarIpucu => 'e.g. 1.250,50';

  @override
  String get butTutarGecersiz => 'Enter a valid amount (e.g. 1.250,50)';

  @override
  String butTarih(Object tarih) {
    return 'Date: $tarih';
  }

  @override
  String get butYeniKategori => 'New category';

  @override
  String get butKategoriYok => 'No categories yet.';

  @override
  String get butKategoriAdi => 'Category name';

  @override
  String get butKategoriAdiIpucu => 'e.g. Garden maintenance';

  @override
  String get butAdZorunlu => 'Name is required';

  @override
  String butKategoriTip(Object ad, Object tip) {
    return '$ad ($tip)';
  }

  @override
  String get butPasifEki => ' · inactive (no new entries)';

  @override
  String get butBeklenmeyenKisa => 'An unexpected error occurred. Try again.';

  @override
  String get butFinansalOzet => 'Financial summary';

  @override
  String get butAidatTahsilati => 'Dues collection';

  @override
  String get butEnYuksekGiderler => 'Largest expenses';

  @override
  String butTahsilatYuzde(Object yuzde) {
    return 'Collection $yuzde%';
  }

  @override
  String get butTahakkukYok => 'No assessments recorded for this period.';

  @override
  String get butSiteBaslik => 'Site Budget';

  @override
  String get butKategoriToplamlari => 'Category totals';

  @override
  String get butSeffaflikNotu =>
      'This screen shows the site management\'s income and expenses as a summary, for transparency. Person- and unit-level details are not shown; contact your management with questions.';

  @override
  String get demBaslik => 'Assets';

  @override
  String get demEtiketOkut => 'Scan tag';

  @override
  String get demBaskaEtiketOkut => 'Scan another tag';

  @override
  String demUzerimdekiler(Object ek) {
    return 'Assigned to me$ek';
  }

  @override
  String get demNfcAciklama =>
      'Scan the NFC tag on the asset when taking or returning it. The app identifies the asset and shows who holds it.';

  @override
  String get demTaniniyor => 'Identifying the asset...';

  @override
  String get demKimsedeDegil => 'Not held by anyone — available.';

  @override
  String demSende(Object sure) {
    return 'WITH YOU — $sure.';
  }

  @override
  String demBaskasinda(Object ad, Object sure) {
    return 'Held by $ad — $sure.';
  }

  @override
  String get demBaskasininUzerinde => 'Appears to be held by someone else.';

  @override
  String get demBakimda => 'Under maintenance — cannot be checked out now.';

  @override
  String get demZorlaDevralmaYok =>
      'No forced takeover — the current holder must return the asset.';

  @override
  String get demZimmetineAl => 'Check out';

  @override
  String get demBirak => 'Return';

  @override
  String get demBirakKisa => 'Return';

  @override
  String get demSonHareketler => 'Recent activity';

  @override
  String demAldi(Object ad, Object zaman) {
    return '$ad took it — $zaman (still held)';
  }

  @override
  String get demListeYetkiYok => 'You are not authorized for the asset list.';

  @override
  String get demUzerindeYok => 'You currently hold no assets.';

  @override
  String demAldin(Object zaman, Object sure) {
    return 'Taken: $zaman ($sure)';
  }

  @override
  String get demSureBelirsiz => 'for a while';

  @override
  String get demSureAzOnce => 'just now';

  @override
  String demSureDakika(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'for $n minutes',
      one: 'for $n minute',
    );
    return '$_temp0';
  }

  @override
  String demSureSaat(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'for $n hours',
      one: 'for $n hour',
    );
    return '$_temp0';
  }

  @override
  String demSureGun(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'for $n days',
      one: 'for $n day',
    );
    return '$_temp0';
  }

  @override
  String get demOfflineUyari =>
      'An internet connection is required. Asset custody is a REAL-TIME record; it is not processed offline (queuing would be misleading).';

  @override
  String demEtiketEslesmiyor(Object uid) {
    return 'This tag ($uid) does not match a registered asset. The tag must be assigned to an asset from the panel.';
  }

  @override
  String get demZatenZimmetinde =>
      'It was already checked out to you ✓ (resubmission — no duplicate)';

  @override
  String get demZimmetineAlindi => 'Checked out ✓';

  @override
  String get demBirakildi => 'Returned ✓ — the checkout is closed.';

  @override
  String demIslemYapilamadi(Object hata) {
    return 'The action failed: $hata The status was refreshed — check the card again.';
  }

  @override
  String demHataSatiri(Object ad, Object hata) {
    return '$ad: $hata';
  }

  @override
  String get karBaslik => 'Parcels';

  @override
  String karSekmeBekleyen(Object n) {
    return 'Pending ($n)';
  }

  @override
  String karSekmeTeslim(Object n) {
    return 'Collected ($n)';
  }

  @override
  String get karYeni => 'New parcel';

  @override
  String get karBekleyenYokSakin => 'You have no parcels awaiting pickup.';

  @override
  String get karBekleyenYok => 'No parcels awaiting pickup.';

  @override
  String get karTeslimYok => 'No collected parcels recorded yet.';

  @override
  String get karKaydedildi =>
      'Parcel recorded — the unit\'s residents were notified ✓';

  @override
  String karDaireTarih(Object daire, Object zaman) {
    return 'Unit: $daire · $zaman';
  }

  @override
  String karDaire(Object daire) {
    return 'Unit: $daire';
  }

  @override
  String karKayit(Object zaman) {
    return 'Recorded: $zaman';
  }

  @override
  String karNot(Object not) {
    return 'Note: $not';
  }

  @override
  String get karTeslimAlindiBildirim => 'Parcel marked as collected ✓';

  @override
  String get karIsaretlenemedi => 'Could not mark it. Try again.';

  @override
  String get karTeslimAldim => 'I collected it';

  @override
  String get karGonderilemedi => 'Could not submit the record. Try again.';

  @override
  String get karDaireNo => 'Unit number * (e.g. A-12)';

  @override
  String get karDaireNoGerekli => 'Unit number is required';

  @override
  String get karFirma => 'Courier company *';

  @override
  String get karFirmaGerekli => 'Courier company is required';

  @override
  String get karPaketFotografi => 'Parcel photo (optional)';

  @override
  String get karKaydetVeBildir => 'Save and notify residents';

  @override
  String get ortakTekrarDene => 'Try again';

  @override
  String get butTahakkuk => 'Assessed';

  @override
  String get butTahsilat => 'Collected';

  @override
  String get butGeciken => 'Overdue';

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
  String get kuralBaslik => 'Site Rules';

  @override
  String get kuralYeni => 'New rule';

  @override
  String get kuralAramaIpucu => 'Search titles (e.g. pool)';

  @override
  String get kuralEklendi => 'Rule added ✓';

  @override
  String get kuralGuncellendi => 'Rule updated ✓';

  @override
  String get kuralAramaBos => 'No rules match your search.';

  @override
  String get kuralYokYonetim => 'No rules yet. Add one with \"New rule\".';

  @override
  String get kuralYokSakin => 'No rules published yet.';

  @override
  String get kuralSilOnayBaslik => 'Delete this rule?';

  @override
  String kuralSilOnayGovde(Object baslik) {
    return '\"$baslik\" will be permanently deleted.';
  }

  @override
  String get kuralSilindi => 'Rule deleted ✓';

  @override
  String get kuralDuzenleBaslik => 'Edit rule';

  @override
  String get kuralBaslikAlan => 'Title * (e.g. Pool Hours)';

  @override
  String get kuralBaslikGerekli => 'Title is required';

  @override
  String get kuralMetni => 'Rule text *';

  @override
  String get kuralMetniGerekli => 'Rule text is required';

  @override
  String get kuralSira => 'Order (lowest first)';

  @override
  String get kuralSiraGecersiz => 'Order must be 0 or a positive integer';

  @override
  String get kuralMevcutGorsel => 'Existing image kept';

  @override
  String get kuralEkleButon => 'Add rule';

  @override
  String get ortakFotoOnlineTekrarDene =>
      'An internet connection is required to upload a photo. Try again once you are back online.';

  @override
  String get ortakFotoBekleyinVeyaKaldir =>
      'The photo has not been uploaded yet. Wait for the upload to finish or remove the photo.';

  @override
  String get duyuruYeni => 'New announcement';

  @override
  String get duyuruYayinlandi => 'Announcement published ✓';

  @override
  String get duyuruGuncellendi => 'Announcement updated ✓';

  @override
  String get duyuruYok => 'No announcements yet.';

  @override
  String get duyuruYonetim => 'Management';

  @override
  String duyuruMeta(Object ad, Object zaman, Object duzenlendi) {
    return '$ad · $zaman$duzenlendi';
  }

  @override
  String get duyuruDuzenlendiEki => ' · edited';

  @override
  String get duyuruSilOnay => 'Delete this announcement?';

  @override
  String get duyuruSilindi => 'Announcement deleted ✓';

  @override
  String get duyuruDuzenleBaslik => 'Edit announcement';

  @override
  String get duyuruBaslikZorunlu => 'Title is required';

  @override
  String get duyuruMetniAlan => 'Announcement text';

  @override
  String get duyuruMetniZorunlu => 'Announcement text is required';

  @override
  String get duyuruYayinla => 'Publish';

  @override
  String get ortakIslemler => 'Actions';

  @override
  String get sakinBaslik => 'Residents';

  @override
  String get sakinEkle => 'Add resident';

  @override
  String get sakinListelenemedi => 'Residents could not be listed.';

  @override
  String get sakinDaireYok => 'No unit assigned';

  @override
  String get sakinIslemleri => 'Resident actions';

  @override
  String get sakinParolaSifirla => 'Reset password';

  @override
  String get sakinParolaSifirlaOnay => 'Reset the password?';

  @override
  String sakinParolaSifirlaGovde(Object ad) {
    return 'A new temporary code is generated for \"$ad\"; the old password stops working. The user signs in with phone + the new code and then sets a password.';
  }

  @override
  String get sakinSifirla => 'Reset';

  @override
  String sakinYeniKodMesaji(Object ad) {
    return 'New temporary code for \"$ad\". Share it with the resident; they sign in with phone + this code and then set a password.';
  }

  @override
  String get sakinSilOnay => 'Delete resident?';

  @override
  String sakinSilGovde(Object ad) {
    return '\"$ad\" will be removed. With no history the record is deleted outright; otherwise it becomes inactive. Either way the phone number is released (it can be registered again).';
  }

  @override
  String sakinSilindi(Object ad) {
    return '\"$ad\" deleted (number released)';
  }

  @override
  String sakinPasiflestirildi(Object ad) {
    return '\"$ad\" set to inactive — has history (number released)';
  }

  @override
  String get sakinDuzenleBaslik => 'Edit resident';

  @override
  String get sakinYeniTelefon => 'New mobile number';

  @override
  String get sakinBosBirakDegismez => 'Leave empty to keep it unchanged';

  @override
  String get sakinGuncellendi => 'Updated ✓';

  @override
  String get ortakAdSoyad => 'Full name';

  @override
  String get ortakCepTelefonu => 'Mobile number';

  @override
  String get ortakTelefonIpucu => 'e.g. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Phone number is required';

  @override
  String get sakinGirisAnahtari => 'Sign-in key (globally unique).';

  @override
  String get ortakDaireNoIpucu => 'e.g. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Unit number is required';

  @override
  String get sakinParolaOpsiyonel => 'Password (optional)';

  @override
  String get sakinBosBirakKod => 'Leave empty to generate a temporary code';

  @override
  String get sakinEklendiKod =>
      'Resident added. Share this code with them; they sign in with phone + this code and then set a password.';

  @override
  String get sakinEklendi => 'Resident added ✓';

  @override
  String get sakinYok => 'No residents yet.\nAdd one from the bottom right.';

  @override
  String get ortakGeciciKodBaslik => 'Temporary sign-in code';

  @override
  String get ortakKopyala => 'Copy';

  @override
  String get ortakKopyalandi => 'Copied';
}
