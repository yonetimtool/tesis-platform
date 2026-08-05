/// Ana ekran menusunun role gore bilesimi — SAF fonksiyon (widget'siz),
/// birim testle dogrulanir. Gorunurluk kurallari contracts/auth.md §4'un
/// UX aynasidir; gercek yetki backend RBAC'ta.
library;

import '../../../../l10n/gen/app_localizations.dart';
import '../../auth/domain/user_role.dart';

enum HomeMenuEntry {
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

  /// Devriye noktasi NFC okutma (POST /scans) — ARTIK menude DEGIL: okutma
  /// "Turlarim" (devriye penceresi → Nokta okut) ve "Gorevlerim" (NFC'li gorev
  /// adimi) icinden yapilir; ayri "NFC etiket okutma" tile'i kaldirildi. Enum +
  /// rota (AppRoutes.nfc) Turlarim'in okutma ekranini actigi icin KORUNUR.
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

  /// Seffaflik Panosu (Dalga-1) — aylik ANONIM finansal ozet. Sakin:
  /// yayinlanmis aylar (salt okuma); yonetici/admin: her ay + yayinla/geri-al.
  transparency,

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

  /// Dis Hizmetler — guvenilir esnaf/hizmet kisileri (cilingir/elektrik...) +
  /// yonetici notu. Yonetici ekler/duzenler/siler; yonetici+guvenlik+sakin okur.
  disHizmet,

  /// Entegrasyonlar (C1b) — dis sistem (megafon/akilli-ev/webhook) konfig +
  /// SSRF-korumali tetik. Mobilde YONETICI yonetir (admin panelden).
  integrations,

  /// Saha Personeli (Ozellik 3) — YALNIZ yonetici mobil menusunde: guvenlik +
  /// tesis gorevlisi hesaplarini listeler ve ekler (telefon + gecici kod).
  /// yonetici backend'de YALNIZ saha personeli acabilir (RBAC zorlar); admin
  /// tum kullanicilari PANELDEN yonetir (mobil menude yok).
  /// (P35) Guvenlik amiri de gorur — ama YALNIZ guvenlik personeli acabilir
  /// (RBAC zorlar; tesis gorevlisi site isidir, dis sirketin degil).
  personel,

  /// Site Sakinleri — YALNIZ yonetici mobil menusunde: sakinleri listeler, yeni
  /// tasinani ekler (daire + gecici kod), ayrilani cikarir (pasiflestir). Sakin
  /// KENDI kayit olamaz; yonetici/admin ekler. admin panelden de yonetir.
  sakinler,

  /// Bina Duzenleme (D-viz Rev-2) — GORSEL editor: blok ekle → kutucuk → icine
  /// gir → kat + daire ekle (blok/kat/sira). Blok-suz mod (blok=null) destegi.
  /// Mobilde YONETICI kurar; yazma backend'de admin+yonetici (RBAC). Ayni CRUD
  /// uclarini kullanir; Sikayet Haritasi bu yapiyi yansitir.
  binaDuzenleme,

  /// Bagimsiz Bolum Tanimlari (P26) — TIP (1+1, 2+1, dubleks + varsayilan
  /// aidat) ve GRUP (Daire / Villa / Dukkan) listeleri. Site KURULUM adimidir:
  /// yalniz yonetim (admin + yonetici) gorur; saha ve sakin GORMEZ (tanimlari
  /// okuyabilirler ama yonetmezler).
  daireTanimlari,

  /// Sikayet Haritasi (D-viz-2) — 2D bina semasi: blok->kat->renkli daire
  /// hucreleri (ANONIM yogunluk). TUM roller gorur; SAKIN daireyi sikayet
  /// edebilir (mevcut POST /unit-complaints). Renk API'den (0-2/3-4/5+).
  sikayetHaritasi,

  /// Sikayetlerim (D-viz Rev-1.1) — ARTIK menude DEGIL: resident kendi
  /// sikayetlerini Sikayet Haritasi uzerinde (isaretli daireler) gorur; ayri
  /// sayfaya yonlendirilmez. Enum + rota ekran yeniden kullanim icin korunur.
  sikayetlerim,

  /// (P38) Anketler — sakin oy verir, yonetim sonucu panelden gorur.
  /// Menude TUM rollerde durur (herkes okur) ama OY YALNIZ sakinde:
  /// anket sakinlerin karar aracidir, personelin oyu site kararina girmez.
  anketler,

  /// (P139.3) Otopark — AGREGAT doluluk ekrani (plaka listesi DEGIL, KVKK).
  /// Bugune kadar YALNIZ sayacli kart olarak vardi; modul girisi YOKTU ve
  /// bu yuzden ana ekran izgarasina konamiyordu. Rota (`AppRoutes.otopark`)
  /// ZATEN vardi — bu bir yuzeye cikarma, yeni ekran degil.
  /// Gorunurluk UYDURULMADI: kartinin bugun cizildigi rolden turedi
  /// (`_yoneticiErisim`) — yani yonetici (+admin).
  otopark,

