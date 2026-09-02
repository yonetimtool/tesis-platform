// (P133.1) KENAR CUBUGU MENUSU — GRUPLAR, tek kaynak.
//
// NEDEN AYRI BIR MODUL: liste `AppShell.tsx` icinde yasiyordu ve orada
// yalnizca CIZIMLE birlikte test edilebiliyordu. Gruplama bir VERI
// kararidir (hangi sayfa hangi bolume ait, hangi bolum katli gelir) ve
// jsdom kurmadan olculebilmeli. Cizim testi ayrica duruyor — ikisi ayri
// hata sinifi: kume dogru olup kabugun onu okumamasi mumkundur.
//
// ROL KAPISI BURADA DEGIL: gorunurluk `yuzey.ts`teki `ROTA_ROLLERI`den
// gelir ve bu tur onu DEGISTIRMEDI. Buradaki tek is, gorunen kumeyi
// BOLUMLERE ayirmak.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

import { rotaRoldeGorunur, rotaYuzeyi, type Yuzey } from "./yuzey";

export type IconName =
  | "grid" | "building" | "clock" | "scan" | "route" | "check"
  | "box" | "home" | "edit" | "pin" | "money" | "chart"
  | "users" | "megaphone" | "chat" | "bell" | "hub" | "gear"
  | "shield" | "doc"
  // (P184-ek §10) Dar kenar cubukta her oge YALNIZ ikonla cizilir; ayni grup
  // icinde iki oge ayni ikonu paylasamaz. Asagidakiler o ayrimi saglamak icin
  // eklendi — hepsi ayni cizim dilinde (stroke, viewBox 24, ~18px).
  | "alert" | "camera" | "nfc" | "visitor" | "package" | "car"
  | "task" | "cube" | "calendar" | "ticket" | "gavel"
  | "wallet" | "ledger" | "invoice" | "coins" | "expense" | "income"
  | "transfer" | "refund" | "receipt" | "gauge" | "report"
  | "news" | "inbox" | "survey" | "handshake" | "invite" | "help"
  | "folder" | "list" | "tag" | "submeter" | "homes" | "eye"
  // (P191 §4) Banka entegrasyonu — finans grubunda benzersiz ikon.
  | "bank"
  // (P202) Surum politikasi — platform grubunda benzersiz ikon.
  | "phone";

/** Bolum kimlikleri. Sira BURADAKI siradir (menude de bu sirayla cizilir). */
export type GrupId =
  // (P167 §1.3) OZET — bolum DEGIL, bagimsiz ust sekme. Bir `GrupId` olarak
  // tutulmasinin nedeni teknik: gorunurluk/arama/aktiflik mantigi tek bir
  // kume uzerinden yuruyor ve "grupsuz oge" ikinci bir kod yolu acardi.
  // Cizimde basligi YOKTUR (`bagimsiz`), ogeleri IKONLUDUR.
  | "ozet"
  | "guvenlik"
  | "tesis"
  // (P167 §1.4) FINANSAL ISLEMLER — `finansHareket` ve `icra` bolumleri
  // BURAYA KATILDI.
  //
  // P154 ikisini ayirmisti ve gerekcesi bir YER butcesiydi: butun bolumler
  // acik cizildigi icin 11 satirlik bir finans bolumu menuyu tasiriyordu.
  // P167 §1.2 o butceyi ORTADAN KALDIRIYOR — artik butun ana basliklar
  // KAPALI baslar, yani bir bolumun kac satir oldugu ancak kullanici onu
  // actiginda onemli. Ayirmayi surdurmek, sebebi kalkmis bir bolunmeyi
  // korumak olurdu; icra da (§1.4) para dosyasinin yaninda aranir.
  | "finans"
  | "iletisim"
  | "tanimlar"
  | "yonetim"
  | "platform";

export interface MenuOgesi {
  /** ROTA — sorgu YOK. Yuzey ve rol aramalari BUNUNLA yapilir. */
  href: string;
  /**
   * (P154 / Asama 7.1) Rotanin ALT GORUNUMU, sorgu dizesi olarak.
   *
   * Brief FINANS bolumunde yedi satir istiyor (Tahsilatlar, Gelirler,
   * Giderler, Virman, Iade, Acilis fisleri...). Bunlarin hepsi `/finans`
   * sayfasindaki AYNI deftere bakar, yalnizca `tip` suzgeci degisir —
   * yedi ayri sayfa acmak ayni tabloyu yedi kez yazmak olurdu.
   *
   * SORGU `href`E GOMULMEDI ve bu onemli: `rotaYuzeyi`/`rotaRoldeGorunur`
   * TAM ESLESME yapar (`ROTA_ROLLERI["/finans"]`). `"/finans?tip=gelir"`
   * yazsaydik arama bosa duser, oge HICBIR ROLDE gorunmezdi — sessizce.
   */
  sorgu?: string;
  anahtar: SozlukAnahtari;
  /**
   * (P167 §1.1) IKON ARTIK YALNIZ BAGIMSIZ SEKMELERDE CIZILIR.
   *
   * Kural TERSINE cevrildi: eskiden ana basliklar ciplakti, alt satirlarin
   * hepsinde ikon vardi — 40 satirlik menude 40 kucuk sekil, hicbiri
   * otekinden ayirt edilmiyordu. Ikon bir AYIRT EDICI olmaktan cikip
   * gurultuye donusmustu.
   *
   * Simdi ikon BASLIK duzeyinde (`GRUP_IKONU`) ve bagimsiz sekmelerde;
   * alt satirlar GIRINTIYLE hizalanir. Alan burada KALDI cunku bagimsiz
   * sekme (Ozet) hâlâ kendi ikonunu tasiyor.
   */
  icon: IconName;
  grup: GrupId;
}

