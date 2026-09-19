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
    // (P241 §2e) `gorev_atandi` ve arkadaslari EKLENDI — iki yuzeyin
    // haritasi karsilastirilinca eksik olduklari gorundu. `gorev_atandi`
    // P191'den beri gonderiliyordu ve dokununca HICBIR YERE
    // gitmiyordu.
    'is_emri_atandi' ||
    'gorev_atandi' ||
    'gorev_tamamlandi' ||
    'gorev_adim_ilerleme' =>
      AppRoutes.tasks,
    // Uzak okutma da bir DEVRIYE alarmi — otekilerle ayni ekran.
    'uzak_okutma' => AppRoutes.patrolTracking,
    // (P147) SAKININ KENDI olaylari — her biri ILGILI ekrana gider.
    // "Kargonuz geldi" -> kargo sayfasi, "sikayetiniz sonuclandirildi" ->
    // sikayetlerim. Hedefi olmayan tipe uydurma bir ekran verilmez.
    'kargo' => AppRoutes.kargo,
    'ziyaretci' => AppRoutes.visitors,
    'rezervasyon' => AppRoutes.rezervasyon,
    'sikayet_cozuldu' => AppRoutes.sikayetlerim,
    // (P241) PAKET OLCUMUNDE YAKALANDI: P240'ta uc yeni bildirim ailesi
    // eklendi ama bu beyaz liste guncellenmemisti — panik push'una
    // dokunan kullanici ALARM EKRANINA GITMIYOR, bildirim yalnizca
    // "okundu" isaretleniyordu. Acil durumda en pahali sessiz kusur.
    'panik_alarm' || 'panik_yanlis_alarm' || 'panik_kapandi' =>
      AppRoutes.panikTakip,
    // (P240 §3) Kacak/yangin -> cihazin oldugu ekran (vana, sensor).
    'akilli_ev_kacak' || 'akilli_ev_yangin' => AppRoutes.akilliEv,
    // (P240 §4) Kopan entegrasyon -> entegrasyon listesi (saglik sutunu).
    'entegrasyon_koptu' => AppRoutes.integrations,
    // (P241 §1) Bakim hatirlatmalari -> bakim takibi.
    'bakim_yaklasti' || 'bakim_bugun' || 'bakim_gecikti' => AppRoutes.bakim,
    // (P241 §2e) Vardiya plani yayinlandi -> PLAN ekrani.
    //
    // P240'ta ayni kusur yasandi: yeni bildirim ailesi eklenmis, bu
    // beyaz liste guncellenmemisti ve push'a dokunan kullanici hicbir
    // yere gitmiyordu. Yeni tip eklerken BURASI da guncellenir —
    // `p241_bildirim_rotasi_test` iki yuzeyin haritasini karsilastirir.
    'vardiya_yayinlandi' => AppRoutes.vardiyaPlani,
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
