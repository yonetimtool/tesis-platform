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
  | "users" | "megaphone" | "chat" | "bell" | "hub" | "gear";

/** Bolum kimlikleri. Sira BURADAKI siradir (menude de bu sirayla cizilir). */
export type GrupId =
  | "guvenlik"
  | "tesis"
  | "finans"
  // (P154 / Asama 7.1) Brief'in FINANS listesindeki ALTI ALT GORUNUM
  // (Tahsilatlar, Gelirler, Giderler, Virman, Iade, Acilis fisleri) KENDI
  // KATLI BOLUMUNDE durur, `finans`in icinde DEGIL.
  //
  // NEDEN: olculdu — hepsini `finans`a koyunca bolum 5 satirdan 11'e cikti
  // ve finans acikken menu 17 satir oldu. Kerem'in olculebilir sarti
  // "900px'te kaydirmasiz ~10 satir"di; `test_..SATIR SAYISI` bunu 12'de
  // kilitliyor. Kilidi gevsetmek olcuyu isin pesinden surumek olurdu.
  // "Daha fazla"nin ardinda hepsi ERISILEBILIR, gunluk butce ise korunur.
  | "finansHareket"
  // (P154 / Asama 7.1) Brief: "ICRA DOSYALARI: ayri ust sekme". Finansin
  // altinda bir satir DEGIL, kendi bolumu — icra hukuki bir surectir ve
  // para hareketiyle ayni yerde durmasi ikisini karistirir (goc 0029'un
  // notu: borc `dues_assessment`ta durur, icraya KOPYALANMAZ).
  | "icra"
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
  guvenlik: "kabukGrupGuvenlik",
  tesis: "kabukGrupTesis",
  finans: "kabukGrupFinans",
  finansHareket: "kabukGrupFinansHareket",
  icra: "kabukGrupIcra",
  iletisim: "kabukGrupIletisim",
  tanimlar: "kabukGrupTanimlar",
  yonetim: "kabukGrupYonetim",
  platform: "kabukGrupPlatform",
};

// (P166 §1) SIRA ARTIK ANLAMA GORE, "hangisi katlanir"a gore DEGIL.
//
// Eski dizide `platform` ortadaydi cunku katli olmayan son bolumdu —
// yani sirayi katlama karari belirliyordu. Katlama gidince olcut de
// degisti: para hareketleri paranin, tanimlar da yonetimin yanindadir.
const GRUP_SIRASI: readonly GrupId[] = [
  "guvenlik",
  "tesis",
  "finans",
  "finansHareket",
  "icra",
  "iletisim",
  "tanimlar",
  "yonetim",
  "platform",
];