/** Menude cizilecek baglanti (rota + varsa sorgu). */
export function ogeBaglantisi(o: MenuOgesi): string {
  return o.sorgu ? `${o.href}?${o.sorgu}` : o.href;
}

/**
 * Bu oge su an acik mi?
 *
 * SORGU DA KARSILASTIRILIR: yedi finans satiri ayni `pathname`i paylasir;
 * yalniz yola bakan bir kural YEDISINI BIRDEN aktif boyardi ve kullanici
 * nerede oldugunu menuden okuyamazdi.
 *
 * Sorgusuz oge (orn. "Tum hareketler") YALNIZCA suzgec de bossa aktiftir.
 */
export function ogeAktif(
  o: MenuOgesi,
  pathname: string,
  sorgu: URLSearchParams | null,
): boolean {
  if (pathname !== o.href) return false;
  const beklenen = new URLSearchParams(o.sorgu ?? "");
  for (const [ad, deger] of beklenen) {
    if (sorgu?.get(ad) !== deger) return false;
  }
  if (o.sorgu) return true;
  // Sorgusuz oge: kardeslerinden birinin suzgeci aciksa o aktiftir, bu degil.
  return !OGELER.some(
    (k) => k.href === o.href && k.sorgu && ogeAktif(k, pathname, sorgu),
  );
}

// (P166 §1) "DAHA FAZLA / DAHA AZ" KATMANI KALDIRILDI.
//
// Eskiden dort bolum (`finansHareket`, `iletisim`, `tanimlar`, `yonetim`)
// `KATLI_GRUPLAR` dizisindeydi ve tek bir "Daha fazla" satirinin ARDINDA
// duruyordu. Kerem'in olcumu: uygulamayi bilmeyen kullanici o satirin bir
// MENU oldugunu anlamiyor, arkasindaki 30+ sayfayi HIC gormuyordu.
//
// Katlama bir yer kazanma cozumuydu; yerine KAYDIRMA kondu (`nav` zaten
// `overflow-y-auto`). Kaydirma cubugu bir sayfanin VAR OLDUGUNU soyler,
// katlanmis bir baslik soylemez — bulunabilirlik farki budur.
//
// GRUP BASLIKLARI KALDI ve hâlâ katlanabilir; degisen sey VARSAYILAN:
// artik hepsi ACIK baslar. Yani hicbir sayfa "bir tiklama uzakta" degil.

/** Bolum basligi anahtarlari. */
export const GRUP_ANAHTARI: Record<GrupId, SozlukAnahtari> = {
  ozet: "kabukOzet",
  guvenlik: "kabukGrupGuvenlik",
  tesis: "kabukGrupTesis",
  finans: "kabukGrupFinans",
  iletisim: "kabukGrupIletisim",
  tanimlar: "kabukGrupTanimlar",
  yonetim: "kabukGrupYonetim",
  platform: "kabukGrupPlatform",
};

/**
 * (P167 §1.1) BOLUM IKONLARI — ana basligin gorsel capasi.
 *
 * Ikon sayisi 40'tan 7'ye dustugu icin her biri artik AYIRT EDICI: kullanici
 * "para" simgesini gorup Finansal Islemler'i tarayarak degil BAKARAK bulur.
 * Alt satirlar ikonsuz ve girintili — hiyerarsi ikonun VARLIGI/YOKLUGU ile
 * anlatiliyor, ayri bir renk ya da cizgiyle degil.
 */
export const GRUP_IKONU: Record<GrupId, IconName> = {
  ozet: "grid",
  guvenlik: "shield",
  tesis: "building",
  finans: "money",
  iletisim: "chat",
  tanimlar: "box",
  yonetim: "gear",
  platform: "hub",
};

/**
 * (P167 §1.3) BASLIKSIZ BOLUMLER — "bagimsiz sekme"ler.
 *
 * Ozet bir bolum degil TEK bir sayfadir; ona bir ana baslik verip altina tek
 * satir koymak, kullaniciyi her acilista bir tiklamaya zorlardi. Bu kumedeki
 * bolumler basliksiz cizilir ve ogeleri IKONLU olur (§1.1'in son cumlesi).
 */
const BAGIMSIZ_GRUPLAR: ReadonlySet<GrupId> = new Set<GrupId>(["ozet"]);