  /// (P143) Arac gecisleri — plaka okuma kayitlari. Otopark/Vardiya/Ihlal
  /// ile AYNI DURUM: rotasi (`AppRoutes.aracGecis`) vardi, MODUL GIRISI
  /// yoktu. `auth.md` §4a amire "arac gecisi ... okuma"yi ACIK sayiyor;
  /// giris olmadan amir onu izgarasina koyamiyordu.
  aracGecis,

  /// (P139.5) Ihlaller — arac/park ihlal kayitlari. Otopark ve Vardiya ile
  /// AYNI DURUM: kart vardi, MODUL GIRISI YOKTU. Kurasyon sonrasi bu
  /// eksiklik gorunur oldu — kart varsayilan izgaradan dusuyor ve
  /// kullanici GERI EKLEYEMIYORDU (secenek listesinde yok). Gorunurluk
  /// kartinin cizildigi rollerden turedi: `_gorevliErisim` (guvenlik) +
  /// `_yoneticiErisim`.
  ihlaller,

  /// (P139.3) Vardiyalar — vardiya cizelgesi. Otoparkla ayni durum: kart
  /// vardi, modul girisi yoktu. Gorunurluk kartlarindan turedi:
  /// `_gorevliErisim` + `_tesisGorevlisiErisim` + `_yoneticiErisim`.
  vardiyalar,

  /// Yonetici Iletisim — tenant'in yoneticileri (ad + telefon + arama) +
  /// yonetim maili. Saha rolleri + sakin gorur; YONETICI kendisi GORMEZ.
  yoneticiIletisim,
}

List<HomeMenuEntry> homeMenuForRole(UserRole role) {
  switch (role) {
    case UserRole.admin:
      // Ziyaretci/kargo DOGRUDAN GORMEZ (KVKK — varsayilan kapali); yerine
      // "Goruntuleme izni" ile tek-seferlik izin alir.
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.daireTanimlari,
        HomeMenuEntry.otopark,
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.outbox,
      ];
    case UserRole.guvenlikAmiri:
      // (P35) GUVENLIK ALANI + EKIP: tur/vardiya planlama sunucuda moda
      // baglidir, ama menu her iki modda AYNIDIR — dis_sirket modunda
      // ekranlar salt-okur calisir. Ziyaretci/kargo/sakin/finans girisleri
      // YOK: dis sirket = en az yetki (KVKK).
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
        HomeMenuEntry.patrol,
        HomeMenuEntry.personel,
        // (P143) `auth.md` §4a amire ACIK diyor: "tur/vardiya/kontrol
        // noktasi, tarama raporu, kamera, pano, bildirimler, ARAC GECISI
        // VE IHLAL OKUMA". Ucu de menude YOKTU — amir bunlari izgarasina
        // koyamiyordu. Daraltma kasitliydi ama BU UCU kapsamiyordu.
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.aracGecis,
        HomeMenuEntry.outbox,
      ];
    case UserRole.security:
      // Ziyaretciler kapi operasyonudur: kayit + canli sonuc guvenlikte.
      // Gorev-YONETIMI YOK (A4): saha rolu yalniz "Gorevlerim" gorur.
      // Sikayet Haritasi (yogunluk) YOK — yonetim/sakin konusu; yerine
      // "Bina Duzenleme" SALT-OKUMA (blok/kat/daire yapisi; yazma yok). Bu
      // salt-okuma girisi menunun EN ALTINDA durur (yonetici'deki konumuyla ayni).
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.outbox,
        // (P139.3) Vardiyalar — `binaDuzenleme`den ONCE: onun EN ALTTA
        // durmasi kayitli bir kuraldir (home_menu_test).
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.binaDuzenleme,
        HomeMenuEntry.yoneticiIletisim,
      ];
    case UserRole.tesisGorevlisi:
      // Turlarim yok: /me/patrol-window admin+security (auth.md §4).
      // Gorev-YONETIMI YOK (A4): saha rolu yalniz "Gorevlerim" gorur.
      // Sikayet Haritasi (yogunluk) YOK; yerine "Bina Duzenleme" SALT-OKUMA
      // (menunun EN ALTINDA — yonetici'deki konumuyla ayni).
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.complaints,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.outbox,
        // (P139.3) Vardiyalar — `binaDuzenleme`den ONCE: onun EN ALTTA
        // durmasi kayitli bir kuraldir (home_menu_test).
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.binaDuzenleme,
        HomeMenuEntry.yoneticiIletisim,
      ];
    case UserRole.yonetici:
      // Saha kaniti uretmez: scan/zimmet/kuyruk gizli. Gorevler ve devriye
      // salt takip; duyuru gonderme/yonetme duyuru ekraninda.
      return const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrolTracking,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.budget,
        HomeMenuEntry.financialSummary,
        HomeMenuEntry.transparency,
        HomeMenuEntry.reports,
        HomeMenuEntry.personel,
        HomeMenuEntry.sakinler,
        HomeMenuEntry.integrations,
        HomeMenuEntry.binaDuzenleme,
        HomeMenuEntry.daireTanimlari,
        HomeMenuEntry.otopark,
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.vardiyalar,
      ];
    case UserRole.resident:
      // Sakinin kaynaklari: duyuru okuma + sikayet/oneri kanali + kendi aidat
      // durumu (auth.md §4). Ziyaretciler sakinde ust sirada: kapida cevap
      // bekleyen kayit (push ile gelinen akis) kolay erisilsin.
      return const [
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        // Sikayet Haritasi: resident KENDI sikayetlerini de HARITA uzerinde
        // gorur (kendi ilettigi daireler isaretli) — ayri "Sikayetlerim"
        // sayfasina yonlendirilmez (D-viz Rev-1.1 fix).
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.myDues,
        HomeMenuEntry.siteBudget,
        HomeMenuEntry.transparency,
        HomeMenuEntry.yoneticiIletisim,
      ];
    case UserRole.denetci:
      // (P128/P129) DENETCININ MOBIL MENUSU BOS — ve bu bir eksiklik degil
      // KARARDIR. Denetimin isi masabasi isidir (rapor okumak, tablo
      // indirmek) ve urun karari `app.*` web yuzeyi yonunde verildi.
      //
      // Buraya "birkac kart" koymak, kullanilabilir bir denetci deneyimi
      // TASARLAMADAN varmis gibi gostermek olurdu. Ekran, giris yapan
      // denetciye web adresini soyler (home_gate).
      return const [];
    case UserRole.unknown:
      // Rol cozulmeden (storage okumasi) veya bilinmeyen degerde: bos —
      // saniye alti bir durumdur, yanlis karti gostermekten iyidir.
      return const [];
  }
}

