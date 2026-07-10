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

  /// Gorev-YONETIMI — tum gorev/atama listesi-takibi (kesin matris):
  /// goruntuleme yonetici+security+tesis_gorevlisi(+admin); "yeni gorev"
  /// yalniz yonetimde. "Gorevlerim"den (kisiye atananlar) AYRIDIR.
  taskTracking,

  /// Demirbas zimmet (NFC al/birak) — saha personeli.
  assets,

  /// Devriye noktasi NFC okutma (POST /scans) — saha personeli.
  nfc,

  /// Offline gonderim kuyrugu (scan outbox) — saha personeli.
  outbox,

  /// Aylik raporlar — yonetici: devriye/gorev/aidat ozeti (salt okuma).
  reports,

  /// Butce (Wave 2A) — yonetici: kategori + defter + kasa ozeti.
  budget,

  /// Finansal ozet (Wave 2B) — yonetici: cepten gunluk/donemsel rapor
  /// (tahsilat orani, geciken daire, gelir/gider/kasa, en yuksek giderler).
  financialSummary,

  /// Site Butcesi (Wave 2B) — resident: SALT OKUMA agregat seffaflik
  /// (toplam gelir/gider/kasa; defter satiri ve kisi/daire verisi yok).
  siteBudget,

  /// Aidatim — resident: kendi dairelerinin borc durumu (salt okuma).
  myDues,

  /// Sikayet/Oneri — yasayan/calisandan yonetime kanal: acan roller
  /// (security/tesis_gorevlisi/resident) acar + kendininkini izler;
  /// admin/yonetici tumunu gorur + yanitlar (kesin kural, auth.md §4).
  complaints,

  /// Ziyaretciler — kapi onay akisi: security kaydeder + tum gecmisi izler;
  /// resident kendi dairesinin kayitlarini gorur + Onayla/Reddet;
  /// admin/yonetici salt izler; tesis_gorevlisi ERISMEZ (auth.md §4).
  visitors,

  /// Kargo — paket takibi (ziyaretci ile ayni matris): security kaydeder
  /// (daire+firma+foto) + tum gecmisi izler; resident kendi dairesinin
  /// paketlerini gorur + "Teslim aldim"; admin/yonetici salt izler;
  /// tesis_gorevlisi ERISMEZ (auth.md §4).
  kargo,

  /// Rezervasyon — ortak alan: yonetim alan tanimlar + bekleyenleri
  /// onaylar/reddeder (+takvim); resident aktif alanlara slot talep eder +
  /// kendi dairesinin taleplerini izler; saha rolleri ERISMEZ (auth.md §4).
  rezervasyon,

  /// Etkinlikler — yonetim olusturur/duzenler (RSVP sayilarini izler);
  /// resident Katiliyorum/Katilmiyorum beyani verir; OKUMA + seffaf
  /// sayilar TUM roller (auth.md §4).
  etkinlik,
}

List<HomeMenuEntry> homeMenuForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      // security ile ayni saha kartlari + talepler (yonetim gorunumu).
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.security:
      // Ziyaretciler kapi operasyonudur: kayit + canli sonuc guvenlikte.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.tesisGorevlisi:
      // Turlarim yok: /me/patrol-window admin+security (auth.md §4).
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.complaints,
        HomeMenuEntry.tasks,
        HomeMenuEntry.taskTracking,
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
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrolTracking,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.budget,
        HomeMenuEntry.financialSummary,
        HomeMenuEntry.reports,
      ];
    case UserRole.resident:
      // Sakinin kaynaklari: acil durum (panik butonu sakinin de hakki) +
      // duyuru okuma + sikayet/oneri kanali + kendi aidat durumu (auth.md §4).
      // Ziyaretciler sakinde ust sirada: kapida cevap bekleyen kayit
      // (push ile gelinen akis) kolay erisilsin.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.complaints,
        HomeMenuEntry.myDues,
        HomeMenuEntry.siteBudget,
      ];
    case UserRole.unknown:
      // Rol cozulmeden (storage okumasi) veya bilinmeyen degerde: bos —
      // saniye alti bir durumdur, yanlis karti gostermekten iyidir.
      return const [];
  }
}
