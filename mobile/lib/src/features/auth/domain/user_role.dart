/// Rol modeli (contracts/auth.md §4) — JWT `role` claim'inin istemci aynasi.
///
/// Buradaki yetenek bayraklari YALNIZCA menu/ekran gorunurlugu icindir
/// (UX hizalamasi). Gercek yetki her istekte backend RBAC'ta zorlanir;
/// istemci suzgeci atlatilsa bile backend 403 doner.
library;

enum UserRole {
  /// Platform admini (biz) — panel + tum operasyon uclari.
  admin('admin', 'Admin (platform)'),

  /// Site yoneticisi (musteri) — mobil; gorev atama/takip, rapor okuma,
  /// acil durum. Saha kaniti uretmez (scan/tamamlama/zimmet yok).
  yonetici('yonetici', 'Yonetici'),

  /// Guvenlik gorevlisi — devriye + saha operasyonu.
  security('security', 'Guvenlik'),

  /// Tesis gorevlisi (temizlik + bahcivan + teknik; eski `cleaning`).
  tesisGorevlisi('tesis_gorevlisi', 'Tesis Gorevlisi'),

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

  /// Acil durum tetikleme (`POST /emergency`) — TUM roller (resident dahil;
  /// panik butonu sakinin de hakki — canli test karari, auth.md §4).
  bool get canTriggerEmergency =>
      isFieldWorker || this == yonetici || this == resident;

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

  /// Ziyaretci ekranini gorme (`GET /visitors`) — yonetim + guvenlik tum
  /// gecmis, sakin kendi dairesi; tesis_gorevlisi ERISMEZ (auth.md §4).
  bool get canViewVisitors =>
      this == admin || this == yonetici || this == security || this == resident;

  /// Ziyaretci kaydi acma (`POST /visitors`) — YALNIZ security (kapi
  /// operasyonu; yonetim gecmisi okur ama kayit acmaz).
  bool get canRegisterVisitor => this == security;

  /// Ziyaretci onay/red (`PATCH /visitors/{id}`) — YALNIZ resident (o
  /// dairenin aktif sakini olma kosulunu sunucu ayrica zorlar).
  bool get canAnswerVisitor => this == resident;
}
