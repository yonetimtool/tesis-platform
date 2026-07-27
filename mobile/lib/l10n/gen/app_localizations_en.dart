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
  String devriyeNoktaSayaci(Object beklenen, Object okutulan) {
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
  String sureSaatDakika(Object dakika, Object saat) {
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
  String devriyeNoktaOkutuldu(Object beklenen, Object okutulan) {
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
    Object adet,
    Object bas,
    Object bitis,
    Object kat,
    Object toplam,
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
  String binaDaireEklendi(Object ek, Object n) {
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
}
