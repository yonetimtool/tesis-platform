/// Rol modeli (contracts/auth.md §4) — JWT `role` claim'inin istemci aynasi.
///
/// Buradaki yetenek bayraklari YALNIZCA menu/ekran gorunurlugu icindir
/// (UX hizalamasi). Gercek yetki her istekte backend RBAC'ta zorlanir;
/// istemci suzgeci atlatilsa bile backend 403 doner.
library;

enum UserRole {
  /// Platform admini (biz) — panel + tum operasyon uclari.
  admin('admin', 'Platform Admin'),

  /// Site yoneticisi (musteri) — mobil; gorev atama/takip, rapor okuma.
  /// Saha kaniti uretmez (scan/tamamlama/zimmet yok).
  yonetici('yonetici', 'Yönetici'),

  /// Guvenlik gorevlisi — devriye + saha operasyonu.
  security('security', 'Güvenlik'),

  /// Tesis gorevlisi (temizlik + bahcivan + teknik; eski `cleaning`).
  tesisGorevlisi('tesis_gorevlisi', 'Tesis Görevlisi'),

  /// Site sakini — v0'da operasyon erisimi yok.
  resident('resident', 'Site Sakini'),

  /// Claim yok/bilinmeyen deger (eski token, bozuk payload).
  unknown('unknown', 'Bilinmeyen rol');

  const UserRole(this.wire, this.label);

  /// Backend enum degeri (user_role).
  final String wire;

  /// TR gorunen ad.
  final String label;

  static UserRole fromClaim(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => UserRole.unknown,
      );

  /// Turlarim (`GET /me/patrol-window`) — auth.md: admin + security.
  bool get canViewMyPatrol => this == admin || this == security;

  /// Saha kaniti ureten akislar: scan gonderme, gorev tamamlama, zimmet,
  /// foto yukleme — admin + security + tesis_gorevlisi.
  bool get isFieldWorker =>
      this == admin || this == security || this == tesisGorevlisi;

  /// Gorev listesi/detayi okuma — saha rolleri + yonetici (takip).
  bool get canViewTasks => isFieldWorker || this == yonetici;

  /// Duyuru olusturma/duzenleme/silme (mobil UX) — YALNIZ yonetici: duyuru
  /// site yonetiminin agzi (canli test karari). admin mobilde salt okur
  /// (moderasyonu panelden yapar); okuma herkese acik.
  bool get canManageAnnouncements => this == yonetici;

  /// Gorev olusturma/duzenleme/silme (`POST/PATCH/DELETE /tasks`) —
  /// admin + yonetici (yonetici yalniz saha rollerine atayabilir; 422).
  bool get canManageTasks => this == admin || this == yonetici;

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
}