/// Menu girisinin BASLIGI — aktif dilden. Kimlik [HomeMenuEntry] enum'udur;
/// switch EKSIKSIZDIR (default yok) → yeni giris eklenince derleyici zorlar.
String moduleBaslik(AppLocalizations l10n, HomeMenuEntry entry) =>
    switch (entry) {
      HomeMenuEntry.aracGecis => l10n.kartAracPlaka,
      HomeMenuEntry.ihlaller => l10n.modulIhlaller,
      HomeMenuEntry.otopark => l10n.modulOtopark,
      HomeMenuEntry.vardiyalar => l10n.modulVardiyalar,
      HomeMenuEntry.anketler => l10n.modulAnketler,
      HomeMenuEntry.announcements => l10n.modulDuyurular,
      HomeMenuEntry.patrol => l10n.modulTurlarim,
      HomeMenuEntry.patrolTracking => l10n.modulDevriyeTakibi,
      HomeMenuEntry.tasks => l10n.modulGorevlerim,
      HomeMenuEntry.taskTracking => l10n.modulGorevYonetimi,
      HomeMenuEntry.assets => l10n.modulDemirbas,
      HomeMenuEntry.nfc => l10n.modulNfcOkutma,
      HomeMenuEntry.outbox => l10n.modulGonderimKuyrugu,
      HomeMenuEntry.reports => l10n.modulAylikRaporlar,
      HomeMenuEntry.budget => l10n.modulButce,
      HomeMenuEntry.financialSummary => l10n.modulFinansalOzet,
      HomeMenuEntry.transparency => l10n.modulSeffaflik,
      HomeMenuEntry.siteBudget => l10n.modulSiteButcesi,
      HomeMenuEntry.myDues => l10n.modulAidatim,
      HomeMenuEntry.complaints => l10n.kartTalepAriza,
      HomeMenuEntry.visitors => l10n.modulZiyaretciler,
      HomeMenuEntry.kargo => l10n.modulKargo,
      HomeMenuEntry.unitAccess => l10n.modulGoruntulemeIzni,
      HomeMenuEntry.rezervasyon => l10n.modulRezervasyon,
      HomeMenuEntry.etkinlik => l10n.modulEtkinlikler,
      HomeMenuEntry.siteKurallari => l10n.modulSiteKurallari,
      HomeMenuEntry.disHizmet => l10n.modulDisHizmetler,
      HomeMenuEntry.integrations => l10n.modulEntegrasyonlar,
      HomeMenuEntry.personel => l10n.modulPersonel,
      HomeMenuEntry.sakinler => l10n.modulSakinler,
      HomeMenuEntry.binaDuzenleme => l10n.modulBinaYapisi,
      HomeMenuEntry.daireTanimlari => l10n.modulDaireTanimlari,
      HomeMenuEntry.sikayetHaritasi => l10n.modulSikayetHaritasi,
      HomeMenuEntry.sikayetlerim => l10n.modulSikayetlerim,
      HomeMenuEntry.yoneticiIletisim => l10n.modulYoneticiIletisim,
    };
