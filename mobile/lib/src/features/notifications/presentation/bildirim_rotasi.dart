/// BILDIRIM -> HEDEF ROTA (P22b).
///
/// Bildirime dokunmak eskiden YALNIZCA "okundu" isaretliyordu; okunmus bir
/// bildirime dokunmak ise HICBIR SEY yapmiyordu (olu dokunma). Kullanici
/// "kacirilan tur" uyarisini gorup uzerine basiyor ve hicbir yere
/// gitmiyordu — bildirimin isaret ettigi kaydi bulmak icin menuden elle
/// gezinmesi gerekiyordu.
///
/// TASARIM SINIRI (bilincli): `notification` satiri YALNIZ su referanslari
/// tasir — `patrol_window_id`, `patrol_plan_id`, `checkpoint_id`, `task_id`.
/// `complaint_id` YOKTUR (talep bildirimleri push `data`sinda tasir ama
/// kayitta tutulmaz). Bu yuzden talep tiplerinde LISTEYE gidilir, tekil
/// kayda degil. Uydurma bir derin baglanti kurmak yerine kullaniciyi dogru
/// LISTEYE birakmak dogru davranistir.
///
/// Gorev DETAYI da id ile acilamaz: rota `Task` nesnesini `extra` ile ister
/// (bkz. `app_router.dart` — extra yoksa listeye yonlendirir). Dolayisiyla
/// gorev tiplerinde de hedef listedir.
library;

import '../../../routing/app_router.dart';
import '../domain/notification_models.dart';

/// Bildirimin acilmasi gereken rota; hedef bilinmiyorsa `null`.
///
/// `null` donmesi bir HATA DEGILDIR: o bildirim tipinin gidecegi bir ekran
/// yok demektir ve ekran yalnizca "okundu" isaretler. Bilinmeyen bir tipe
/// uydurma bir hedef vermek, kullaniciyi alakasiz bir ekrana atmak olurdu.
String? bildirimRotasi(AppNotification b) {
  final tipten = switch (b.tip) {
    // Devriye alarmlari — tur takibi ekrani pencereleri/okutmalari gosterir.
    'kacirilan_tur' || 'eksik_checkpoint' || 'gecikmis_okutma' =>
      AppRoutes.patrolTracking,
    // Talep akisi (acan kisiye): talep listesi.
    'talep_is_emri' || 'talep_cozuldu' || 'talep_reddedildi' =>
      AppRoutes.complaints,
    // Is emri atamasi (saha personeline): gorev listesi.
    'is_emri_atandi' => AppRoutes.tasks,
    _ => null,
  };
  if (tipten != null) return tipten;

  // Tip bilinmiyor (eski/yeni bir deger) ama kayit bir REFERANS tasiyorsa
  // ondan turet — tip listesi bayatlasa bile dokunma olu kalmasin.
  if (b.taskId != null && b.taskId!.isNotEmpty) return AppRoutes.tasks;
  if (b.patrolWindowId != null && b.patrolWindowId!.isNotEmpty) {
    return AppRoutes.patrolTracking;
  }
  return null;
}