// Menu ogeleri METIN degil ANAHTAR tasir: etiket cizim aninda aktif dilde
// cozulur. Sira GRUP ICINDE anlamlidir (once gunluk bakilan, sonra kurulum).
const OGELER: readonly MenuOgesi[] = [
  // --- GUVENLIK: gunluk saha akisi --------------------------------------
  { href: "/dashboard", anahtar: "kabukCanliPanel", icon: "grid", grup: "guvenlik" },
  { href: "/olaylar", anahtar: "kabukOlaylar", icon: "bell", grup: "guvenlik" },
  { href: "/notifications", anahtar: "kabukBildirimler", icon: "bell", grup: "guvenlik" },
  { href: "/kameralar", anahtar: "kabukKameralar", icon: "scan", grup: "guvenlik" },
  { href: "/shifts", anahtar: "kabukVardiyalar", icon: "clock", grup: "guvenlik" },
  { href: "/checkpoints", anahtar: "kabukNfcNoktalari", icon: "scan", grup: "guvenlik" },
  { href: "/patrol-plans", anahtar: "kabukDevriyePlanlari", icon: "route", grup: "guvenlik" },
  { href: "/ziyaretciler", anahtar: "kabukZiyaretciler", icon: "users", grup: "guvenlik" },
  { href: "/kargolar", anahtar: "kabukKargolar", icon: "box", grup: "guvenlik" },
  { href: "/arac-gecisleri", anahtar: "kabukAracGecisleri", icon: "scan", grup: "guvenlik" },

  // --- TESIS: binanin kendisi -------------------------------------------
  { href: "/units", anahtar: "kabukDaireler", icon: "home", grup: "tesis" },
  { href: "/tasks", anahtar: "kabukGorevler", icon: "check", grup: "tesis" },
  { href: "/gorevlerim", anahtar: "kabukGorevlerim", icon: "check", grup: "tesis" },
  { href: "/assets", anahtar: "kabukDemirbas", icon: "box", grup: "tesis" },
  { href: "/schematic", anahtar: "kabukSikayetHaritasi", icon: "pin", grup: "tesis" },
  { href: "/dis-hizmetler", anahtar: "kabukDisHizmetler", icon: "hub", grup: "tesis" },
  { href: "/etkinlikler", anahtar: "kabukEtkinlikler", icon: "clock", grup: "tesis" },
  { href: "/rezervasyonlarim", anahtar: "kabukRezervasyon", icon: "clock", grup: "tesis" },
  { href: "/kurallar", anahtar: "kabukKurallar", icon: "check", grup: "tesis" },

  // --- FINANS: para -----------------------------------------------------
  // (P154 / Asama 7.1) Brief'in FINANS listesi: Borclandirmalar ·
  // Tahsilatlar · Gelirler · Giderler · Hesaplar arasi virman · Odeme
  // iadesi · Acilis fisleri.
  //
  // ALTISI YENI SAYFA DEGIL, `/finans`in `tip` SUZGECI. Yedi ayri sayfa
  // acmak ayni defter tablosunu yedi kez yazmak olurdu; sayfa zaten bu
  // alti tipi taniyor (`TIPLER` dizisi) ve suzgeci artik adresten okuyor.
  { href: "/dues", anahtar: "kabukAidat", icon: "money", grup: "finans" },
  { href: "/aidatim", anahtar: "kabukAidatim", icon: "money", grup: "finans" },
  { href: "/finans", anahtar: "kabukFinans", icon: "money", grup: "finans" },
  { href: "/finans", sorgu: "tip=tahsilat", anahtar: "kabukTahsilatlar", icon: "money", grup: "finansHareket" },
  { href: "/finans", sorgu: "tip=gelir", anahtar: "kabukGelirler", icon: "money", grup: "finansHareket" },
  { href: "/finans", sorgu: "tip=gider", anahtar: "kabukGiderler", icon: "money", grup: "finansHareket" },
  { href: "/finans", sorgu: "tip=virman", anahtar: "kabukVirman", icon: "money", grup: "finansHareket" },
  { href: "/finans", sorgu: "tip=iade", anahtar: "kabukIade", icon: "money", grup: "finansHareket" },
  { href: "/finans", sorgu: "tip=acilis", anahtar: "kabukAcilisFisleri", icon: "money", grup: "finansHareket" },
  // (P111) Sayac okuma tanimlardan beslenir, ciktisi bir tahakkuktur.
  { href: "/sayac-okuma", anahtar: "kabukSayacOkuma", icon: "chart", grup: "finans" },
  { href: "/reports/dues", anahtar: "kabukRaporlar", icon: "chart", grup: "finans" },
  // (P40) 12 raporluk katalog; `/reports/dues` tek raporluk eski sayfadir
  // ve ikisi YAN YANA durur ki eski baglantilar kirilmasin.
  { href: "/raporlar", anahtar: "kabukRaporMotoru", icon: "chart", grup: "finans" },

  // --- ICRA: ayri ust bolum (brief 7.1) ---------------------------------
  // Uc (`/finans/icra-dosyalari`) ve BFF kaydi VARDI, EKRANI YOKTU —
  // envanterdeki "olu BFF ucu" sinifinin bir uyesi. Brief "olmayani ac"
  // dedigi icin sayfa bu turda acildi.
  { href: "/icra", anahtar: "kabukIcra", icon: "scan", grup: "icra" },

  // --- PLATFORM: yalniz `panel.*` ---------------------------------------
  { href: "/tenants", anahtar: "kabukTesisler", icon: "building", grup: "platform" },
  { href: "/integrations", anahtar: "kabukEntegrasyonlar", icon: "hub", grup: "platform" },
  { href: "/settings", anahtar: "kabukAyarlar", icon: "gear", grup: "platform" },

  // --- ILETISIM: siteye seslenme + sakinden gelen -----------------------
  { href: "/announcements", anahtar: "kabukDuyurular", icon: "megaphone", grup: "iletisim" },
  // (P162) SITE KURALI ve ETKINLIK YONETIMI — `iletisim` grubunda, TESIS
  // grubunda DEGIL. Iki gerekce:
  //
  //  1. ANLAM: ucu de yonetimin SAKINE YAYINLADIGI icerik. Duyuru
  //     yonetimi zaten burada; kural ve etkinlik ondan farkli degil.
  //  2. OLCUM: `tesis` grubu zaten en kalabalik olan. Iki satir daha
  //     eklemek acilistaki gorunur satiri 13'e cikariyordu ve
  //     `menu-gruplari` testi (P133.1: en cok 12) hakli olarak dustu.
  //     Bu bir bicim kurali degil, kaydirma cubugunu onleyen bir butce.
  { href: "/site-kurallari", anahtar: "kabukKuralYonetimi", icon: "check", grup: "iletisim" },
  { href: "/etkinlik-yonetimi", anahtar: "kabukEtkinlikYonetimi", icon: "clock", grup: "iletisim" },
  { href: "/duyurular", anahtar: "kabukDuyurularim", icon: "megaphone", grup: "iletisim" },
  { href: "/mesajlar", anahtar: "kabukMesajlar", icon: "megaphone", grup: "iletisim" },
  // (P154 / Asama 7.1) Brief: "SMS gonderimi · WhatsApp · E-posta
  // gonderimi". Uc ayri sayfa DEGIL — `/mesajlar` zaten kanal seciyor,
  // menu yalnizca o secimi onceden yapar.
  { href: "/mesajlar", sorgu: "kanal=sms", anahtar: "kabukSmsGonderimi", icon: "chat", grup: "iletisim" },
  // WHATSAPP SATIRI YOK — brief'in listesinde var ama `mesaj_kanal` enum'u
  // bugun yalniz `sms, eposta` tasiyor. Tiklanabilir ama sablonu
  // KAYDEDILEMEYEN bir satir, tam da temizlemeye calistigimiz "olu
  // baglanti" sinifi olurdu. Asama 9'un kalan isi (enum + sablon onay
  // alanlari) bittiginde tek satirla acilir.
  { href: "/mesajlar", sorgu: "kanal=eposta", anahtar: "kabukEpostaGonderimi", icon: "chat", grup: "iletisim" },
  { href: "/complaints", anahtar: "kabukTalepler", icon: "chat", grup: "iletisim" },
  { href: "/taleplerim", anahtar: "kabukTaleplerim", icon: "chat", grup: "iletisim" },
  { href: "/anketler", anahtar: "kabukAnketler", icon: "chat", grup: "iletisim" },
  { href: "/yonetim-iletisim", anahtar: "kabukYonetimIletisim", icon: "chat", grup: "iletisim" },
  // (P155 §7) Davet gonderim durumu — kisiye kayit bagi gonderildi mi.
  { href: "/davetler", anahtar: "kabukDavetler", icon: "megaphone", grup: "iletisim" },
  { href: "/support", anahtar: "kabukDestek", icon: "chat", grup: "iletisim" },

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
  // (P154 / Asama 7.3) Sihirbaz TANIMLAR bolumunun BASINDA: kurulum
  // adimlarinin cogu bu bolumun ekranlaridir ve yeni yonetici once
  // buraya bakmali.
  { href: "/kurulum", anahtar: "kurulumBaslik", icon: "check", grup: "tanimlar" },
  { href: "/ice-aktarim", anahtar: "iceAktarimBaslik", icon: "box", grup: "tanimlar" },
  { href: "/building-editor", anahtar: "kabukBloklar", icon: "edit", grup: "tanimlar" },
  { href: "/tanimlar", anahtar: "kabukTanimlar", icon: "box", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=unit-tipleri", anahtar: "kabukDaireTipleri", icon: "home", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=kasalar", anahtar: "kabukKasalar", icon: "money", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=gelir-gider-tanimlari", anahtar: "kabukGelirGiderTanimlari", icon: "chart", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=gorev-kategorileri", anahtar: "tanimGorevKategorileri", icon: "check", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=personel-kayitlari", anahtar: "kabukPersonel", icon: "users", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=arac-kayitlari", anahtar: "kabukAraclar", icon: "scan", grup: "tanimlar" },
  { href: "/tanimlar", sorgu: "defter=sayaclar-ana", anahtar: "kabukSayaclar", icon: "chart", grup: "tanimlar" },

  { href: "/users", anahtar: "kabukKullanicilar", icon: "users", grup: "yonetim" },
  { href: "/transparency", anahtar: "kabukSeffaflik", icon: "money", grup: "yonetim" },
  // (P40) Yonetisim denetim kaydinin YANINDA: ikisi de "ne karar alindi,
  // kim ne yapti" sorusunu yanitlar.
  { href: "/yonetisim", anahtar: "kabukYonetisim", icon: "building", grup: "yonetim" },
  { href: "/audit", anahtar: "kabukDenetimKaydi", icon: "scan", grup: "yonetim" },
  // (P41) Yetki matrisi denetimin yaninda.
  { href: "/yetki", anahtar: "kabukYetki", icon: "users", grup: "yonetim" },
  { href: "/kvkk", anahtar: "kabukKvkk", icon: "users", grup: "yonetim" },
];