// (P166 §1) SIRA ARTIK ANLAMA GORE, "hangisi katlanir"a gore DEGIL.
//
// Eski dizide `platform` ortadaydi cunku katli olmayan son bolumdu —
// yani sirayi katlama karari belirliyordu. Katlama gidince olcut de
// degisti: para hareketleri paranin, tanimlar da yonetimin yanindadir.
// (P167 §1.3) OZET EN USTTE ve basliksiz: gunun ilk bakisi oraya duser.
const GRUP_SIRASI: readonly GrupId[] = [
  "ozet",
  "guvenlik",
  "tesis",
  "finans",
  "iletisim",
  "tanimlar",
  "yonetim",
  "platform",
];

// Menu ogeleri METIN degil ANAHTAR tasir: etiket cizim aninda aktif dilde
// cozulur. Sira GRUP ICINDE anlamlidir (once gunluk bakilan, sonra kurulum).
const OGELER: readonly MenuOgesi[] = [
  // --- OZET: bagimsiz ust sekme (P167 §1.3) -----------------------------
  // Eski adi "Canli Panel"di ve GUVENLIK bolumunun altindaydi. Ikisi de
  // yanlisti: sayfa yalniz guvenligi degil TESISIN TAMAMINI (para, takvim,
  // maket, alarm) ozetliyor ve gunun ilk bakisi oraya duser — bir bolumun
  // altinda, kapali bir baslgin ardinda durmamali.
  { href: "/dashboard", anahtar: "kabukOzet", icon: "grid", grup: "ozet" },

  // --- GUVENLIK: gunluk saha akisi --------------------------------------
  { href: "/olaylar", anahtar: "kabukOlaylar", icon: "alert", grup: "guvenlik" },
  { href: "/notifications", anahtar: "kabukBildirimler", icon: "bell", grup: "guvenlik" },
  { href: "/kameralar", anahtar: "kabukKameralar", icon: "camera", grup: "guvenlik" },
  { href: "/shifts", anahtar: "kabukVardiyalar", icon: "clock", grup: "guvenlik" },
  // (P203 §4) PLAN, sablonlarin YANINDA: "vardiya" iki farkli sey —
  // biri SABLON (saatler), oteki PLAN (kim, hangi gun). Ayni bolumde
  // ama ayri satir: birlestirmek, gunluk kullanilan plani haftada bir
  // dokunulan sablon ekraninin icine gommekti.
  { href: "/vardiya-plani", anahtar: "kabukVardiyaPlani", icon: "calendar", grup: "guvenlik" },
  { href: "/checkpoints", anahtar: "kabukNfcNoktalari", icon: "nfc", grup: "guvenlik" },
  { href: "/patrol-plans", anahtar: "kabukDevriyePlanlari", icon: "route", grup: "guvenlik" },
  { href: "/ziyaretciler", anahtar: "kabukZiyaretciler", icon: "visitor", grup: "guvenlik" },
  { href: "/kargolar", anahtar: "kabukKargolar", icon: "package", grup: "guvenlik" },
  { href: "/arac-gecisleri", anahtar: "kabukAracGecisleri", icon: "car", grup: "guvenlik" },

  // --- TESIS: binanin kendisi -------------------------------------------
  { href: "/units", anahtar: "kabukDaireler", icon: "home", grup: "tesis" },
  { href: "/tasks", anahtar: "kabukGorevler", icon: "task", grup: "tesis" },
  { href: "/gorevlerim", anahtar: "kabukGorevlerim", icon: "check", grup: "tesis" },
  { href: "/assets", anahtar: "kabukDemirbas", icon: "cube", grup: "tesis" },
  { href: "/schematic", anahtar: "kabukSikayetHaritasi", icon: "pin", grup: "tesis" },
  { href: "/dis-hizmetler", anahtar: "kabukDisHizmetler", icon: "hub", grup: "tesis" },
  { href: "/etkinlikler", anahtar: "kabukEtkinlikler", icon: "calendar", grup: "tesis" },
  { href: "/rezervasyonlarim", anahtar: "kabukRezervasyon", icon: "ticket", grup: "tesis" },
  { href: "/rezervasyon-yonetimi", anahtar: "kabukRezervasyonYonetimi", icon: "clock", grup: "tesis" },
  { href: "/kurallar", anahtar: "kabukKurallar", icon: "gavel", grup: "tesis" },

  // --- FINANS: para -----------------------------------------------------
  // (P154 / Asama 7.1) Brief'in FINANS listesi: Borclandirmalar ·
  // Tahsilatlar · Gelirler · Giderler · Hesaplar arasi virman · Odeme
  // iadesi · Acilis fisleri.
  //
  // ALTISI YENI SAYFA DEGIL, `/finans`in `tip` SUZGECI. Yedi ayri sayfa
  // acmak ayni defter tablosunu yedi kez yazmak olurdu; sayfa zaten bu
  // alti tipi taniyor (`TIPLER` dizisi) ve suzgeci artik adresten okuyor.
  { href: "/dues", anahtar: "kabukAidat", icon: "money", grup: "finans" },
  { href: "/aidatim", anahtar: "kabukAidatim", icon: "wallet", grup: "finans" },
  { href: "/finans", anahtar: "kabukFinans", icon: "ledger", grup: "finans" },
  // (P167 Asama 4) SORGU SUZGECLERI GERCEK SAYFALARA DONDU.
  //
  // P154'te bunlar `/finans`in `tip` suzgecleriydi ve o zaman dogruydu:
  // yedi satirin hepsi AYNI deftere bakiyordu, tek fark neyi gizledigiydi.
  // Brief §4 bunu degistiriyor — her birinin kendi "+ Yeni" formu, kendi
  // sutunlari ve bazilarinin ikinci bir TOPLU akisi var. Suzgec olarak
  // birakmak, tek sayfaya yedi ayri modal doldurmak olurdu.
  //
  // BORCLANDIRMALAR AYRI BIR TABLOYU (`dues_assessment`) listeler; oteki
  // yedisi `finansal_hareket` defterini.
  { href: "/finans/borclandirmalar", anahtar: "finansBorclandirmalar", icon: "invoice", grup: "finans" },
  { href: "/finans/tahsilatlar", anahtar: "kabukTahsilatlar", icon: "coins", grup: "finans" },
  { href: "/finans/giderler", anahtar: "kabukGiderler", icon: "expense", grup: "finans" },
  { href: "/finans/gelirler", anahtar: "kabukGelirler", icon: "income", grup: "finans" },
  { href: "/finans/virman", anahtar: "kabukVirman", icon: "transfer", grup: "finans" },
  { href: "/finans/iade", anahtar: "kabukIade", icon: "refund", grup: "finans" },
  { href: "/finans/acilis", anahtar: "kabukAcilisFisleri", icon: "receipt", grup: "finans" },
  // (P191 §4) Banka entegrasyonu — ekstre -> eslestirme -> tahsilat.
  { href: "/finans/banka", anahtar: "kabukBankaEntegrasyonu", icon: "bank", grup: "finans" },
  // (P192 §4) OTOMASYON — aidat plani, borc hatirlatma, duzenli gider,
  // otomasyon gunlugu. Dordu de "yoneticinin her ay elle yaptigi is"i
  // yanitladigi icin tek sayfada.
  { href: "/finans/otomasyon", anahtar: "finansOtomasyon", icon: "clock", grup: "finans" },
  // (P203 §5) FAZLA MESAI — finans bolumunde, cunku urettigi sey bir
  // GIDERDIR (P192 tek defter). Vardiya bolumune koymak, parayi
  // operasyonun icine gizlemek olurdu.
  { href: "/finans/mesai", anahtar: "kabukMesai", icon: "clock", grup: "finans" },
  // (P192 §5) BORCLULAR: yaslandirma + tahsilat gostergesi + toplu islem.
  // Ucu ayni sayfada cunku yaslandirma bir SORU sorar, toplu islem
  // onun CEVABINI uygular.
  { href: "/finans/borclular", anahtar: "finansBorclular", icon: "gavel", grup: "finans" },
  // (P192 §5.4) BUTCE: hedef ile gerceklesen yan yana + sapma.
  { href: "/finans/butce", anahtar: "finansButce", icon: "chart", grup: "finans" },
  // (P167 §1.4) ICRA DOSYALARI — bagimsiz ust sekme DEGIL, finansin ALTI.
  // Icra bir borcun son durumudur; kullanici onu "hukuk" basligi altinda
  // degil, borcu takip ettigi yerde arar.
  { href: "/icra", anahtar: "kabukIcra", icon: "gavel", grup: "finans" },
  // (P111) Sayac okuma tanimlardan beslenir, ciktisi bir tahakkuktur.
  { href: "/sayac-okuma", anahtar: "kabukSayacOkuma", icon: "gauge", grup: "finans" },
  { href: "/reports/dues", anahtar: "kabukRaporlar", icon: "chart", grup: "finans" },
  // (P40) 12 raporluk katalog; `/reports/dues` tek raporluk eski sayfadir
  // ve ikisi YAN YANA durur ki eski baglantilar kirilmasin.
  { href: "/raporlar", anahtar: "kabukRaporMotoru", icon: "report", grup: "finans" },

  // --- PLATFORM: yalniz `panel.*` ---------------------------------------
  { href: "/tenants", anahtar: "kabukTesisler", icon: "building", grup: "platform" },
  { href: "/integrations", anahtar: "kabukEntegrasyonlar", icon: "hub", grup: "platform" },
  { href: "/settings", anahtar: "kabukAyarlar", icon: "gear", grup: "platform" },
  // (P202) Zorunlu/onerilen guncelleme esikleri. PLATFORM grubunda cunku
  // magazadaki paket tektir: bir tesis yoneticisinin butun kullanicilari
  // kilitleyebilmesi dogru olmazdi.
  { href: "/surum-politikasi", anahtar: "kabukSurumPolitikasi", icon: "phone", grup: "platform" },
  // kvkk-metinler ikonu asagida (doc) — platform grubunda doc yalniz burada.
  // (P170 §2) KVKK VE YASAL METIN YONETIMI BURAYA TASINDI.
  //
  // Tesis menusunde "Yonetisim"in altindaydi ve `admin, yonetici`ye
  // acikti. Metinleri PLATFORM yonetir: tesis yoneticisinin kendi
  // aydinlatma metnini yazmasi, hukuki sorumlulugu yazma yetkisiyle
  // karistirmakti.
  //
  // `/kvkk` (pazarlama tercihleri) TESIS TARAFINDA KALDI ve karistirilmasin:
  // biri tesisin YAYINLADIGI yasal metin, oteki kullanicinin KENDI izni.
  { href: "/kvkk-metinler", anahtar: "kabukKvkkMetinler", icon: "doc", grup: "platform" },

  // --- ILETISIM: siteye seslenme + sakinden gelen -----------------------
  { href: "/announcements", anahtar: "kabukDuyurular", icon: "megaphone", grup: "iletisim" },
  // (P184-ek §10) iletisim grubunda ikonlar birbirinden ayri: duyuru=megafon,
  // kural=tokmak, etkinlik=takvim, duyurularim=gazete, mesaj=sohbet,
  // talep=gelen-kutusu, taleplerim=bilet, anket=anket, yonetim=el-sikisma,
  // davet=davet, destek=yardim.
  // (P162) SITE KURALI ve ETKINLIK YONETIMI — `iletisim` grubunda, TESIS
  // grubunda DEGIL. Iki gerekce:
  //
  //  1. ANLAM: ucu de yonetimin SAKINE YAYINLADIGI icerik. Duyuru
  //     yonetimi zaten burada; kural ve etkinlik ondan farkli degil.
  //  2. OLCUM: `tesis` grubu zaten en kalabalik olan. Iki satir daha
  //     eklemek acilistaki gorunur satiri 13'e cikariyordu ve
  //     `menu-gruplari` testi (P133.1: en cok 12) hakli olarak dustu.
  //     Bu bir bicim kurali degil, kaydirma cubugunu onleyen bir butce.
  { href: "/site-kurallari", anahtar: "kabukKuralYonetimi", icon: "gavel", grup: "iletisim" },
  { href: "/etkinlik-yonetimi", anahtar: "kabukEtkinlikYonetimi", icon: "calendar", grup: "iletisim" },
  { href: "/duyurular", anahtar: "kabukDuyurularim", icon: "news", grup: "iletisim" },
  // (P167 §1.5) UC SATIR TEKE INDI: "Mesajlar", "SMS gonderimi" ve
  // "E-posta gonderimi" UCU DE `/mesajlar`a gidiyordu — ikisi ayni sayfayi
  // bir sorguyla onceden suzuyordu (P154'un karari).
  //
  // Kerem'in olcumu: kullanici uc ayri YETENEK sanip ucunu de tikliyor ve
  // her seferinde ayni ekrani goruyor. Onceden suzme bir kisayoldu; bedeli
  // menuyu uc kat yanlis okutmak oldu. Sayfa kanali ZATEN kendi icinde
  // seciyor, dolayisiyla kaybolan bir yol YOK.
  //
  // ROTA OLMEDI: `/mesajlar?kanal=sms` hâlâ gecerli ve sayfa onu okuyor —
  // eski yer imleri ve `/kurulum` baglantilari kirilmadi.
  { href: "/mesajlar", anahtar: "kabukSmsEpostaYonetimi", icon: "chat", grup: "iletisim" },
  { href: "/complaints", anahtar: "kabukTalepler", icon: "inbox", grup: "iletisim" },
  { href: "/taleplerim", anahtar: "kabukTaleplerim", icon: "ticket", grup: "iletisim" },
  { href: "/anketler", anahtar: "kabukAnketler", icon: "survey", grup: "iletisim" },
  { href: "/yonetim-iletisim", anahtar: "kabukYonetimIletisim", icon: "handshake", grup: "iletisim" },
  // (P155 §7) Davet gonderim durumu — kisiye kayit bagi gonderildi mi.
  { href: "/davetler", anahtar: "kabukDavetler", icon: "invite", grup: "iletisim" },
  { href: "/support", anahtar: "kabukDestek", icon: "help", grup: "iletisim" },

  // --- YONETIM: kurulum + hesap verebilirlik -----------------------------
  // --- TANIMLAR: kurulum kayitlari (brief 7.1) --------------------------
  // Brief'in listesi: Blok · Daire tipleri · Kasa · Gelir/gider tanimlari ·
  // Personel · Arac · Sayac.
  //
  // ALTISI `/tanimlar`in DEFTERLERI. Sayfa zaten sekmeli ve veri-surumlu;
  // menu yalnizca hangi defterle acilacagini soyler (`defter` sorgusu).
  // Ayri sayfalara bolmek, `DEFTERLER` dizisinin tek-kaynak olmasini
  // bozardi.
  //
  // BLOK BURAYA TASINDI (once TESIS'teydi): brief blogu bir TANIM sayar.
  // Daire (`/units`) TESIS'te kaldi — o gunluk bakilan bir liste, blok
  // ise kurulumda bir kez cizilir.
  // (P167 §1.6) BOLUM YENIDEN YAZILDI.
  //
  // ESKI HALI BOZUKTU ve bozuklugun adi suydu: baslik "Tanimlar" diyordu
  // ama altinda `/tanimlar` ekraninin ON BIR DEFTERINDEN yalniz yedisi
  // vardi; buna karsilik KENDINE isaret eden bir "Tanimlar" satiri
  // (kullaniciya hicbir sey soylemeyen bir dongusellik) ve bir "Kurulum
  // sihirbazi" duruyordu — sihirbaz bir TANIM degil bir AKIS'tir.
  //
  // Yeni kural: bolum, `/tanimlar` ekraninin sekme seridinin BIREBIR
  // aynasidir; ustune ayni seviyede iki kurulum kaydi (Bloklar, Ice
  // aktarim) eklenir. Sihirbaz alt cubuga tasindi (§1.8) — orada tek
  // basina, tam genislikte durur ve bir defter sanilmaz.
  //
  // SIRA `/tanimlar` sayfasindaki DEFTERLER dizisiyle AYNI: kullanici
  // menuden tikladiginda sekme seridinde ayni sirada bulacak.
  { href: "/building-editor", anahtar: "kabukBloklar", icon: "edit", grup: "tanimlar" },
  { href: "/ice-aktarim", anahtar: "iceAktarimBaslik", icon: "box", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=kasalar", anahtar: "tanimKasalar", icon: "money", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=gelir-gider-gruplari", anahtar: "tanimGelirGiderGruplari", icon: "folder", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=gelir-gider-tanimlari", anahtar: "tanimGelirGiderTanimlari", icon: "list", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=firmalar", anahtar: "tanimFirmalar", icon: "building", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=gorev-kategorileri", anahtar: "tanimGorevKategorileri", icon: "tag", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=personel-kayitlari", anahtar: "tanimPersonel", icon: "users", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=arac-kayitlari", anahtar: "tanimAraclar", icon: "car", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=sayaclar-ana", anahtar: "tanimSayaclar", icon: "gauge", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=sayaclar-bolum", anahtar: "tanimSayaclarBolum", icon: "submeter", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=unit-tipleri", anahtar: "tanimDaireTipleri", icon: "home", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=unit-gruplari", anahtar: "tanimDaireGruplari", icon: "homes", grup: "tanimlar" },
  // "Ayarlar" sekmesi de bir BOLUMDUR ve menude yeri olmali; sayfada
  // yerel duruma bagliydi, bu turda o da adrese tasindi (bkz. tanimlar
  // sayfasi) — yoksa menuden acilamayan tek sekme olarak kalirdi.
  { href: "/tanimlar", sorgu: "defter=ayarlar", anahtar: "tanimAyarlar", icon: "gear", grup: "tanimlar" },

  { href: "/users", anahtar: "kabukKullanicilar", icon: "users", grup: "yonetim" },
  // (P193 §5) Tesis ayarlari — YONETIM grubunda, `/settings` (platform)
  // ile karismasin diye ayri ad ve ayri ikon.
  { href: "/tesis-ayarlari", anahtar: "kabukTesisAyarlari", icon: "building", grup: "yonetim" },
  { href: "/transparency", anahtar: "kabukSeffaflik", icon: "eye", grup: "yonetim" },
  // (P167 §6.1) "YONETISIM" BASLIGI KALDIRILDI ve icindeki dort bolum
  // KENDI SATIRLARINA cikti. Eski hâlde tek bir satirin arkasinda karar
  // defteri, dokuman arsivi, KVKK metni ve gurultu uyarilari duruyordu —
  // yani menude aranan hicbiri BULUNAMIYORDU. "Yonetisim" bir is degil
  // bir SOYUTLAMADIR; kullanici "karar defteri"ni arar.
  { href: "/karar-defteri", anahtar: "kabukKararDefteri", icon: "gavel", grup: "yonetim" },
  { href: "/dokumanlar", anahtar: "kabukDokumanlar", icon: "folder", grup: "yonetim" },
  { href: "/gurultu-uyarilari", anahtar: "kabukGurultuUyarilari", icon: "bell", grup: "yonetim" },
  { href: "/audit", anahtar: "kabukDenetimKaydi", icon: "scan", grup: "yonetim" },
  // (P41) Yetki matrisi denetimin yaninda.
  { href: "/yetki", anahtar: "kabukYetki", icon: "shield", grup: "yonetim" },
  { href: "/kvkk", anahtar: "kabukKvkk", icon: "doc", grup: "yonetim" },
];

/**
 * PROFIL GRUPTA DEGILDIR — ve (P167 §1.7) artik KENAR CUBUGUNDA da degil.
 *
 * SAG USTE tasindi: avatar + tesis adi + kullanici adi, tiklaninca acilan
 * bir menu. Gerekce, kullanicinin aradigi yerdir — hesabina dair her sey
 * (bilgiler, guvenlik, bildirim, parola, cikis) bilinen bir konvansiyonla
 * sag ust kosede aranir; sol menu ise SITEYE ait ekranlarin listesidir.
 * Ikisini karistirmak, kendi kaydini "yonetim isleri" arasinda aratiyordu.
 *
 * KAYIT BURADA KALDI cunku profil hâlâ bir SAYFA: `sayfaAra` onu bulmali
 * ("profil" yazan kullanici gidebilmeli) ve gorunurlugu yine
 * `ROTA_ROLLERI`den gelir.
 */
export const PROFIL_OGESI: MenuOgesi = {
  href: "/profil",
  anahtar: "kabukProfil",
  icon: "users",
  grup: "yonetim",
};

/**
 * (P167 §1.8) KURULUM SIHIRBAZI — bolum ogesi DEGIL, alt cubugun ust satiri.
 *
 * Tanimlar bolumunun icindeydi ve orada bir DEFTER gibi gorunuyordu; oysa
 * sihirbaz bir kayit turu degil, o kayitlari sirayla dolduran bir AKIS.
 * Alt cubukta tam genislikte tek satir olarak durur: ne bir bolume ait
 * gorunur ne de tema/cikis ile ayni onem duzeyine iner.
 *
 * `PROFIL_OGESI` ile ayni desen — arama onu hâlâ bulur, rol kapisi hâlâ
 * `ROTA_ROLLERI`den gelir.
 */
export const KURULUM_OGESI: MenuOgesi = {
  href: "/kurulum",
  anahtar: "kurulumBaslik",
  icon: "check",
  grup: "tanimlar",
};

export interface MenuGrubu {
  id: GrupId;
  anahtar: SozlukAnahtari;
  ogeler: MenuOgesi[];
  /**
   * (P167 §1.3) Basliksiz mi cizilecek?
   *
   * `true` ise kabuk bolum basligini CIZMEZ ve ogeleri IKONLU gosterir —
   * "bagimsiz ust sekme" gorunumu. `false` ise baslik ikonlu bir acilir
   * dugmedir, ogeler ikonsuz ve girintilidir.
   */
  bagimsiz: boolean;
}

/**
 * Yuzey + role gorunen menuyu BOLUMLENMIS dondurur.
 *
 * BOS BOLUM CIZILMEZ: denetci dort sayfa goruyor; bes baslik altinda dort
 * satir gostermek, menuyu kisaltmak icin yapilan isi tersine cevirirdi.
 */
export function menuGruplari(yuzey: Yuzey, rol: string | null): MenuGrubu[] {
  const gorunen = OGELER.filter(
    (o) => rotaYuzeyi(o.href) === yuzey && rotaRoldeGorunur(o.href, rol),
  );
  return GRUP_SIRASI.map((id) => ({
    id,
    anahtar: GRUP_ANAHTARI[id],
    ogeler: gorunen.filter((o) => o.grup === id),
    bagimsiz: BAGIMSIZ_GRUPLAR.has(id),
  })).filter((g) => g.ogeler.length > 0);
}

/** Bir menu ogesi bu yuzey + rolde gorunuyor mu? */
function ogeGorunur(oge: MenuOgesi, yuzey: Yuzey, rol: string | null): boolean {
  return rotaYuzeyi(oge.href) === yuzey && rotaRoldeGorunur(oge.href, rol);
}

/** Profil bu rolde gorunuyor mu? (Sag ust kullanici menusu — §1.7) */
export function profilGorunur(yuzey: Yuzey, rol: string | null): boolean {
  return ogeGorunur(PROFIL_OGESI, yuzey, rol);
}

/** Kurulum sihirbazi bu rolde gorunuyor mu? (Alt cubuk — §1.8) */
export function kurulumGorunur(yuzey: Yuzey, rol: string | null): boolean {
  return ogeGorunur(KURULUM_OGESI, yuzey, rol);
}

/**
 * Bir rotanin ait oldugu bolum — acilista HANGI bolumun acik gelecegini
 * bulmak icin.
 *
 * (P167 §1.2) BILINMEYEN ROTA ARTIK HICBIR BOLUMU ACMAZ. Eskiden `null`
 * gorulunce ILK bolum aciliyordu; yeni varsayilan "hepsi kapali" oldugu
 * icin bu davranis kullanicinin kapali birakma tercihini bozar. `/profil`
 * ve `/kurulum` da bilerek `null` doner — ikisi de bolum disidir (§1.7,
 * §1.8).
 */
export function rotaninGrubu(pathname: string): GrupId | null {
  const tam = OGELER.find((o) => o.href === pathname);
  if (tam) return tam.grup;
  // `/reports/patrols` gibi alt rotalar: en uzun onek eslesmesi.
  const onek = OGELER.filter((o) => pathname.startsWith(`${o.href}/`)).sort(
    (a, b) => b.href.length - a.href.length,
  )[0];
  return onek?.grup ?? null;
}

/* =========================================================================
 * (P166 §2) SAYFA ARAMASI — "aidat" yazan kullanici Aidat SAYFASINI bulur
 * =========================================================================
 *
 * Global arama bugune kadar yalniz KAYIT ariyordu (kisi, daire, gorev...).
 * Bir sayfanin ADINI yazan kullanici "sonuc yok" goruyordu; oysa aradigi
 * sey menude, iki baslik altinda duruyordu.
 *
 * NEDEN SUNUCUDA DEGIL, BURADA
 * ----------------------------
 * Kayit aramasi sunucudadir ve OYLE KALMALI: kayitlarin icerigi tarayiciya
 * gonderilemez. Sayfa aramasi ise BASKA bir sey — aranan kume, kenar
 * cubugunun ZATEN cizdigi kumenin ta kendisi. Sunucuya tasimak, ayni
 * gorunurluk kararini ikinci bir yerde tekrar etmek olurdu; ikisi
 * ayrisirsa arama menuden farkli bir kume gosterirdi.
 *
 * YETKI SIZINTISI YOK ve bunun gerekcesi tam olarak sudur: kume
 * `menuGruplari(yuzey, rol)`ten geliyor, yani kenar cubugundakiyle AYNI
 * fonksiyondan. Aramada gorunen bir sayfa menude de gorunur; menude
 * gorunmeyen aramada da gorunmez. Ikinci bir suzgec YAZILMADI — yazilsaydi
 * ikinci bir yetki karari olur ve biri unutuldugunda sizinti SESSIZ olurdu.
 */

/**
 * Turkce duyarli, aksan gormeyen karsilastirma anahtari.
 *
 * Klavyesinde Turkce harf olmayan ya da acele eden kullanici aksan
 * yazmaz; aksansiz yazim aksanli basligi BULMALI. `NFD` cozup birlesen
 * isaretleri atmak bunu saglar.
 *
 * NOKTASIZ I (U+0131) AYRI ELE ALINIR: `NFD` onu cozmez (birlesen bir
 * isareti yoktur, ayri bir harftir) ve `toLocaleLowerCase("tr")` buyuk
 * `I`yi ona cevirir. Elle esitlenmezse "Iletisim" yazan kullanici
 * hicbir sey bulamazdi. Kacis dizisiyle yazildi: bu dosyada gorunur
 * metin YOKTUR ve tarama (tur 22) harfin kendisini sabit metin sanar.
 */
function aramaAnahtari(s: string): string {
  return s
    .toLocaleLowerCase("tr")
    .replace(/\u0131/g, "i")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

/** Sayfa vurusu — menu ogesinin kendisi + hangi bolumde oldugu. */
export interface SayfaVurusu {
  oge: MenuOgesi;
  /** Bolum basligi anahtari — sonucta "Finans › Aidat" gibi baglam verir. */
  grupAnahtari: SozlukAnahtari;
}

/**
 * Rolde GORUNEN sayfalar icinde ad aramasi.
 *
 * `etiket` disaridan gelir cunku menu ogeleri METIN degil ANAHTAR tasir ve
 * cozum aktif dile baglidir — bu modul i18n'e (dolayisiyla React'e) bagli
 * olmamali, testte de saf cagrilabilmeli.
 *
 * SIRALAMA: once ADI sorguyla BASLAYANLAR, sonra adinin icinde gecenler,
 * en sonda yalniz BOLUM ADI eslesenler. "aidat" yazan kullanici once Aidat
 * sayfasini gormeli, "Finans" bolumunun tamamini degil.
 */
export function sayfaAra(
  yuzey: Yuzey,
  rol: string | null,
  q: string,
  etiket: (a: SozlukAnahtari) => string,
  sinir = 6,
): SayfaVurusu[] {
  const aranan = aramaAnahtari(q.trim());
  if (aranan.length < 2) return [];

  const gruplar = menuGruplari(yuzey, rol);
  // PROFIL de bir sayfadir. Menude bolum disinda cizilir ama aranabilir
  // olmali — kullanici "profil" yazip kendi kaydina gidebilmeli.
  const kume: SayfaVurusu[] = gruplar.flatMap((g) =>
    g.ogeler.map((oge) => ({ oge, grupAnahtari: g.anahtar })),
  );
  // PROFIL ve KURULUM SIHIRBAZI menude bolum disindadir (§1.7 sag ust,
  // §1.8 alt cubuk) ama ikisi de birer SAYFA — aramanin onlari bulmamasi,
  // kullaniciyi "menude yok, o hâlde yok" sonucuna gotururdu.
  for (const oge of [PROFIL_OGESI, KURULUM_OGESI]) {
    if (ogeGorunur(oge, yuzey, rol)) {
      kume.push({ oge, grupAnahtari: GRUP_ANAHTARI[oge.grup] });
    }
  }

  const puanli: { v: SayfaVurusu; puan: number }[] = [];
  for (const v of kume) {
    const ad = aramaAnahtari(etiket(v.oge.anahtar));
    const bolum = aramaAnahtari(etiket(v.grupAnahtari));
    if (ad.startsWith(aranan)) puanli.push({ v, puan: 0 });
    else if (ad.includes(aranan)) puanli.push({ v, puan: 1 });
    else if (bolum.includes(aranan)) puanli.push({ v, puan: 2 });
  }
  // KARARLI SIRALAMA: esit puanda menudeki sira korunur, yoksa ayni sorgu
  // iki cagrida farkli siralar dondurebilirdi.
  return puanli
    .map((p, i) => ({ ...p, i }))
    .sort((a, b) => a.puan - b.puan || a.i - b.i)
    .slice(0, sinir)
    .map((p) => p.v);
}

/** Yalniz testler icin: ham liste (her ogenin bir gruba dustugu olculur). */
export const _OGELER = OGELER;
