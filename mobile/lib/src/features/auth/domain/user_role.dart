/// Rol modeli (contracts/auth.md §4) — JWT `role` claim'inin istemci aynasi.
///
/// Buradaki yetenek bayraklari YALNIZCA menu/ekran gorunurlugu icindir
/// (UX hizalamasi). Gercek yetki her istekte backend RBAC'ta zorlanir;
/// istemci suzgeci atlatilsa bile backend 403 doner.
///
/// KIMLIK / METIN AYRIMI (README §15): enum METIN TASIMAZ. Eski `label` (TR
/// sabiti) tur 8'de KALDIRILDI; gorunen ad `presentation/rol_adi.dart`
/// icindeki `rolAdi(l10n, rol)` ile cizim aninda cozulur
/// (`CameraUrlHatasi` emsali: enum domain'de, `switch` cizim katmaninda).
library;

enum UserRole {
  /// Platform admini (biz) — panel + tum operasyon uclari.
  admin('admin'),

  /// Site yoneticisi (musteri) — mobil; gorev atama/takip, rapor okuma.
  /// Saha kaniti uretmez (scan/tamamlama/zimmet yok).
  yonetici('yonetici'),

  /// Guvenlik gorevlisi — devriye + saha operasyonu.
  security('security'),

  /// Tesis gorevlisi (temizlik + bahcivan + teknik; eski `cleaning`).
  tesisGorevlisi('tesis_gorevlisi'),

  /// Site sakini — v0'da operasyon erisimi yok.
  resident('resident'),

  /// (P35) Guvenlik amiri — guvenligi DIS BIR SIRKET yurutuyorsa vardiya ve
  /// tur planlamasinin sahibi. Sakin/finans/kargo alanlari BILINCLI olarak
  /// KAPALIDIR (dis sirket = en az yetki).
  guvenlikAmiri('guvenlik_amiri'),

  /// Claim yok/bilinmeyen deger (eski token, bozuk payload).
  unknown('unknown');

  const UserRole(this.wire);

  /// Backend enum degeri (user_role).
  final String wire;

  static UserRole fromClaim(String? value) => UserRole.values.firstWhere(
    (r) => r.wire == value,
    orElse: () => UserRole.unknown,
  );

  /// Turlarim (`GET /me/patrol-window`) — auth.md: admin + security
  /// (+ P35 guvenlik amiri: kendi ekibinin turlerini yurutur/izler).
  bool get canViewMyPatrol =>
      this == admin || this == security || this == guvenlikAmiri;

  /// Bildirim kutusu (`GET /notifications`) — admin + yonetici + security
  /// (+ P35 amir: P34 alarmlarinin muhatabi). tesis_gorevlisi ERISMEZ.
  bool get canViewNotifications =>
      this == admin || this == yonetici || this == security ||
      this == guvenlikAmiri;

  /// (P35) Guvenlik ALANI: tur/vardiya/kamera/alarm ekranlari. Yazma yetkisi
  /// TENANT MODUNA baglidir ve SUNUCUDA belirlenir — istemci yalnizca
  /// ekranin GORUNURLUGUNU secer.
  bool get isGuvenlikYonetimi =>
      this == admin || this == yonetici || this == guvenlikAmiri;

  /// Saha kaniti ureten akislar: scan gonderme, gorev tamamlama, zimmet,
  /// foto yukleme — admin + security + tesis_gorevlisi.
  bool get isFieldWorker =>
      this == admin || this == security || this == tesisGorevlisi ||
      // Amir de saha kaniti uretir: turu bizzat yurutebilir.
      this == guvenlikAmiri;

  /// Gorev listesi/detayi okuma — saha rolleri + yonetici (takip).
  bool get canViewTasks => isFieldWorker || this == yonetici;

  /// Duyuru olusturma/duzenleme/silme (mobil UX) — YALNIZ yonetici: duyuru
  /// site yonetiminin agzi (canli test karari). admin mobilde salt okur
  /// (moderasyonu panelden yapar); okuma herkese acik.
  bool get canManageAnnouncements => this == yonetici;

  /// Gorev olusturma/duzenleme/silme (`POST/PATCH/DELETE /tasks`) —
  /// admin + yonetici (yonetici yalniz saha rollerine atayabilir; 422).
  bool get canManageTasks => this == admin || this == yonetici;

  /// Seffaflik Panosu yayinlama (ay yayinla/geri-al) — admin + yonetici.
  bool get canPublishTransparency => this == admin || this == yonetici;

  /// Seffaflik Panosu goruntuleme — tum bilinen roller (sakin dahil; ANONIM
  /// agregat ozet). unknown haric.
  bool get canViewTransparency => this != unknown;

  /// Sikayet/oneri ekranini gorme — yasayan/calisandan yonetime kanal
  /// (kesin kural, auth.md §4): acan roller kendi taleplerini, yonetim
  /// (admin/yonetici) tumunu gorur. Bilinen 5 rolun 5'i de erisir.
  bool get canViewComplaints => this != unknown;

  /// Talep ACMA (`POST /complaints`) — acan roller: security +
  /// tesis_gorevlisi + resident. yonetici ACAMAZ (kanalin cevaplayan
  /// tarafi); admin de acmaz (platform operatoru).
  bool get canCreateComplaint =>
      this == security || this == tesisGorevlisi || this == resident;

  /// Talep yanitla/durum degistir (`PATCH /complaints/{id}`) —
  /// admin + yonetici; acan roller cevaplayamaz.
  bool get canRespondComplaints => this == admin || this == yonetici;