/**
 * PROFIL GRUPTA DEGILDIR — alt bolumde, cikis dugmesinin yanindadir.
 *
 * Bir bolume koymak onu "yonetim isi" gibi gosterirdi; oysa kullanicinin
 * KENDI kaydidir ve her rolde ayni yerde durmasi beklenir. Gorunurlugu
 * yine `ROTA_ROLLERI`den gelir (bu tur degistirmedi).
 */
export const PROFIL_OGESI: MenuOgesi = {
  href: "/profil",
  anahtar: "kabukProfil",
  icon: "users",
  grup: "yonetim",
};

export interface MenuGrubu {
  id: GrupId;
  anahtar: SozlukAnahtari;
  ogeler: MenuOgesi[];
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
  })).filter((g) => g.ogeler.length > 0);
}

/** Profil satiri bu rolde gorunuyor mu? */
export function profilGorunur(yuzey: Yuzey, rol: string | null): boolean {
  return (
    rotaYuzeyi(PROFIL_OGESI.href) === yuzey &&
    rotaRoldeGorunur(PROFIL_OGESI.href, rol)
  );
}

/**
 * Bir rotanin ait oldugu bolum — acilista HANGI bolumun acik gelecegini
 * bulmak icin.
 *
 * Bilinmeyen rota `null` doner ve o durumda ILK bolum acilir (bkz. kabuk):
 * "hicbiri acik degil" hâli, menuyu bos bir baslik listesine cevirirdi.
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
  if (profilGorunur(yuzey, rol)) {
    kume.push({ oge: PROFIL_OGESI, grupAnahtari: GRUP_ANAHTARI[PROFIL_OGESI.grup] });
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
