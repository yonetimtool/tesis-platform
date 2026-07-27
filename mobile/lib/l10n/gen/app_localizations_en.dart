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
}
