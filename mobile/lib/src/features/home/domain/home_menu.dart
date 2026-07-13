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

  /// Gorev-YONETIMI — gorev olusturma/atama + takip (A4 kesin matris):
  /// YALNIZ yonetici (+admin). Saha rolleri gormez; onlar "Gorevlerim"i
  /// kullanir (kendi rol grubuna atanan + atanmamis gorevler).
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

  /// Ziyaretciler — kapi onay akisi: security kaydeder (hedef sakin secer) +
  /// tum gecmisi izler; resident YALNIZ kendine hedeflenen kayitlari gorur +
  /// Onayla/Reddet. admin/yonetici DOGRUDAN GORMEZ (izinle — bkz. unitAccess);
  /// tesis_gorevlisi ERISMEZ (auth.md §4, KVKK).
  visitors,

  /// Kargo — paket takibi: security kaydeder (daire+firma+foto) + tum gecmisi
  /// izler; resident kendi dairesinin paketlerini gorur + "Teslim aldim".
  /// admin/yonetici DOGRUDAN GORMEZ (izinle); tesis_gorevlisi ERISMEZ.
  kargo,

  /// Goruntuleme izni — tek-seferlik daire erisim akisi (KVKK):
  /// admin/yonetici bir daire icin izin TALEBI acar + onaylananlari bir kez
  /// goruntuler; resident kendi dairesine gelen talepleri Onayla/Reddet eder
  /// (auth.md §4).
  unitAccess,

  /// Rezervasyon — ortak alan: yonetim alan tanimlar + bekleyenleri
  /// onaylar/reddeder (+takvim); resident aktif alanlara slot talep eder +
  /// kendi dairesinin taleplerini izler; saha rolleri ERISMEZ (auth.md §4).
  rezervasyon,

  /// Etkinlikler — yonetim olusturur/duzenler (RSVP sayilarini izler);
  /// resident Katiliyorum/Katilmiyorum beyani verir; OKUMA + seffaf
  /// sayilar TUM roller (auth.md §4).
  etkinlik,

  /// Site Kurallari — blog-tarzi kural listesi (baslik aramali): yonetim
  /// ekler/duzenler/siler, TUM roller okur (auth.md §4).
  siteKurallari,
}

List<HomeMenuEntry> homeMenuForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      // Ziyaretci/kargo DOGRUDAN GORMEZ (KVKK — varsayilan kapali); yerine
      // "Goruntuleme izni" ile tek-seferlik izin alir.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.security:
      // Ziyaretciler kapi operasyonudur: kayit + canli sonuc guvenlikte.
      // Gorev-YONETIMI YOK (A4): saha rolu yalniz "Gorevlerim" gorur.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
    case UserRole.tesisGorevlisi:
      // Turlarim yok: /me/patrol-window admin+security (auth.md §4).
      // Gorev-YONETIMI YOK (A4): saha rolu yalniz "Gorevlerim" gorur.
      return const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
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
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
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
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
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