  /// Ziyaretci LISTESINI dogrudan gorme (`GET /visitors`) — GIZLILIK/KVKK
  /// (auth.md §4): YALNIZ security (kapi ops/vardiya devri) + resident (kendine
  /// HEDEFLENEN kayitlar). admin VE yonetici VARSAYILAN KAPALI (403) — daireyi
  /// gormek icin tek-seferlik izin alirlar (bkz. canRequestUnitAccess).
  /// tesis_gorevlisi ERISMEZ.
  bool get canViewVisitors => this == security || this == resident;

  /// Ziyaretci kaydi acma (`POST /visitors`) — YALNIZ security (kapi
  /// operasyonu). Hedef sakini secer (target_resident_user_id). Ziyaretci
  /// artik LOG-ONLY: onay/red YOK (sakin yaniti kaldirildi).
  bool get canRegisterVisitor => this == security;

  /// Kargo LISTESINI dogrudan gorme (`GET /kargo`) — ziyaretci ile ayni
  /// gizlilik: security + resident (kendi dairesi); admin+yonetici varsayilan
  /// kapali. tesis_gorevlisi ERISMEZ (auth.md §4).
  bool get canViewKargo => canViewVisitors;

  /// Tek-seferlik daire goruntuleme izni TALEBI acma
  /// (`POST /unit-access-request`) — admin + yonetici (ziyaretci/kargo onlara
  /// varsayilan kapali; sakin-onayli scoped erisim icin talep acar).
  bool get canRequestUnitAccess => this == admin || this == yonetici;

  /// Gelen erisim talebini onaylama/reddetme (`PATCH /unit-access-request/{id}`)
  /// — YALNIZ resident (talebin ait oldugu dairenin aktif sakini; sunucu zorlar).
  bool get canDecideUnitAccess => this == resident;

  /// Kargo kaydi acma (`POST /kargo`) — YALNIZ security (kapi operasyonu).
  bool get canRegisterKargo => this == security;

  /// Kargo teslim alma (`PATCH /kargo/{id}`) — YALNIZ resident (o dairenin
  /// aktif sakini olma kosulunu sunucu ayrica zorlar).
  bool get canReceiveKargo => this == resident;

  /// Ortak alan yonetimi (`POST/PATCH /common-areas`) — admin + yonetici.
  bool get canManageCommonAreas => this == admin || this == yonetici;

  /// Rezervasyon ekranini gorme (`GET /reservations`) — yonetim tumu, sakin
  /// kendi dairesi; saha rolleri ERISMEZ (auth.md §4).
  bool get canViewReservations =>
      this == admin || this == yonetici || this == resident;

  /// Rezervasyon talebi (`POST /reservations`) — YALNIZ resident (yonetim
  /// karar veren taraf; talep acmaz).
  bool get canRequestReservation => this == resident;

  /// Rezervasyon karari (`PATCH /reservations/{id}`) — admin + yonetici.
  bool get canDecideReservations => this == admin || this == yonetici;

  /// Etkinlik olustur/duzenle/sil (`POST/PATCH/DELETE /events`) —
  /// admin + yonetici (duyuru deseni).
  bool get canManageEvents => this == admin || this == yonetici;

  /// Etkinlik RSVP (`PUT /events/{id}/rsvp`) — YALNIZ resident (etkinligin
  /// muhatabi sakinler; personel beyan vermez — auth.md §4).
  bool get canRsvpEvents => this == resident;

  /// Etkinlik okuma + SEFFAF sayilar — bilinen 5 rolun 5'i.
  bool get canViewEvents => this != unknown;

  /// Site kurali ekle/duzenle/sil (`POST/PATCH/DELETE /site-rules`) —
  /// admin + yonetici; okuma bilinen tum rollerde (auth.md §4).
  bool get canManageSiteRules => this == admin || this == yonetici;

  /// Dis sistem entegrasyonlari (`/integrations`, C1b — CRUD + tetik) —
  /// admin + yonetici. admin panelden, yonetici mobilden yonetir (auth.md §4).
  bool get canManageIntegrations => this == admin || this == yonetici;

  // ---------------------------------------------------------------------- //
  // Arac gecisi (G1) + Otopark (G4) + Ihlal (G2)
  // ---------------------------------------------------------------------- //

  /// Arac gecisi LISTESI (`GET /vehicle-passes`) — YALNIZ admin + security.
  /// PLAKA kisisel veriye baglanabilir (KVKK), bu yuzden yonetici/resident/
  /// tesis_gorevlisi listeyi GORMEZ (403). Yonetimin ihtiyaci olan AGREGAT
  /// doluluk `/parking/occupancy` ile herkese aciktir.
  bool get canViewVehiclePasses =>
      this == admin || this == security || this == guvenlikAmiri;

  /// Arac GIRISI kaydi + CIKIS damgasi (`POST /vehicle-passes`,
  /// `.../checkout`) — okuma ile ayni kume (kapi operasyonu).
  bool get canManageVehiclePasses => canViewVehiclePasses;

  /// Otopark AGREGAT dolulugu (`GET /parking/occupancy`) — plaka/daire
  /// icermez, bu yuzden bilinen tum rollere aciktir.
  bool get canViewParking => this != unknown;

  /// Ihlal kaydi OKUMA (`GET /violations`) — admin + yonetici + security.
  /// resident ve tesis_gorevlisi ERISMEZ (403): kayit komsu davranisi
  /// hakkinda veri tasir (KVKK).
  bool get canViewViolations =>
      this == admin || this == yonetici || this == security ||
      this == guvenlikAmiri;

  /// Ihlal ACMA (`POST /violations`) + durum ilerletme — admin + security.
  /// yonetici OKUR ama acmaz/degistiremez (403).
  bool get canManageViolations => this == admin || this == security;

  /// Ihlal KAPATMA (`PATCH durum=kapatildi`) — YALNIZ admin. Dort-goz
  /// kurali: inceleyen personel kendi kaydini kapatamaz.
  bool get canCloseViolations => this == admin;
}
