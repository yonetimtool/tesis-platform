/// Ana ekran menusunun role gore bilesimi — SAF fonksiyon (widget'siz),
/// birim testle dogrulanir. Gorunurluk kurallari contracts/auth.md §4'un
/// UX aynasidir; gercek yetki backend RBAC'ta.
library;

import '../../auth/domain/user_role.dart';

enum HomeMenuEntry {
  /// Kirmizi panik karti (POST /emergency).
  emergency,

  /// Duyurular — okuma TUM roller; admin/yonetici ekranda olusturur/yonetir.
  announcements,

  /// Turlarim — aktif devriye penceresi (admin + security).
  patrol,

  /// Devriye takibi — yonetici: bugunun pencereleri + gecmis (salt izleme).
  patrolTracking,

  /// Gorevlerim — saha personeli: tamamlama akisiyla.
  tasks,

  /// Gorev takibi — yonetici: ayni liste, tamamlama YOK (salt izleme).
  taskTracking,

  /// Demirbas zimmet (NFC al/birak) — saha personeli.
  assets,

  /// Devriye noktasi NFC okutma (POST /scans) — saha personeli.
  nfc,

  /// Offline gonderim kuyrugu (scan outbox) — saha personeli.
  outbox,

  /// Aylik raporlar — yonetici: devriye/gorev/aidat ozeti (salt okuma).
  reports,

  /// Aidatim — resident: kendi dairelerinin borc durumu (salt okuma).
  myDues,
}

List<HomeMenuEntry> homeMenuForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
    case UserRole.security:
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.tesisGorevlisi:
      // Turlarim yok: /me/patrol-window admin+security (auth.md §4).
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.yonetici:
      // Saha kaniti uretmez: scan/zimmet/kuyruk gizli. Gorevler ve devriye
      // salt takip; duyuru gonderme/yonetme duyuru ekraninda.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.patrolTracking,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.reports,
      ];
    case UserRole.resident:
      // Sakinin kaynaklari: duyuru okuma + kendi aidat durumu (auth.md §4).
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.myDues,
      ];
    case UserRole.unknown:
      // Rol cozulmeden (storage okumasi) veya bilinmeyen degerde: bos —
      // saniye alti bir durumdur, yanlis karti gostermekten iyidir.
      return const [];
  }
}
