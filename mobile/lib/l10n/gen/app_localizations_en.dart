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
  String get sekmeSeffaflik => 'Transparency';

  @override
  String get sekmeGorevlerim => 'My Tasks';

  @override
  String get sekmeAyarlar => 'Settings';

  @override
  String get kabukGrupGuvenlik => 'Security';

  @override
  String get kabukGrupTesis => 'Facility';

  @override
  String get kabukGrupFinans => 'Finance';

  @override
  String get kabukGrupIletisim => 'Communication';

  @override
  String get kabukGrupTanimlar => 'Definitions';

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
  String get kameraKareYok => 'No image available';

  @override
  String get kameraBaglantiYok => 'No connection';

  @override
  String get kameraUrlWebSayfasi =>
      'This is a web page address. The app only plays direct stream URLs: .m3u8 (HLS) or .mp4.';

  @override
  String get kameraKaynakYardim =>
      'Only direct media URLs play: HLS (.m3u8) and MP4. Web pages (YouTube, Vimeo, municipal viewer pages) cannot be played. RTSP is stored but needs an HLS gateway to play.';

  @override
  String get kameraSnapshot => 'Snapshot URL';

  @override
  String get kameraSnapshotAlt =>
      'Optional. If set, the camera list shows a live still frame (single JPEG frame).';

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
  String get telefonHataEksik =>
      'The number is incomplete — enter 10 digits (e.g. 0543 199 29 04).';

  @override
  String get telefonHataOnEk =>
      'A mobile number must start with 5 (e.g. 0543…). Landlines are not accepted.';

  @override
  String get ortakCepTelefonu => 'Mobile number';

  @override
  String get ortakTelefonIpucu => 'e.g. 0532 111 22 03';

  @override
  String get ortakTelefonZorunlu => 'Phone number is required';

  @override
  String get sakinGirisAnahtari => 'For contact only (optional).';

  @override
  String get ortakDaireNoIpucu => 'e.g. A-12';

  @override
  String get sakinDaireNoZorunlu => 'Unit number is required';

  @override
  String get sakinEklendi => 'Resident added ✓';

  @override
  String get sakinYok => 'No residents yet.\nAdd one from the bottom right.';

  @override
  String get girisParolaVeyaKod => 'Password or temporary code';

  @override
  String get girisIlkKodIpucu =>
      'On first sign-in, enter the temporary code you got from management.';

  @override
  String get girisKimlik => 'E-mail or phone number';

  @override
  String get girisKimlikOrnek => 'name@example.com or 5XX XXX XX XX';

  @override
  String get girisKimlikYardim =>
      'Sign in with your e-mail address or phone number';

  @override
  String get girisKimlikGerekli => 'Enter your e-mail address or phone number';

  @override
  String get girisTesisSec => 'Which facility do you want to sign in to?';

  @override
  String get girisBeniHatirla => 'Remember me';

  @override
  String get girisYap => 'Sign in';

  @override
  String get girisOturumSonaErdi =>
      'Your session has expired. Please sign in again.';

  @override
  String get parolaBelirleBaslik => 'Set your password';

  @override
  String get parolaBelirleAciklama =>
      'You signed in for the first time with a temporary code. To continue, create your own permanent password; from now on you will sign in with your unit number + this password.';

  @override
  String get parolaBelirleButon => 'Set password';

  @override
  String get parolaGiriseDon => 'Back to sign-in';

  @override
  String get ortakParolaZorunlu => 'Password is required';

  @override
  String get ortakYeniParola => 'New password';

  @override
  String get ortakYeniParolaTekrar => 'New password (again)';

  @override
  String get ortakYeniParolaZorunlu => 'New password is required';

  @override
  String get ortakParolalarEslesmiyor => 'Passwords do not match';

  @override
  String get parolaKuraliKisa => 'Must be at least 8 characters';

  @override
  String get parolaKuraliBuyukHarf =>
      'Must contain at least one uppercase letter';

  @override
  String get parolaKuraliRakam => 'Must contain at least one digit';

  @override
  String get parolaKuraliSembol =>
      'Must contain at least one symbol (! ? @ # . -)';

  @override
  String get profilYuklenemedi => 'Profile could not be loaded.';

  @override
  String get profilNumaraYok => 'No number entered';

  @override
  String get profilFotoBaslik => 'Profile photo';

  @override
  String get profilFotoSec => 'Choose photo';

  @override
  String get profilFotoGuncellendi => 'Profile photo updated ✓';

  @override
  String get profilFotoKaldirildi => 'Profile photo removed';

  @override
  String get ortakGaleri => 'Gallery';

  @override
  String get profilParolaDegistir => 'Change password';

  @override
  String get profilMevcutParola => 'Current password';

  @override
  String get profilMevcutParolaZorunlu => 'Current password is required';

  @override
  String get profilParolaGuncelle => 'Update password';

  @override
  String get profilParolaGuncellendi => 'Password updated ✓';

  @override
  String get profilTelefon => 'Phone';

  @override
  String get profilTelefonIpucu => 'e.g. +905551112233';

  @override
  String get profilAranabilir => 'Reachable by phone';

  @override
  String get profilAranabilirAlt =>
      'Authorized roles (consent-based calling) can reach your number';

  @override
  String get profilIletisimKaydet => 'Save contact details';

  @override
  String get profilIletisimGuncellendi => 'Contact details updated ✓';

  @override
  String get personelEkle => 'Add staff';

  @override
  String get personelDuzenle => 'Edit staff';

  @override
  String get personelListelenemedi => 'Staff could not be listed.';

  @override
  String get personelPasiflestir => 'Deactivate';

  @override
  String get personelAktiflestir => 'Activate';

  @override
  String get personelPasiflestirildi => 'Deactivated ✓';

  @override
  String get personelAktiflestirildi => 'Activated ✓';

  @override
  String get personelGuncellendi => 'Staff member updated ✓';

  @override
  String get personelEklendi => 'Staff member added ✓';

  @override
  String get personelFoto => 'Photo';

  @override
  String get personelTelefonOpsiyonel => 'Mobile number (optional)';

  @override
  String get personelBosBirakDegismezNokta =>
      'Leave empty to keep it unchanged.';

  @override
  String get personelYok =>
      'No field staff yet.\nAdd one from the bottom right.';

  @override
  String get disKisiEkle => 'Add contact';

  @override
  String get disListeAlinamadi => 'The list could not be loaded.';

  @override
  String get disKayitYokYonetim =>
      'No entries yet. Add a tradesperson you trust from the bottom right.';

  @override
  String get disKayitYok => 'No external service entries yet.';

  @override
  String get disNotEkleyin => 'Add a note (only management can edit).';

  @override
  String get disNotuDuzenle => 'Edit note';

  @override
  String get disBolumNotu => 'Section note';

  @override
  String get disNotIpucu =>
      'e.g. Tradespeople we have trusted for years; for site security, do not let strangers in.';

  @override
  String get disNotGuncellendi => 'Note updated ✓';

  @override
  String get disAra => 'Call';

  @override
  String get disSilOnay => 'Delete this entry?';

  @override
  String disSilGovde(Object ad) {
    return '\"$ad\" will be deleted.';
  }

  @override
  String get disSilindi => 'Deleted ✓';

  @override
  String get disYeniKisi => 'New external contact';

  @override
  String get disKisiDuzenle => 'Edit contact';

  @override
  String get disTur => 'Service type';

  @override
  String get disTurIpucu => 'e.g. Locksmith, Electrical, Plumbing';

  @override
  String get disTurZorunlu => 'Service type is required';

  @override
  String get disAd => 'First name';

  @override
  String get disSoyad => 'Last name';

  @override
  String get disAdGerekli => 'First name is required';

  @override
  String get disSoyadGerekli => 'Last name is required';

  @override
  String get nfcBaslik => 'NFC tag reading';

  @override
  String get nfcHazir => 'Ready to read. Tap Start.';

  @override
  String get nfcYaklastirBekliyor =>
      'Hold the tag against the back of the phone...';

  @override
  String get nfcOkundu => 'Tag read.';

  @override
  String get nfcOkumayaBasla => 'Start reading';

  @override
  String get nfcTekrarOku => 'Read again';

  @override
  String nfcKuyrukBekleyen(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n scans waiting to be sent',
      one: '$n scan waiting to be sent',
    );
    return '$_temp0';
  }

  @override
  String get nfcKuyruk => 'Send queue';

  @override
  String get nfcKaydedildiBekliyor =>
      'Saved ✓ — it will be sent automatically once you are online.';

  @override
  String get nfcKaydedildiGonderiliyor => 'Saved ✓ — sending...';

  @override
  String get nfcGonderildiZatenVar =>
      'Sent ✓ — this scan was already recorded.';

  @override
  String get nfcGonderildi => 'Sent ✓ — scan recorded.';

  @override
  String get nfcEslesmeYok => 'This tag does not match any checkpoint.';

  @override
  String get nfcSdmBaslik => 'SDM (raw, unverified)';

  @override
  String get nfcTipEtiket => 'Type';

  @override
  String nfcNoktalarAlinamadi(Object hata) {
    return 'Checkpoints could not be loaded: $hata';
  }

  @override
  String get nfcTestBaslik => 'TEST: which checkpoint to scan?';

  @override
  String get nfcTestAlt => 'Simulates a scan without a physical tag.';

  @override
  String get nfcAktifNoktaYok => 'No active checkpoints.';

  @override
  String get nfcAktifNoktaYokAlt => 'Add one from \"Checkpoints\" first.';

  @override
  String get nfcManuelOkut => 'Manual scan (test)';

  @override
  String get nfcTestGorunur => 'Visible only in test builds.';

  @override
  String nfcUidSatir(Object uid) {
    return 'UID: $uid';
  }

  @override
  String get nfcHataKapali =>
      'NFC is off. Please turn NFC on in device settings.';

  @override
  String get nfcHataDesteklenmiyor => 'This device does not support NFC.';

  @override
  String get nfcHataUidOkunamadi => 'The tag UID could not be read.';

  @override
  String nfcHataCozumlenemedi(Object detay) {
    return 'The tag could not be parsed: $detay';
  }

  @override
  String nfcHataOturum(Object detay) {
    return 'The NFC session could not be started: $detay';
  }

  @override
  String nfcHataOkumaIptal(Object detay) {
    return 'Reading was cancelled: $detay';
  }

  @override
  String nfcHataYapilandirma(Object detay) {
    return 'NFC is unavailable in this build: $detay. The app needs an update; retrying will not help.';
  }

  @override
  String get nfcHataBilinmeyen => 'An unknown error occurred.';

  @override
  String get nfcIosYaklastir => 'Hold the tag against the back of the phone.';

  @override
  String get nfcIosOkundu => 'Read';

  @override
  String get nfcIosIptal => 'Cancelled';

  @override
  String get nfcIosOkunamadi => 'Could not be read';

  @override
  String get seffafYuklenemedi => 'Could not load. Please try again.';

  @override
  String get seffafAyYayinlandi => 'The month was published.';

  @override
  String get seffafYayinGeriAlindi => 'Publication was withdrawn.';

  @override
  String get seffafVeriYokYonetim =>
      'No financial data yet. Months appear here once income/expense or dues are entered.';

  @override
  String get seffafVeriYok => 'Management has not published a summary yet.';

  @override
  String get seffafTaslakEki => ' • draft';

  @override
  String get seffafYayinla => 'Publish this month';

  @override
  String get seffafYayindaAlt => 'Residents can see this summary.';

  @override
  String get seffafOnizlemeAlt => 'Only management can see it (preview).';

  @override
  String get seffafOnizlemeUyari => 'Preview — not published yet.';

  @override
  String seffafOzetBaslik(Object ay) {
    return '$ay — Summary';
  }

  @override
  String get seffafToplamGelir => 'Total income';

  @override
  String get seffafToplamGider => 'Total expenses';

  @override
  String get seffafNet => 'Net';

  @override
  String seffafOncekiAyNet(Object tutar) {
    return 'Previous month net: $tutar';
  }

  @override
  String get seffafGiderDagilimi => 'Expense breakdown';

  @override
  String get seffafGiderYok => 'No expenses recorded this month.';

  @override
  String get seffafAidatToplama => 'Dues collection';

  @override
  String get seffafTahakkukYok => 'No assessment for this month.';

  @override
  String seffafOdeyenDaire(Object odeyen, Object toplam) {
    return 'Units paid: $odeyen/$toplam';
  }

  @override
  String seffafTahsilatSatir(Object tahsilat, Object tahakkuk, Object yuzde) {
    return 'Collected: $tahsilat / $tahakkuk  (amount: $yuzde%)';
  }

  @override
  String seffafGecikmede(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n units overdue',
      one: '$n unit overdue',
    );
    return '$_temp0';
  }

  @override
  String ortakYuzde(Object yuzde) {
    return '$yuzde%';
  }

  @override
  String get entegYeni => 'New';

  @override
  String get entegYokMesaj =>
      'No integrations. Add an external system (PA/smart home/webhook) with \"New\".';

  @override
  String get entegSilOnay => 'Delete it?';

  @override
  String entegSilGovde(Object ad) {
    return 'The \"$ad\" integration will be deleted.';
  }

  @override
  String entegSilinemedi(Object hata) {
    return 'Could not delete: $hata';
  }

  @override
  String get entegAktifKisa => 'active';

  @override
  String get entegPasifKisa => 'inactive';

  @override
  String entegKimlikSatir(Object tip, Object kilit) {
    return 'Auth: $tip$kilit';
  }

  @override
  String get entegTest => 'Test';

  @override
  String entegTestBasarili(Object durum) {
    return '✓ Success ($durum)';
  }

  @override
  String entegTestBasarisiz(Object hata, Object durum) {
    return '✗ $hata$durum';
  }

  @override
  String get entegBasarisiz => 'Failed';

  @override
  String get entegDuzenleBaslik => 'Edit integration';

  @override
  String get entegYeniBaslik => 'New integration';

  @override
  String get entegPreset => 'Ready-made template (preset)';

  @override
  String get entegKanalTipi => 'Channel type';

  @override
  String get entegUrl => 'Endpoint URL (http/https)';

  @override
  String get entegUrlHelper =>
      'Internal/private addresses are blocked when triggering';

  @override
  String get entegUrlHata => 'Must start with http(s)';

  @override
  String get entegHttpMetodu => 'HTTP method';

  @override
  String get entegKimlikDogrulama => 'Authentication';

  @override
  String get entegSir => 'Secret (bearer token / API key)';

  @override
  String get entegSirKayitli => 'Stored — enter a new value to change it';

  @override
  String get entegSirYazmaOzel => 'Write-only; never returned by the server';

  @override
  String get entegPayload => 'Payload template';

  @override
  String entegPayloadHelper(Object sablonlar) {
    return '$sablonlar placeholders';
  }

  @override
  String get entegTestMesaji => 'Test message';

  @override
  String get ortakAdGerekli => 'Name is required';

  @override
  String get ziyaretYeni => 'New visitor';

  @override
  String get ziyaretKaydedildi =>
      'Visitor recorded — the resident was notified ✓';

  @override
  String get ziyaretYokGuvenlik => 'No visitor records yet.';

  @override
  String get ziyaretYokSakin => 'No visitor records were shared with you.';

  @override
  String ziyaretBildirilenSakin(Object ad) {
    return 'Notified resident: $ad';
  }

  @override
  String get ziyaretSakiniAra => 'Call resident';

  @override
  String get ziyaretGuvenligiAra => 'Call security';

  @override
  String get ziyaretBilgileriDuzenle => 'Edit details';

  @override
  String get ziyaretGuncellendi => 'Visitor details updated ✓';

  @override
  String get ziyaretOnceDaireNo => 'Enter a unit number first';

  @override
  String get ziyaretSakiniSecin => 'Select the resident to notify';

  @override
  String get ziyaretDuzenleBaslik => 'Edit visitor';

  @override
  String get ziyaretDuzenleAlt =>
      'You can update the name, unit, notified resident and note.';

  @override
  String get ziyaretYeniAlt =>
      'The resident only gets a notification (no approval is requested).';

  @override
  String get ziyaretAdAlan => 'Visitor name *';

  @override
  String get ziyaretAdGerekli => 'Visitor name is required';

  @override
  String get ziyaretSakinleriGetir => 'Load residents';

  @override
  String get ziyaretBildirilecekSakin => 'Resident to notify *';

  @override
  String get ziyaretKaydetVeBildir => 'Save and notify the resident';

  @override
  String get raporBaslik => 'Monthly reports';

  @override
  String get raporOncekiAy => 'Previous month';

  @override
  String get raporSonrakiAy => 'Next month';

  @override
  String raporAyBaslik(Object ay, Object yil) {
    return '$ay $yil';
  }

  @override
  String get raporYetkiYok =>
      'You are not authorized for monthly reports. This screen is open to the site manager role.';

  @override
  String get raporGorevTamamlama => 'Task completion';

  @override
  String get raporAidat => 'Dues';

  @override
  String get raporSonTamamlamalar => 'Recent completions (first 10)';

  @override
  String get raporPlanlananPencere => 'Planned windows';

  @override
  String raporTamamlanmaYuzde(Object yuzde) {
    return 'Completion $yuzde%';
  }

  @override
  String get raporPencereYok => 'No patrol windows were planned this month.';

  @override
  String get raporGorevYok => 'No task completions this month.';

  @override
  String get raporToplamTamamlama => 'Total completions';

  @override
  String get raporAidatKayitYok =>
      'No assessment/payment records for this period.';

  @override
  String raporTahakkukDaire(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Assessed ($n units)',
      one: 'Assessed ($n unit)',
    );
    return '$_temp0';
  }

  @override
  String raporTahsilatOdeme(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Collected ($n payments)',
      one: 'Collected ($n payment)',
    );
    return '$_temp0';
  }

  @override
  String get raporKalanBakiye => 'Outstanding balance';

  @override
  String get aidatBaslik => 'My dues';

  @override
  String get aidatYetkiYok =>
      'Dues information is available only to resident accounts.';

  @override
  String get aidatDaireYok =>
      'No unit is registered to you. Please contact your management.';

  @override
  String get aidatToplamBakiye => 'Total balance (all units)';

  @override
  String get aidatBorcVar => 'Balance due';

  @override
  String get aidatBorcYok => 'No balance due';

  @override
  String get aidatToplamTahakkuk => 'Total assessed';

  @override
  String get aidatToplamOdenen => 'Total paid';

  @override
  String get aidatBakiye => 'Balance';

  @override
  String aidatHesapSatiri(Object tahakkuk, Object odenen, Object bakiye) {
    return 'Assessed $tahakkuk - paid $odenen = $bakiye';
  }

  @override
  String aidatTahakkuklar(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Assessments ($n)',
      one: 'Assessment ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatOdemeler(num n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Payments ($n)',
      one: 'Payment ($n)',
    );
    return '$_temp0';
  }

  @override
  String aidatSonOdeme(Object tarih) {
    return 'Due date: $tarih';
  }

  @override
  String aidatMakbuz(Object no) {
    return 'Receipt: $no';
  }

  @override
  String get aidatOdemeDurumuNotu =>
      'Payment status is updated only by confirmation from the payment provider; contact your management with questions.';

  @override
  String get aidatYontemElden => 'Cash';

  @override
  String get aidatYontemHavale => 'Bank transfer';

  @override
  String get aidatYontemKart => 'Card';

  @override
  String get aidatYontemDiger => 'Other';

  @override
  String get aidatDurumBasarili => 'Successful';

  @override
  String get aidatDurumIptal => 'Cancelled';

  @override
  String get noktaBaslik => 'Checkpoints';

  @override
  String get noktaEkle => 'Add checkpoint';

  @override
  String get noktaListelenemedi => 'Checkpoints could not be listed.';

  @override
  String get noktaSilOnay => 'Delete this checkpoint?';

  @override
  String noktaSilGovde(Object ad) {
    return 'The \"$ad\" checkpoint will be deleted.';
  }

  @override
  String get noktaSilindi => 'Checkpoint deleted ✓';

  @override
  String get noktaUidZatenVar => 'This NFC tag is already registered.';

  @override
  String get noktaDuzenleBaslik => 'Edit checkpoint';

  @override
  String get noktaYeniBaslik => 'New checkpoint';

  @override
  String get noktaAdIpucu => 'e.g. Main Entrance';

  @override
  String get noktaUidAlan => 'NFC tag UID';

  @override
  String get noktaUidIpucu => 'e.g. 04A2B3C4D5';

  @override
  String get noktaUidHelper => 'The tag\'s unique identifier (hex).';

  @override
  String get noktaEnlem => 'Latitude (opt.)';

  @override
  String get noktaKonumGecersiz => 'Invalid location. Example: 41.0082';

  @override
  String get ortakSecenekYuklenemedi =>
      'Some options could not be loaded — the list may be incomplete.';

  @override
  String get noktaBoylam => 'Longitude (opt.)';

  @override
  String get noktaPasifAlt => 'An inactive checkpoint will not match a scan';

  @override
  String get noktaYok => 'No checkpoints yet.';

  @override
  String get kuyrukHatalariTemizle => 'Clear permanent failures';

  @override
  String get kuyrukBos => 'The queue is empty.';

  @override
  String kuyrukOzet(Object bekleyen, Object hatali) {
    return '$bekleyen pending · $hatali permanent failures';
  }

  @override
  String get kuyrukSenkronla => 'Sync now';

  @override
  String get kuyrukBekliyor => 'Pending';

  @override
  String kuyrukBekliyorDeneme(Object n) {
    return 'Pending (attempt: $n)';
  }

  @override
  String get kuyrukGonderiliyor => 'Sending...';

  @override
  String get kuyrukGonderildiZatenVar => 'Sent (already recorded)';

  @override
  String get kuyrukGonderildiYeni => 'Sent (new record)';

  @override
  String kuyrukKaliciHata(Object hata) {
    return 'Permanent failure: $hata';
  }

  @override
  String get kuyrukEtiketEslesmedi => 'tag did not match';

  @override
  String get okutmaImzaGecersiz =>
      'The tag signature could not be verified — it may be a fake or wrong tag.';

  @override
  String get okutmaTekrarEdilmis => 'This scan was already processed.';

  @override
  String okutmaBeklenmeyenHata(Object detay) {
    return 'Unexpected error: $detay';
  }

  @override
  String get noktaUidZorunlu => 'NFC UID is required';

  @override
  String get hataZamanAsimi => 'Timed out while connecting to the server.';

  @override
  String get hataSunucuyaUlasilamadi =>
      'The server could not be reached. Check your network connection and the server address.';

  @override
  String get destekBaslik => 'Support';

  @override
  String get destekYeniTalep => 'New request';

  @override
  String get destekTalepYok => 'You have no support requests yet';

  @override
  String destekYuklenemedi(Object hata) {
    return 'Requests could not be loaded.\n$hata';
  }

  @override
  String destekGonderilemedi(Object hata) {
    return 'The request could not be sent: $hata';
  }

  @override
  String get destekYeniTalepBaslik => 'New support request';

  @override
  String get destekKonu => 'Subject';

  @override
  String get destekGorselEkle => 'Add image';

  @override
  String get destekGorseliDegistir => 'Change image';

  @override
  String get destekEkip => 'The Yönetiyor team';

  @override
  String get tesisKurulumBaslik => 'Set up your site';

  @override
  String get tesisKurulumAciklama =>
      'You have signed in as a manager for the first time. To continue, enter the name of your site; you can change it later in settings.';

  @override
  String get tesisAdiIpucu => 'e.g. Example Residence';

  @override
  String get tesisAdiKisa => 'The site name must be at least 2 characters';

  @override
  String get tesisOlustur => 'Create site';

  @override
  String get tesisAdiGuncellendi => 'Site name updated';

  @override
  String get tesisAdiAciklama =>
      'Shown in the home screen title; every user sees this name.';

  @override
  String get sikayetYokSakin =>
      'You have not opened a complaint yet.\nPick a unit on the Complaint Map to file one.';

  @override
  String sikayetSatirBaslik(Object daire, Object kategori) {
    return 'Unit $daire · $kategori';
  }

  @override
  String get sikayetDurumKapandi => 'Closed';

  @override
  String get vardiyaBaslik => 'Shifts';

  @override
  String get vardiyaYuklenemedi => 'Shifts could not be loaded.';

  @override
  String get vardiyaTanimYok => 'No shifts defined';

  @override
  String vardiyaSaatAraligi(Object baslangic, Object bitis, Object gunTipi) {
    return '$baslangic - $bitis • $gunTipi';
  }

  @override
  String get vardiyaPersonelAta => 'Assign staff';

  @override
  String vardiyaPersonelBaslik(Object ad) {
    return '$ad — Staff';
  }

  @override
  String get vardiyaPersonelGuncellendi => 'Shift staff updated ✓';

  @override
  String get vardiyaPersonelYuklenemedi => 'Staff could not be loaded.';

  @override
  String get vardiyaAtanabilirYok => 'No assignable staff';

  @override
  String get gunTipiHaftaIci => 'Weekdays';

  @override
  String get gunTipiHaftaSonu => 'Weekends';

  @override
  String get gunTipiResmiTatil => 'Public holidays';

  @override
  String get gunTipiHerGun => 'Every day';

  @override
  String get yonIletisimBaslik => 'Management contacts';

  @override
  String get yonIletisimAlinamadi => 'Management details could not be loaded.';

  @override
  String get yonIletisimTanimliDegil =>
      'No management contact details are defined.';

  @override
  String get yonIletisimMail => 'Management email';

  @override
  String get yonIletisimAra => 'Call the manager';

  @override
  String get aramaBaslatilamadi => 'The call could not be started';

  @override
  String get aramaYapilamiyor => 'Not callable';

  @override
  String get bildirimYok => 'No notifications';

  @override
  String bildirimYuklenemedi(Object hata) {
    return 'Notifications could not be loaded.\n$hata';
  }

  @override
  String get bildirimYeniPush => 'New notification';

  @override
  String get akisDevriyeOkutma => 'Patrol Scan';

  @override
  String get akisGorevTamamlandi => 'Task Completed';

  @override
  String get akisAidatOdemesi => 'Dues Payment';

  @override
  String get akisTalepAcildi => 'Request Opened';

  @override
  String get akisTalepIsEmri => 'Request Turned Into a Work Order';

  @override
  String get akisTalepCozuldu => 'Request Resolved';

  @override
  String get akisTalepReddedildi => 'Request Rejected';

  @override
  String get akisDaireSikayeti => 'Unit Complaint';

  @override
  String get akisAlarmKacirilanTur => 'Missed Patrol';

  @override
  String get akisAlarmEksikCheckpoint => 'Missing Checkpoint';

  @override
  String get akisAlarmGecikmisOkutma => 'Late Scan';

  @override
  String get akisZiyaretciGirisi => 'Visitor Check-In';

  @override
  String get akisZiyaretciCikisi => 'Visitor Check-Out';

  @override
  String get akisKargoKaydedildi => 'Parcel Registered';

  @override
  String get akisKargoTeslimEdildi => 'Parcel Handed Over';

  @override
  String get akisAracGirisi => 'Vehicle Entry';

  @override
  String get akisAracCikisi => 'Vehicle Exit';

  @override
  String get akisIhlalKaydi => 'Violation Record';

  @override
  String akisAltDaireTutar(Object daire, Object tutar) {
    return 'Unit $daire — $tutar';
  }

  @override
  String akisAltDaireKategori(Object daire, Object kategori) {
    return 'Unit $daire — $kategori';
  }

  @override
  String akisAltAdDaire(Object ad, Object daire) {
    return '$ad — Unit $daire';
  }

  @override
  String akisAltPlakaDaire(Object plaka, Object daire) {
    return '$plaka — Unit $daire';
  }

  @override
  String akisAltPlakaTanim(Object plaka, Object tanim) {
    return '$plaka ($tanim)';
  }

  @override
  String akisAltPlakaDaireTanim(Object plaka, Object daire, Object tanim) {
    return '$plaka — Unit $daire ($tanim)';
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
  String get ortakParolayiGoster => 'Show password';

  @override
  String get ortakParolayiGizle => 'Hide password';

  @override
  String get ortakFotograf => 'Photo';

  @override
  String get ortakFotografiBuyut => 'Enlarge photo';

  @override
  String get ortakGoster => 'View';

  @override
  String get talepRedBaslik => 'Reject request';

  @override
  String get ziyaretciDaireSakinYok => 'No active resident in this unit';

  @override
  String get ceviriOtomatik => 'This content was translated automatically';

  @override
  String get ceviriOtomatikKisa => 'Auto-translated';

  @override
  String get ceviriOrijinaliGor => 'View original';

  @override
  String get ceviriCeviriyiGor => 'View translation';

  @override
  String get ceviriHazirlaniyor =>
      'Translation in progress — showing the original';

  @override
  String get ceviriHazirlaniyorKisa => 'Translating…';

  @override
  String get ceviriYapilamadi => 'Translation failed — showing the original';

  @override
  String get ceviriYapilamadiKisa => 'Translation failed';

  @override
  String get modulAracGecis => 'Vehicle passes';

  @override
  String get modulOtopark => 'Parking';

  @override
  String get modulIhlaller => 'Violations';

  @override
  String get aracSuzgecTumu => 'All';

  @override
  String get aracSuzgecIceride => 'Inside';

  @override
  String get aracSuzgecCikmis => 'Left';

  @override
  String get aracPlakaAra => 'Search plate';

  @override
  String get aracListeBos => 'No vehicle passes recorded';

  @override
  String get aracAramaBos => 'No pass matches this plate';

  @override
  String get aracRozetIceride => 'Inside';

  @override
  String get aracRozetCikti => 'Left';

  @override
  String get aracRozetZiyaretci => 'Visitor';

  @override
  String aracGirisZamani(Object zaman) {
    return 'Entry: $zaman';
  }

  @override
  String aracCikisZamani(Object zaman) {
    return 'Exit: $zaman';
  }

  @override
  String aracDaire(Object no) {
    return 'Unit $no';
  }

  @override
  String get aracCikisVer => 'Check out';

  @override
  String get aracCikisOnayBaslik => 'Check this vehicle out?';

  @override
  String get aracCikisVerildi => 'Exit recorded';

  @override
  String get aracZatenKapali => 'This pass is already closed';

  @override
  String get aracYeniGiris => 'New entry';

  @override
  String get aracGirisKaydedildi => 'Vehicle entry recorded';

  @override
  String get aracPlaka => 'Plate';

  @override
  String get aracPlakaZorunlu => 'Plate is required';

  @override
  String get aracTanimAlani => 'Vehicle description (optional)';

  @override
  String get aracDaireAlani => 'Unit no (optional)';

  @override
  String get aracZiyaretciMi => 'Visitor vehicle';

  @override
  String get aracZatenIceride =>
      'This plate already has an open pass (vehicle inside)';

  @override
  String get aracErisimYok =>
      'The vehicle pass list is restricted to management and security';

  @override
  String aracKaydeden(Object ad) {
    return 'Recorded by: $ad';
  }

  @override
  String get otoparkDoluEtiket => 'Occupied';

  @override
  String get otoparkBosEtiket => 'Free';

  @override
  String get otoparkKapasiteEtiket => 'Capacity';

  @override
  String get otoparkKapasiteTanimsiz =>
      'Capacity is not set — only the number of vehicles inside is shown';

  @override
  String get otoparkAracListesi => 'Open vehicle passes';

  @override
  String get ihlalDurumYeni => 'New';

  @override
  String get ihlalDurumInceleniyor => 'Under review';

  @override
  String get ihlalDurumKapatildi => 'Closed';

  @override
  String get ihlalKaynakKamera => 'Camera';

  @override
  String get ihlalKaynakManuel => 'Manual';

  @override
  String get ihlalKaynakDevriye => 'Patrol';

  @override
  String get ihlalListeBos => 'No violation records';

  @override
  String get ihlalYeni => 'New violation';

  @override
  String get ihlalAcildi => 'Violation record created';

  @override
  String get ihlalBaslikAlani => 'Title';

  @override
  String get ihlalBaslikZorunlu => 'Title is required';

  @override
  String get ihlalAciklamaAlani => 'Description (optional)';

  @override
  String get ihlalKonumAlani => 'Location (optional)';

  @override
  String get ihlalKaynakAlani => 'Detection source';

  @override
  String get ihlalIncelemeyeAl => 'Start review';

  @override
  String get ihlalKapat => 'Close record';

  @override
  String get ihlalDurumGuncellendi => 'Violation status updated';

  @override
  String get ihlalKapatmaOnay =>
      'Close this record? A closed violation cannot be reopened.';

  @override
  String get ihlalKapaliDegistirilemez =>
      'A closed violation cannot be reopened';

  @override
  String get ihlalErisimYok =>
      'Violation records are restricted to management and security';

  @override
  String ihlalKaydeden(Object ad) {
    return 'Opened by: $ad';
  }

  @override
  String get kameraRestream => 'Restream URL (optional)';

  @override
  String get kameraRestreamAlt =>
      'Makes an RTSP camera playable. The HLS address of the Frigate/go2rtc gateway.';

  @override
  String get kameraRestreamHata =>
      'The restream URL must start with http:// or https://';

  @override
  String get kameraRestreamRozet => 'Via gateway';

  @override
  String get modulPlakaOlaylari => 'Plate readings';

  @override
  String get anprDurumIslendi => 'Processed';

  @override
  String get anprDurumOnayBekliyor => 'Awaiting approval';

  @override
  String get anprDurumYokSayildi => 'Ignored';

  @override
  String get anprDurumHata => 'Error';

  @override
  String get anprYonGiris => 'Entry';

  @override
  String get anprYonCikis => 'Exit';

  @override
  String get anprYonBilinmiyor => 'Direction unknown';

  @override
  String get anprListeBos => 'No plate readings';

  @override
  String get anprErisimYok =>
      'Plate readings are restricted to management and security';

  @override
  String anprGuven(Object oran) {
    return 'Confidence $oran%';
  }

  @override
  String get anprOnayla => 'Approve';

  @override
  String get anprReddet => 'Reject';

  @override
  String get anprOnayBaslik => 'Approve reading';

  @override
  String get anprOnayAciklama =>
      'You can correct the plate if it was misread. Approving opens or closes the vehicle pass.';

  @override
  String get anprKararUygulandi => 'Decision applied';

  @override
  String get anprOnayBeklemiyor =>
      'This reading is no longer awaiting approval';

  @override
  String get anprNedenDusukGuven => 'Low confidence';

  @override
  String get anprNedenZatenIceride => 'Vehicle already inside';

  @override
  String get anprNedenAcikGecisYok => 'No open pass';

  @override
  String get anprNedenOtomatikCikisKapali => 'Automatic exit is off';

  @override
  String get anprNedenElleReddedildi => 'Manually rejected';

  @override
  String get anprNedenPlakaBicimi => 'Plate could not be read';

  @override
  String get aracPlakaOkumalari => 'Plate readings';

  @override
  String get kategoriGoruntuKirliligi => 'Visual pollution';

  @override
  String get fabSikayetBildir => 'Report a neighbour complaint';

  @override
  String get sakinRolTipi => 'Relationship type';

  @override
  String get sakinRolMalik => 'Owner';

  @override
  String get sakinRolKiraci => 'Tenant';

  @override
  String get sakinRolDegisme => 'Leave unchanged';

  @override
  String get sakinRolAlt =>
      'Dues are charged to the tenant, investment costs to the owner.';

  @override
  String get sakinEposta => 'E-mail';

  @override
  String get sakinEpostaTemizle => 'Remove e-mail';

  @override
  String get sakinRolBagYok =>
      'The resident must be linked to a unit to set a relationship type';

  @override
  String get sikayetKuyruguBaslik => 'Complaint Queue';

  @override
  String get sikayetSekmeYeni => 'New';

  @override
  String get sikayetSekmeTumu => 'All';

  @override
  String get sikayetOkunmamisYok => 'No unread complaints.';

  @override
  String get sikayetYokYonetim => 'No complaints yet.';

  @override
  String get sikayetOkunduIsaretle => 'Mark as read';

  @override
  String sikayetOkunmamisRozet(int sayi) {
    return '$sayi unread complaints';
  }

  @override
  String get kameraHataAdresBozuk =>
      'The stream address is invalid. It may contain a stray space or line break.';

  @override
  String get kameraHataSemaDesteklenmiyor =>
      'This address type cannot be played directly. Define a restream address for the camera.';

  @override
  String get kameraHataSifrelenmemis =>
      'The unencrypted (http) stream was blocked by the device. A work profile or VPN may be disallowing it.';

  @override
  String kameraUrlCokUzun(int sinir) {
    return 'The stream address is too long (maximum $sinir characters).';
  }

  @override
  String get kameraUrlSifrelenmemisUyari =>
      'This address is unencrypted (http). Use https if possible.';

  @override
  String get modulDaireTanimlari => 'Unit Types';

  @override
  String get daireTanimSekmeTipler => 'Types';

  @override
  String get daireTanimSekmeGruplar => 'Groups';

  @override
  String get daireTanimAd => 'Name';

  @override
  String get daireTanimAdIpucu => 'e.g. 2+1, duplex, Villa';

  @override
  String get daireTanimVarsayilanAidat => 'Default dues';

  @override
  String get daireTanimAidatBos => 'Not set';

  @override
  String get daireTanimAidatAlt =>
      'Leaving it empty means not set; entering 0 means exempt.';

  @override
  String daireTanimDaireSayisi(int sayi) {
    return '$sayi units';
  }

  @override
  String daireTanimSilOnay(int sayi) {
    return 'Delete this definition? The $sayi linked units are NOT deleted; only their classification is cleared.';
  }

  @override
  String daireTanimSilindiEtki(int sayi) {
    return 'Deleted. $sayi units lost their classification.';
  }

  @override
  String get daireTanimYok => 'No definitions yet.';

  @override
  String get daireTanimYeni => 'New definition';

  @override
  String get daireTipiSecici => 'Unit type';

  @override
  String get daireGrubuSecici => 'Unit group';

  @override
  String get daireTanimSecilmedi => 'Not selected';

  @override
  String get odeBaslik => 'Pay';

  @override
  String get odeBorcunuz => 'Outstanding amount';

  @override
  String get odeHavaleBaslik => 'Bank transfer';

  @override
  String get odeHavaleAdim =>
      'Transfer to the IBAN and write the code below in the description. Without the code your payment may not be matched.';

  @override
  String get odeKodBaslik => 'Your reference code';

  @override
  String get odeKopyala => 'Copy';

  @override
  String get odeKopyalandi => 'Copied';

  @override
  String get odeKartBaslik => 'Pay by card';

  @override
  String get odeKartKapali =>
      'Card payment is not enabled yet. You can use a bank transfer for now.';

  @override
  String get odeHavaleKapali =>
      'The site has not defined a bank account yet. Please contact the management.';

  @override
  String get odeBorcYok => 'You have no outstanding debt.';

  @override
  String get odeBasarili => 'Your payment was received.';

  @override
  String get nfcFotoGerekli => 'A photo is required to start the patrol.';

  @override
  String get nfcFotoCek => 'Take a photo and send';

  @override
  String get nfcFotoYukleniyor => 'Uploading photo...';

  @override
  String nfcFotoYuklenemedi(String hata) {
    return 'Photo upload failed: $hata';
  }

  @override
  String get nfcKonumYok =>
      'Location unavailable — the scan was recorded without it.';

  @override
  String get nfcKonumIzinYok =>
      'Location permission denied — the scan was recorded without it.';

  @override
  String get nfcKonumServisKapali =>
      'Location services are off — the scan was recorded without it.';

  @override
  String get rolGuvenlikAmiri => 'Security Chief';

  @override
  String get rolDenetci => 'Auditor';

  @override
  String get kvkkBaslik => 'Privacy Notice';

  @override
  String get kvkkSonaKaydir => 'Scroll to the end of the text to approve.';

  @override
  String get kvkkOnayliyorum => 'I have read and approve';

  @override
  String get kvkkYuklenemedi => 'The privacy notice could not be loaded.';

  @override
  String get kvkkTekrarDene => 'Try again';

  @override
  String get kvkkSurumDegisti =>
      'The text was updated; please read the new version.';

  @override
  String get kvkkIzinBaslik => 'Campaigns and offers for me';

  @override
  String get kvkkIzinAciklama =>
      'Entirely optional; you can continue without approving. You can change this at any time in Settings.';

  @override
  String get kvkkIzinEposta => 'I want to receive e-mail';

  @override
  String get kvkkIzinSms => 'I want to receive SMS';

  @override
  String get kvkkIzinArama => 'I want to be called';

  @override
  String get kvkkIzinKaydedilemedi => 'The preference could not be saved.';

  @override
  String get kvkkAyarlarBaslik => 'Permissions and Privacy Notice';

  @override
  String get kvkkMetniGoruntule => 'View the privacy notice';

  @override
  String get anketBaslik => 'Surveys';

  @override
  String get anketYok => 'There is no open survey right now.';

  @override
  String get anketKapali => 'Closed';

  @override
  String get anketOyVerdiniz => 'Your vote was recorded';

  @override
  String get anketOyVer => 'Vote';

  @override
  String anketToplamOy(int sayi) {
    return '$sayi votes';
  }

  @override
  String anketOyHatasi(String hata) {
    return 'Vote could not be sent: $hata';
  }

  @override
  String get anketSonucKapali => 'Results appear once the survey closes.';

  @override
  String get modulAnketler => 'Surveys';

  @override
  String get hesapSilBolum => 'Account';

  @override
  String get hesapSilBaslik => 'Delete my account';

  @override
  String get hesapSilAlt => 'Permanently delete your account and personal data';

  @override
  String get hesapSilOnayBaslik => 'Delete your account?';

  @override
  String get hesapSilOnayGovde =>
      'Your name, phone number, e-mail address and device records will be deleted and you will no longer be able to sign in. Dues and payment records cannot be deleted because we are legally required to keep them; they will remain stored anonymously, no longer linked to your name.';

  @override
  String get hesapSilParolaEtiket => 'Your password';

  @override
  String get hesapSilParolaAciklama =>
      'Enter your password again for security.';

  @override
  String get hesapSilOnayla => 'Permanently delete my account';

  @override
  String get hesapSilSonucSilindi => 'Your account has been deleted.';

  @override
  String get hesapSilSonucAnonim =>
      'Your account has been deleted. Records we are legally required to keep were made anonymous.';

  @override
  String get hesapSilParolaGerekli => 'Enter your password to continue.';

  @override
  String get hesapSilSiliniyor => 'Deleting...';

  @override
  String get ayarlarHukuki => 'Legal';

  @override
  String get ayarlarGizlilik => 'Privacy Policy';

  @override
  String get ayarlarKosullar => 'Terms of Use';

  @override
  String get ayarlarBelgeAcilamadi =>
      'The page could not be opened. Check your internet connection.';

  @override
  String get demoSimuleOkutma => 'Simulated scan';

  @override
  String demoSimuleOkutmaBasarili(String nokta) {
    return 'Simulated scan recorded: $nokta';
  }

  @override
  String get demoSimuleOkutmaHata =>
      'The simulated scan could not be recorded.';

  @override
  String get denetciWebBaslik => 'Audit screens are on the web';

  @override
  String denetciWebGovde(String adres) {
    return 'Audit reports and financial oversight are designed for the desktop. Open $adres on your computer.';
  }

  @override
  String get denetciWebKopyala => 'Copy address';

  @override
  String get modulVardiyalar => 'Shifts';

  @override
  String get izgaraDuzenleBaslik => 'Edit home screen';

  @override
  String izgaraDuzenleAciklama(int enCok) {
    return 'Choose up to $enCok sections you use most.';
  }

  @override
  String get izgaraSifirla => 'Reset to default';

  @override
  String get izgaraKaydet => 'Save';

  @override
  String izgaraSecim(int secili, int enCok) {
    return '$secili/$enCok selected';
  }

  @override
  String izgaraTavanUyarisi(int enCok) {
    return 'You\'ve reached the limit. Remove one to add another ($enCok tiles).';
  }

  @override
  String get dilSeciciBaslik => 'Language';

  @override
  String get talepGeriAl => 'Withdraw';

  @override
  String get talepGeriAlOnay =>
      'Withdraw this request? A withdrawn request is not passed to management, and this cannot be undone.';

  @override
  String get talepGeriAlindi => 'Request withdrawn';

  @override
  String get talepDurumGeriAlindi => 'Withdrawn';

  @override
  String get sikayetGeriAl => 'Withdraw complaint';

  @override
  String get sikayetGeriAlindi => 'Complaint withdrawn';

  @override
  String get izinDevam => 'Continue';

  @override
  String get izinKonumBaslik => 'Why is location needed?';

  @override
  String get izinKonumGovde =>
      'When you scan a patrol checkpoint, your location at that moment is recorded to confirm the round was actually walked on site. Location is captured ONLY at the moment of scanning; the app does not track you in the background.';

  @override
  String get izinKameraBaslik => 'Why is the camera needed?';

  @override
  String get izinKameraGovde =>
      'The camera is used so you can attach a photo when reporting a request or fault. A photo is captured only when you take it, and it is sent to the building management.';

  @override
  String get girisKodlaBaslik => 'No password — sign in with a code';

  @override
  String get girisKodlaAciklama =>
      'We\'ll send a six-digit verification code to your phone.';

  @override
  String get girisKoduGonder => 'Send code';

  @override
  String get girisKodAlani => 'Verification code';

  @override
  String get hesapSilKodlaOnayla => 'No password — confirm with a code';

  @override
  String get hesapSilKodAciklama =>
      'We\'ll send a six-digit code to your email address to confirm deletion.';

  @override
  String get hesapSilKodGerekli => 'Enter the confirmation code';

  @override
  String get kayitBaslik => 'Sign in with Facility ID';

  @override
  String get kayitAltBaslik => 'Choose what applies to you';

  @override
  String get kayitRolYonetici => 'Manager';

  @override
  String get kayitRolSakin => 'Resident';

  @override
  String get kayitRolGuvenlik => 'Security officer';

  @override
  String get kayitRolTesisGorevlisi => 'Facility staff';

  @override
  String get kayitTesisKodu => 'Facility ID';

  @override
  String get kayitTesisKoduIpucu =>
      'The code your management gave you (e.g. OLTU-260715)';

  @override
  String get kayitDaireNo => 'Unit no';

  @override
  String get kayitBlok => 'Block (if any)';

  @override
  String get kayitDevam => 'Continue';

  @override
  String get kayitKodBaslik => 'Verification code';

  @override
  String kayitKodAciklama(String tesis, String telefon) {
    return 'A code was sent to $telefon for $tesis. If the number is not registered, no code will arrive.';
  }

  @override
  String get kayitKodAlani => '6-digit code';

  @override
  String get kayitTesisKoduGerekli => 'Facility ID is required.';

  @override
  String get kayitDaireGerekli => 'Unit no is required.';

  @override
  String get kayitKodGerekli => 'Enter the code.';

  @override
  String get kayitYontemBaslik => 'How will you sign in?';

  @override
  String get kayitYontemParola => 'Create a password';

  @override
  String get kayitGirisLinki => 'Already have an account? Sign in';

  @override
  String kayitAdim(String n, String toplam) {
    return 'Step $n/$toplam';
  }

  @override
  String sosyalIleDevam(String saglayici) {
    return 'Continue with $saglayici';
  }

  @override
  String get sosyalBaslik => 'Match your account';

  @override
  String sosyalEslesmeAciklama(String saglayici) {
    return 'Your $saglayici account is verified. Enter your facility ID and phone number so we can find your account.';
  }

  @override
  String get sosyalRelayUyari =>
      'Apple hid your e-mail address; mail cannot be sent to it.';

  @override
  String get sosyalTesisKodu => 'Facility ID';

  @override
  String get sosyalKodGonder => 'Send verification code';

  @override
  String sosyalKodAciklama(String tesis, String telefon) {
    return '$tesis — enter the code sent to $telefon.';
  }

  @override
  String get sosyalDogrula => 'Verify and sign in';

  @override
  String get sosyalVazgec => 'Cancel';

  @override
  String get davetBaslik => 'Registration';

  @override
  String get davetGecersizBaslik => 'Link not working';

  @override
  String get davetSuresiDoldu => 'This invitation link has expired.';

  @override
  String get davetKullanilmis => 'This invitation has already been used.';

  @override
  String get davetBulunamadi => 'This invitation link is invalid.';

  @override
  String get davetYoneticinizeBasvurun =>
      'Contact your administrator for a new invitation.';

  @override
  String davetOzet(String tesis, String rol) {
    return '$tesis invited you as $rol.';
  }

  @override
  String get kayitYontemEposta => 'Continue with email';

  @override
  String get kayitYontemVeya => 'or';

  @override
  String get kayitBilgilerBaslik => 'Your details';

  @override
  String get kayitAdSoyad => 'Full name';

  @override
  String get kayitAdGerekli => 'Full name is required.';

  @override
  String get kayitParola => 'Password';

  @override
  String get kayitParolaGerekli => 'Password must be at least 8 characters.';

  @override
  String get kayitTesisAdBaslik => 'Create your property';

  @override
  String get kayitTesisAd => 'Enter the property name';

  @override
  String get kayitTesisAdIpucu => 'e.g. Oltu Residences';

  @override
  String get kayitTesisAdGerekli => 'Property name is required.';

  @override
  String get kayitZatenSitemVar => 'I already have a property';

  @override
  String get kayitTesisKoduBaslik => 'Your property code';

  @override
  String get kayitTesisKoduPaylas =>
      'Share this code with your residents and staff; they use it to join.';

  @override
  String get kayitKopyala => 'Copy';

  @override
  String get kayitKopyalandi => 'Copied';

  @override
  String get kayitTamamla => 'Continue';

  @override
  String get kayitSosyalAdNotu =>
      'Name taken from your account; you can change it.';

  @override
  String get kayitEposta => 'Email';

  @override
  String get kayitEpostaGerekli => 'Email address is required.';

  @override
  String get kayitEpostaGecersiz => 'Enter a valid email.';

  @override
  String get kayitTelefonIletisim => 'Phone (optional)';

  @override
  String get kayitTelefonNotu =>
      'Phone is for contact only; verification is done by email.';

  @override
  String get kayitTesisKoduGir => 'Enter your Facility ID';

  @override
  String kayitKodAciklamaEposta(String tesis) {
    return 'We sent a verification code to your email for $tesis. If your address isn\'t registered, no code will arrive.';
  }

  @override
  String get kayitOnayBekliyorBaslik => 'Awaiting manager approval';

  @override
  String get kayitOnayBekliyorAciklama =>
      'Your details could not be verified and were sent to your manager for approval. Check your Facility ID; if the problem persists, consult your manager. Once approved, you can sign in.';

  @override
  String get kayitGiriseDon => 'Back to sign in';

  @override
  String get sosyalTamamlaBaslik => 'Complete with Facility ID';

  @override
  String sosyalTamamlaAciklama(String saglayici) {
    return 'Your $saglayici account is verified. To complete, enter your role and Facility ID.';
  }

  @override
  String get sosyalRol => 'Your role';

  @override
  String get sosyalTamamla => 'Complete';

  @override
  String get sosyalOtpAciklama =>
      'Enter the verification code sent to your email.';

  @override
  String get binaYapisalAraclar => 'Structural tools';

  @override
  String get binaKatSil => 'Delete floor';

  @override
  String get binaTopluTip => 'Bulk change status';

  @override
  String get binaSiralama => 'Edit ordering';

  @override
  String binaKatSilOzet(int n) {
    return '$n units will be deleted';
  }

  @override
  String binaKatSilOnay(int kat) {
    return 'All units on floor $kat will be permanently deleted. This cannot be undone.';
  }

  @override
  String get binaAralikSec => 'Select by number';

  @override
  String get binaAralikUygula => 'Select';

  @override
  String binaSeciliSayisi(int n) {
    return '$n units selected';
  }

  @override
  String binaAralikBulunamayan(String parca) {
    return 'Not found: $parca';
  }

  @override
  String get ortakEminMisiniz => 'Are you sure?';

  @override
  String get ortakDurum => 'Status';

  @override
  String get ortakAktif => 'Active';

  @override
  String get ortakPasif => 'Inactive';

  @override
  String get binaBaslangicKat => 'Start floor';

  @override
  String get binaBaslangicKatIpucu =>
      'Negative for basements: -2, -1, 0 (ground), 1…';

  @override
  String get rezSekmeGecmis => 'Past';

  @override
  String get rezGecmisYok => 'No past reservations.';

  @override
  String get rezGecmisTamam => 'Completed';

  @override
  String rezIptalEden(String ad) {
    return 'Cancelled by: $ad';
  }

  @override
  String get binaKatBos =>
      'No units on this floor; deleting affects no records.';

  @override
  String binaKatOzet(int daire, int sakin, int talep) {
    return '$daire units · $sakin residents · $talep open complaints';
  }

  @override
  String binaKatOzetMali(int tahakkuk, int odeme, int rezervasyon) {
    return '$tahakkuk assessments · $odeme payments · $rezervasyon reservations';
  }

  @override
  String get binaKatMaliUyari =>
      'This floor has dues records. Deleting it permanently removes assessments and payments; the accounting trail cannot be restored. Consider deactivating the units instead.';

  @override
  String binaKatOnayYaz(int kat) {
    return 'Type the floor number to confirm ($kat)';
  }

  @override
  String binaKatSilOzetOnay(
    String blok,
    int kat,
    int daire,
    int sakin,
    int kayit,
  ) {
    return 'Floor $kat of block $blok will be deleted: $daire units, $sakin residents and $kayit linked records are removed permanently. This cannot be undone.';
  }

  @override
  String get kurulumBaslik => 'Setup Wizard';

  @override
  String get kurulumAlt =>
      'Complete the steps to get your facility ready to use.';

  @override
  String get kurulumIlerleme => 'Progress';

  @override
  String get kurulumTamamlandi => 'Setup complete';

  @override
  String kurulumAdimTamam(int sayi) {
    return '$sayi records';
  }

  @override
  String get kurulumAdimAtlandi => 'Skipped';

  @override
  String get kurulumAdimBekliyor => 'Pending';

  @override
  String get kurulumGit => 'Go';

  @override
  String get kurulumGoruntule => 'View';

  @override
  String get kurulumAtla => 'Skip';

  @override
  String get kurulumAtlamayiGeriAl => 'Undo skip';

  @override
  String kurulumSayac(int gecilen, int toplam) {
    return '$gecilen/$toplam steps';
  }

  @override
  String get kurulumHata => 'Could not load setup status.';

  @override
  String get kurulumBlok => 'Blocks';

  @override
  String get kurulumBlokAlt => 'Define the building blocks.';

  @override
  String get kurulumDaire => 'Units';

  @override
  String get kurulumDaireAlt => 'Create floors and units in bulk.';

  @override
  String get kurulumDaireTipi => 'Unit types';

  @override
  String get kurulumDaireTipiAlt => 'Define types and default dues amounts.';

  @override
  String get kurulumSakin => 'Residents';

  @override
  String get kurulumSakinAlt => 'Add residents to units.';

  @override
  String get kurulumPersonel => 'Staff';

  @override
  String get kurulumPersonelAlt => 'Enter employee records.';

  @override
  String get kurulumGorevAlani => 'Task categories';

  @override
  String get kurulumGorevAlaniAlt =>
      'Create the categories your tasks will be grouped by.';

  @override
  String get kurulumNfc => 'NFC checkpoints';

  @override
  String get kurulumNfcAlt => 'Define patrol checkpoints.';

  @override
  String get kurulumAidat => 'Dues assessment';

  @override
  String get kurulumAidatAlt => 'Issue the first period\'s dues to units.';

  @override
  String get kurulumAdimWebde =>
      'This step can currently only be done from the web panel with a platform administrator account.';

  @override
  String get kurulumHatirlaticiBaslik => 'Finish the setup';

  @override
  String get kurulumHatirlaticiMetin =>
      'A few steps remain before your facility is ready. The wizard takes you to each screen in turn.';

  @override
  String get kurulumHatirlaticiGit => 'Open the wizard';

  @override
  String get kurulumHatirlaticiSonra => 'Later';

  @override
  String get noktaYokAlt =>
      'Checkpoints are the NFC tags scanned during patrol rounds.';

  @override
  String get devriyePlanYokAlt =>
      'A patrol plan defines which checkpoints are scanned and when.';

  @override
  String get personelYokAlt =>
      'Create security and facility officer accounts here.';

  @override
  String get sakinYokAlt =>
      'Added residents are linked to units and can sign in to the app.';

  @override
  String get ortakDahaFazlaSecenek => 'More options';

  @override
  String get modulDokumanlar => 'Site Documents';

  @override
  String get dokumanBaslik => 'Site Documents';

  @override
  String get dokumanAra => 'Search document names';

  @override
  String get dokumanYokSakin => 'No documents have been shared yet.';

  @override
  String get dokumanAramaSonucYok => 'No document matches your search.';

  @override
  String get dokumanAcilamadi => 'The document could not be opened.';

  @override
  String dokumanBoyutKb(int kb) {
    return '$kb KB';
  }

  @override
  String get kvkkYasalMetinler => 'Legal Texts';

  @override
  String get kvkkTurAydinlatma => 'Privacy Notice';

  @override
  String get kvkkTurAcikRiza => 'Explicit Consent';

  @override
  String get kvkkTurGizlilik => 'Privacy Policy';

  @override
  String get kvkkTurKullanim => 'Terms of Use';

  @override
  String get kvkkTurCerez => 'Cookie Policy';

  @override
  String get kvkkMetinYayinlanmamis => 'This text has not been published yet.';

  @override
  String get kvkkOnaylanmadi => 'You have not consented to this text yet.';

  @override
  String get kvkkYenidenOnayBekleniyor =>
      'Your consent is awaited for the current version.';

  @override
  String kvkkSurumEtiketi(int n) {
    return 'Version $n';
  }

  @override
  String kvkkOnayladiginizSurum(int n) {
    return 'Version you consented to: $n';
  }

  @override
  String get kabukKisayollar => 'Shortcuts';

  @override
  String get ayarlarBildirimlerBaslik => 'Notifications';

  @override
  String get ayarlarBildirimTercih => 'Notification preferences';

  @override
  String get ayarlarBildirimAciklama =>
      'Choose which channels send you operational notifications. This is separate from marketing consent.';

  @override
  String get ayarlarBildirimEposta => 'Email notifications';

  @override
  String get ayarlarBildirimSms => 'SMS notifications';

  @override
  String get ayarlarBildirimMobil => 'Mobile notifications';

  @override
  String get ayarlarBildirimKaydedildi => 'Notification preference updated';

  @override
  String get ayarlarBildirimYuklenemedi =>
      'Could not load notification preferences';

  @override
  String get ayarlarBildirimIzinKapali =>
      'Device notification permission is off. Mobile notifications will not appear on the phone; enable it in device settings.';

  @override
  String get ayarlarBildirimIzinBelirsiz =>
      'Permission is needed to show notifications.';

  @override
  String get ayarlarBildirimIzinIste => 'Request permission';

  @override
  String get surumZorunluBaslik => 'Update required';

  @override
  String get surumZorunluMetin =>
      'This version can no longer be used. Update the app to continue.';

  @override
  String get surumOnerilenBaslik => 'A new version is available';

  @override
  String get surumOnerilenMetin => 'Update the app for a better experience.';

  @override
  String get surumGuncelle => 'Update';

  @override
  String get surumSimdiGuncelle => 'Update now';

  @override
  String get surumSonra => 'Later';

  @override
  String get surumMagazaAcilamadi =>
      'Could not open the store. You can update the app manually from your phone\'s app store.';

  @override
  String get tesisDegistirBaslik => 'Switch facility';

  @override
  String get tesisDegistirSecili => 'You are here';

  @override
  String get ziyaretDaireAra => 'Unit';

  @override
  String get ziyaretDaireAraIpucu => 'Type a unit number or a resident\'s name';

  @override
  String get vardiyaPlaniBaslik => 'Shift plan';

  @override
  String get vardiyaSuAnGorevde => 'On duty now';

  @override
  String get vardiyaSuAnKimseYok => 'Nobody is scheduled right now.';

  @override
  String get vardiyaSiradaki => 'Next shift';

  @override
  String get vardiyaSiradakiYok => 'No upcoming shift is planned.';

  @override
  String get vardiyaBos => 'Unstaffed';

  @override
  String get vardiyaYeni => 'New shift';

  @override
  String get vardiyaKayitYok => 'No shifts are planned this week.';

  @override
  String get vardiyaPersonel => 'Staff member';

  @override
  String get vardiyaBaslangicTarihi => 'Start date';

  @override
  String get vardiyaBitisTarihi => 'End date';

  @override
  String get vardiyaBaslangicSaati => 'Start time';

  @override
  String get vardiyaBitisSaati => 'End time';

  @override
  String get vardiyaNot => 'Note';

  @override
  String get vardiyaEkleBilgi =>
      'If you give a date range, a separate shift is created for every day in it. If the end time is earlier than the start time (22:00–05:00), the shift runs into the next day.';

  @override
  String get vardiyaEkleGonder => 'Add shifts';

  @override
  String get vardiyaCakisanHaric => 'Add, skipping conflicts';

  @override
  String vardiyaCakisanGunler(int n) {
    return '$n days have conflicts';
  }

  @override
  String get finansTahsilatBaslik => 'Collection';

  @override
  String get finansKisiGerekli => 'Select a person.';

  @override
  String get finansKasaGerekli => 'Select a cash account.';

  @override
  String get finansTutarGerekli => 'Enter a valid amount.';

  @override
  String get finansTahsilatKaydedildi => 'Payment recorded.';

  @override
  String get finansBorcluYok => 'There are no debtors right now.';

  @override
  String get finansAlanTutar => 'Amount';

  @override
  String get finansSutunKasa => 'Cash account';

  @override
  String get finansOdeyenKisi => 'Paying person';

  @override
  String get finansAlanAciklama => 'Description';

  @override
  String get finansMakbuzNotu =>
      'The receipt number and the resident notification are produced on the server — same as on the web.';

  @override
  String finansGecikmeGun(int n) {
    return '$n days overdue';
  }

  @override
  String get finansGiderBaslik => 'Expense entry';

  @override
  String get finansGiderKaydedildi => 'Expense recorded.';

  @override
  String get finansGiderTuru => 'Expense type';

  @override
  String get finansOnayBekliyor => 'Send for approval';

  @override
  String get finansOnayBekliyorNotu =>
      'An expense awaiting approval does NOT reduce the balance; it does once approved.';

  @override
  String get finansFisEkle => 'Add receipt photo';

  @override
  String get finansFisEklendi => 'Receipt added';

  @override
  String get finansFisYuklenemedi =>
      'The expense was recorded but the receipt could not be uploaded. You can add it from the web.';

  @override
  String get finansBorclularBaslik => 'Debtors';

  @override
  String get finansTahsilatOrani => 'Collection rate';

  @override
  String get finansOranYok => 'No assessments for this period.';

  @override
  String finansOranDegeri(int oran, String donem) {
    return '$oran% · $donem';
  }

  @override
  String finansKovaDaire(int n) {
    return '$n units';
  }

  @override
  String finansHatirlat(int n) {
    return 'Remind $n people';
  }

  @override
  String finansHatirlatmaGonderildi(int n) {
    return '$n reminders sent.';
  }

  @override
  String get personelEposta => 'E-mail';

  @override
  String get personelEpostaYardim =>
      'The invitation and password link are sent to this address.';

  @override
  String get personelEpostaGerekli => 'E-mail is required.';

  @override
  String get personelEpostaGecersiz => 'Enter a valid e-mail address.';

  @override
  String get sayacOkumaBaslik => 'Meter reading';

  @override
  String get sayacKalem => 'Billing item';

  @override
  String get sayacAnaSayac => 'Main meter';

  @override
  String get sayacDonem => 'Period (YYYY-MM)';

  @override
  String get sayacAnaTuketim => 'Main meter consumption';

  @override
  String get sayacBirimFiyat => 'Unit price';

  @override
  String get sayacBorclandir => 'Create charges';

  @override
  String get sayacFotoEkle => 'Meter photo';

  @override
  String get sayacBolumYok => 'No unit meters are linked to this main meter.';

  @override
  String get sayacKalemGerekli => 'Select an item and a main meter.';

  @override
  String get sayacAnaTuketimGerekli => 'Enter the main meter consumption.';

  @override
  String get sayacBirimFiyatGerekli => 'Enter the unit price.';

  @override
  String get sayacDegerYok => 'Enter a reading for at least one unit.';

  @override
  String sayacDegerGecersiz(String daire) {
    return 'The value entered for $daire is invalid.';
  }

  @override
  String sayacGeriSayiyor(String daire) {
    return '$daire: the new reading cannot be lower than the previous one.';
  }

  @override
  String sayacOncekiOkuma(String deger) {
    return 'Previous: $deger';
  }

  @override
  String sayacBorclandirildi(int n) {
    return 'Charges created. Units skipped: $n';
  }

  @override
  String get ayarlarBildirimSesi => 'Sound alerts';

  @override
  String get ayarlarBildirimSesiAciklama =>
      'Complaint and shift notifications arrive with sound.';

  @override
  String get ayarlarBildirimSesiUyari =>
      'Sound alerts are off: you may not hear shift reminders and complaint notifications.';

  @override
  String get vardiyaCikar => 'Remove';

  @override
  String get vardiyaCikarSebep =>
      'Reason for removal (illness, leave, emergency)';
}
