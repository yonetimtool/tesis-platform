/// "One cikan grid + Tum Moduller" bolunmesi — SAF fonksiyon (widget'siz),
/// birim testle dogrulanir. Referans tasarimlarda (docs/design-refs) ana
/// ekranda rol basina 5-8 "one cikan" kart durur; kalan tum moduller altta
/// "Tum Moduller" bolumunde listelenir. Rol-gorunurlugun TEK KAYNAGI hala
/// [homeMenuForRole]'dur: buradaki featured listeler onun SIRALI bir
/// ALT-KUMESIDIR; [moreMenuForRole] geri kalandir (orijinal sira korunur).
///
/// featured secimi bir UX kararidir (referans niyetini gercek modullerimize
/// esler) ve serbestce ayarlanabilir — degistiginde SOZLESME testi (bolunme
/// butunlugu) korur, yalniz sayi/uyelik beklentileri guncellenir.
library;

import '../../auth/domain/user_role.dart';
import 'home_menu.dart';

/// Rol basina one cikan kartlar — her biri [homeMenuForRole]'un bir alt-kumesi.
/// Referans esleme:
///  - resident: Ziyaretci/Kargo/Aidat/Gurultu-Sikayet/Duyuru/Site-Raporlari.
///  - security: Kargo/Ziyaretci/Vardiya(Turlarim)/Gorevlerim/Sikayet.
///  - yonetici: Gorevler/Aidat-Finans/Raporlar/Devriye/Seffaflik/Sakinler.
const Map<UserRole, List<HomeMenuEntry>> _featured = {
  UserRole.yonetici: [
    HomeMenuEntry.announcements,
    HomeMenuEntry.sikayetHaritasi,
    HomeMenuEntry.complaints,
    HomeMenuEntry.patrolTracking,
    HomeMenuEntry.taskTracking,
    HomeMenuEntry.financialSummary,
    HomeMenuEntry.reports,
    HomeMenuEntry.sakinler,
  ],
  UserRole.resident: [
    HomeMenuEntry.visitors,
    HomeMenuEntry.kargo,
    HomeMenuEntry.rezervasyon,
    HomeMenuEntry.announcements,
    HomeMenuEntry.sikayetHaritasi,
    HomeMenuEntry.complaints,
    HomeMenuEntry.myDues,
    HomeMenuEntry.transparency,
  ],
  UserRole.security: [
    HomeMenuEntry.complaints,
    HomeMenuEntry.visitors,
    HomeMenuEntry.kargo,
    HomeMenuEntry.patrol,
    HomeMenuEntry.tasks,
  ],
  UserRole.admin: [
    HomeMenuEntry.announcements,
    HomeMenuEntry.sikayetHaritasi,
    HomeMenuEntry.complaints,
    HomeMenuEntry.unitAccess,
    HomeMenuEntry.rezervasyon,
    HomeMenuEntry.patrol,
    HomeMenuEntry.tasks,
    HomeMenuEntry.assets,
  ],
  UserRole.tesisGorevlisi: [
    HomeMenuEntry.announcements,
    HomeMenuEntry.etkinlik,
    HomeMenuEntry.complaints,
    HomeMenuEntry.tasks,
    HomeMenuEntry.assets,
    HomeMenuEntry.outbox,
  ],
};

/// One cikan kartlar — [homeMenuForRole]'un SIRALI alt-kumesi. Curate listede
/// olmayan / rolde gorunmeyen girisler sessizce elenir (sozlesme korunur).
List<HomeMenuEntry> featuredMenuForRole(UserRole role) {
  final full = homeMenuForRole(role);
  final wanted = _featured[role]?.toSet() ?? const {};
  return full.where(wanted.contains).toList();
}

/// "Tum Moduller" — one cikanlar disindaki her sey, orijinal sirada.
List<HomeMenuEntry> moreMenuForRole(UserRole role) {
  final featured = featuredMenuForRole(role).toSet();
  return homeMenuForRole(role).where((e) => !featured.contains(e)).toList();
}
