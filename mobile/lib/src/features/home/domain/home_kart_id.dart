/// ANA EKRAN KART KIMLIKLERI — kararli id'ler + dile bagli baslik cozumu.
///
/// NEDEN (i18n): kartlar eskiden TURKCE BASLIGI hem ekranda gosterip hem de
/// `switch (k.baslik)` ile sayac/rota esleme ANAHTARI olarak kullaniyordu.
/// Dil degisince bu anahtarlar bozulurdu. Artik:
///
///   * KIMLIK ([HomeKartId] / [OzetKutuId] / [HomeKartEtiketId]) = kararli,
///     dilden bagimsiz; TUM switch/rota/analitik eslemeleri bunu kullanir,
///   * BASLIK = cizim aninda aktif dilden cozulur ([kartBasligi] vb.).
///
/// Kural: kontrol akisinda (`switch`, `if`, harita anahtari) METIN
/// KULLANILMAZ. Yeni kart eklenince switch'ler EKSIKSIZ oldugu icin
/// derleyici burayi zorlar (default dali yok).
library;

import '../../../core/i18n/l10n.dart';

/// Hizli erisim kartinin kimligi (uc rol varyantinin TUM kartlari).
enum HomeKartId {
  // gorevli (security)
  vardiyaDurum,

  /// Yonetim izgarasindaki vardiya karti — metni "Vardiya Durumu" (gorevli
  /// kartindaki "Vardiya Durum"dan AYRI: referans gorsellerde iki ekranda
  /// farkli yazar, birebir korunur).
  vardiyaDurumu,
  kargo,
  ziyaretci,
  aracPlaka,
  ihlaller,
  gorevlerim,
  demirbas,
  turlarim,
  // tesis gorevlisi
  talepAriza,
  duyurular,
  etkinlikler,
  siteKurallari,
  yonetici,
  // sakin
  ziyaretciler,
  kargolarim,
  aidatBilgileri,
  gurultuSikayeti,
  geriBildirim,
  sikayetlerim,
  siteRaporlari,
  // yonetim
  gorevler,
  aidatDurumu,
  otoparkKullanimi,
  sikayetler,
  raporlar,
  // kosullu (cevrimdisi kuyruk)
  gonderimKuyrugu,
}

/// Sayac DEGIL, sabit bolum etiketi tasiyan kartlarin etiket kimligi.
enum HomeKartEtiketId { aylikOzet, devriye, kurallar, iletisim }

/// "Hızlı Özet" kutusunun kimligi.
enum OzetKutuId { toplamDaire, toplamTahsilat, tahsilatOrani, otoparkDoluluk }

/// Kart basligi — aktif dilden.
String kartBasligi(AppLocalizations l10n, HomeKartId id) => switch (id) {
      HomeKartId.vardiyaDurum => l10n.kartVardiyaDurum,
      HomeKartId.vardiyaDurumu => l10n.bolumVardiyaDurumu,
      HomeKartId.kargo => l10n.kartKargo,
      HomeKartId.ziyaretci => l10n.kartZiyaretci,
      HomeKartId.aracPlaka => l10n.kartAracPlaka,
      HomeKartId.ihlaller => l10n.kartIhlaller,
      HomeKartId.gorevlerim => l10n.kartGorevlerim,
      HomeKartId.demirbas => l10n.kartDemirbas,
      HomeKartId.turlarim => l10n.kartTurlarim,
      HomeKartId.talepAriza => l10n.kartTalepAriza,
      HomeKartId.duyurular => l10n.bolumDuyurular,
      HomeKartId.etkinlikler => l10n.bolumEtkinlikler,
      HomeKartId.siteKurallari => l10n.bolumSiteKurallari,
      HomeKartId.yonetici => l10n.kartYonetici,
      HomeKartId.ziyaretciler => l10n.kartZiyaretciler,
      HomeKartId.kargolarim => l10n.kartKargolarim,
      HomeKartId.aidatBilgileri => l10n.kartAidatBilgileri,
      // (P142) AD BIRLESTIRME — Kerem'in karari: "karo adi ile gittigi
      // ekranin adi ayni olacak; kullanici bir karoya basinca adindan
      // bekledigi yere gitmeli."
      //
      // OLCUM: `/complaints` ekranina DORT farkli adla giriliyordu —
      // "Sikayet / Oneri", "Geri Bildirim", "Gurultu Sikayeti" ve
      // "Talep / Arıza". Ekranin KENDI basligi "Talep / Arıza"ydi, yani
      // dortten yalniz biri dogruydu. Hepsi o ada baglandi.
      HomeKartId.gurultuSikayeti => l10n.kartTalepAriza,
      HomeKartId.geriBildirim => l10n.kartTalepAriza,
      HomeKartId.sikayetlerim => l10n.kartSikayetlerim,
      HomeKartId.siteRaporlari => l10n.kartSiteRaporlari,
      HomeKartId.gorevler => l10n.kartGorevler,
      HomeKartId.aidatDurumu => l10n.kartAidatDurumu,
      HomeKartId.otoparkKullanimi => l10n.kartOtoparkKullanimi,
      // (P142) EN ZARARLI CAKISMA BUYDU: karonun adi "Sikayetler"di ama
      // gittigi ekran BINA SEMASIYDI (`/sikayetHaritasi`). Kullanici
      // sikayet listesi beklerken kat plani buluyordu. Ad, gittigi
      // ekranin adiyla degistirildi.
      HomeKartId.sikayetler => l10n.modulSikayetHaritasi,
      HomeKartId.raporlar => l10n.kartRaporlar,
      HomeKartId.gonderimKuyrugu => l10n.kartGonderimKuyrugu,
    };

/// Kartin sabit alt etiketi (sayac degil) — aktif dilden.
String kartEtiketi(AppLocalizations l10n, HomeKartEtiketId id) => switch (id) {
      HomeKartEtiketId.aylikOzet => l10n.etiketAylikOzet,
      HomeKartEtiketId.devriye => l10n.etiketDevriye,
      HomeKartEtiketId.kurallar => l10n.etiketKurallar,
      HomeKartEtiketId.iletisim => l10n.etiketIletisim,
    };

/// Ozet kutusunun etiketi — aktif dilden.
String ozetEtiketi(AppLocalizations l10n, OzetKutuId id) => switch (id) {
      OzetKutuId.toplamDaire => l10n.ozetToplamDaire,
      OzetKutuId.toplamTahsilat => l10n.ozetToplamTahsilat,
      OzetKutuId.tahsilatOrani => l10n.ozetTahsilatOrani,
      OzetKutuId.otoparkDoluluk => l10n.ozetOtoparkDoluluk,
    };

/// Ozet kutusunun alt etiketi ("Tüm Site" / "Bu Ay" / "Şu An").
String ozetAltEtiketi(AppLocalizations l10n, OzetKutuId id) => switch (id) {
      OzetKutuId.toplamDaire => l10n.ozetTumSite,
      OzetKutuId.toplamTahsilat => l10n.ozetBuAy,
      OzetKutuId.tahsilatOrani => l10n.ozetBuAy,
      OzetKutuId.otoparkDoluluk => l10n.ozetSuAn,
    };
