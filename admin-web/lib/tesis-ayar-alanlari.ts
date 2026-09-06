// (P193 §5) TESIS AYAR ALANLARI — TEK TABLO, IKI EKRAN.
//
// =========================================================================
// NEDEN `lib`DE
// =========================================================================
// Bu tablo P40'tan beri `app/(protected)/settings/page.tsx` icinde
// duruyordu. P193 §5 yoneticiye kendi ekranini (`/tesis-ayarlari`) actı;
// tabloyu ikinci kez yazmak, bir alan eklendiginde iki listeden birinin
// unutulmasi demekti — ve unutulan liste SESSIZCE eksik kalirdi (ekranda
// alan yok, sunucu alani kabul ediyor).
//
// Ayrica Next.js sayfa dosyalari yalnizca bilinen disa aktarimlara izin
// verir; tablo sayfada kaldigi surece oteki sayfadan OKUNAMIYORDU
// (`lib/kurulum-adimlari.ts` basliginda ayni tuzak kayitli).
//
// =========================================================================
// `adminOnly` NE DEMEK
// =========================================================================
// Sunucudaki `_YONETICI_YAZABILIR` kumesinin DISINDA kalan alan. Karar
// SUNUCUDA; buradaki bayrak yalnizca cizim: yoneticiye 403 alacagi bir
// alani gostermemek icin. Ikisi ayrisirsa yonetici formu doldurup
// kaydedemez — bu yuzden yeni bir alan eklerken ikisi birlikte
// guncellenir.
import type { TenantSettings } from "@/lib/types";
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

/** (P219 §1) AYAR GRUPLARI — hepsi tek listede olmasin.
 *
 * On bes ayar tek bir sutunda diziliyordu ve aralarinda hicbir baglanti
 * yoktu: devriye toleransi, gurultu susma suresi ve borc hedefi ard
 * arda. Yonetici aradigi ayari bulmak icin listenin tamamini okumak
 * zorundaydi.
 *
 * Gruplama ISLEVE gore: kullanicinin "neyi ayarlamak istiyorum"
 * sorusuna karsilik gelir, koddaki tablo adina degil.
 */
export type AyarGrubu =
  | "devriye"
  | "vardiya"
  | "gurultu"
  | "finans"
  | "rezervasyon";

/** Grup sirasi ve basliklari (cizim sirasi BURADAKI siradir). */
export const AYAR_GRUPLARI: { id: AyarGrubu; baslik: SozlukAnahtari }[] = [
  { id: "devriye", baslik: "ayarGrupDevriye" },
  { id: "vardiya", baslik: "ayarGrupVardiya" },
  { id: "gurultu", baslik: "ayarGrupGurultu" },
  { id: "finans", baslik: "ayarGrupFinans" },
  { id: "rezervasyon", baslik: "ayarGrupRezervasyon" },
];

/** Operasyon ayari alan tanimi. `anahtar` backend alan adidir. */
export interface Ayar {
  /** (P219 §1) Hangi baslik altinda cizilecek. */
  grup: AyarGrubu;
  anahtar: keyof TenantSettings & string;
  etiket: SozlukAnahtari;
  ipucu?: SozlukAnahtari;
  tip: "sayi" | "bool" | "metin" | "secim";
  secenekler?: { deger: string; etiket: SozlukAnahtari }[];
  min?: number;
  max?: number;
  /** YALNIZ admin degistirebilir (sunucu de zorlar; burada gorunurluk). */
  adminOnly?: boolean;
}

/** Alan tipi -> HTML input tipi. Ucluda ("sayi" ? "number" : "text")
 *  yazmak, sabit-metin taramasini cevrilmemis metin sanip uyarmaya iterdi;
 *  bunlar KULLANICI METNI DEGIL teknik jetondur. */
export const GIRDI_TIPI: Record<string, string> = { sayi: "number", metin: "text" };

export const OPERASYON: Ayar[] = [
  // --- P34 tur butunlugu ---
  {
    grup: "devriye",
    anahtar: "tur_gecikme_toleransi_dk",
    etiket: "ayarTurTolerans",
    ipucu: "ayarTurToleransIpucu",
    tip: "sayi",
    min: 1,
    max: 240,
  },
  {
    grup: "devriye",
    anahtar: "tur_alarm_tekrar_sayisi",
    etiket: "ayarTurTekrar",
    ipucu: "ayarTurTekrarIpucu",
    tip: "sayi",
    min: 0,
    max: 10,
  },
  {
    grup: "devriye",
    anahtar: "tur_baslangic_foto_zorunlu",
    etiket: "ayarTurFoto",
    ipucu: "ayarTurFotoIpucu",
    tip: "bool",
  },
  // --- (P207 §3) VARDIYA HATIRLATMA ---
  {
    grup: "vardiya",
    anahtar: "vardiya_hatirlatma_dk",
    etiket: "ayarVardiyaHatirlatma",
    ipucu: "ayarVardiyaHatirlatmaIpucu",
    // METIN, sayi DEGIL: kademe listesi ("30,5"). Sayi alani yapmak
    // tek kademeye mahkum ederdi; bos birakmak KAPALI demektir ve
    // sunucu bunu 422 ile degil sessizce "kapali" diye okur.
    tip: "metin",
  },
  {
    grup: "vardiya",
    anahtar: "vardiya_baslamadi_dk",
    etiket: "ayarVardiyaBaslamadi",
    ipucu: "ayarVardiyaBaslamadiIpucu",
    tip: "sayi",
    // Sinirlar SUNUCUYLA AYNI (DB CHECK + API Field). 0 = KAPALI.
    min: 0,
    max: 180,
  },
  // --- P35 guvenlik modu ---
  {
    grup: "vardiya",
    anahtar: "guvenlik_modu",
    etiket: "ayarGuvenlikModu",
    ipucu: "ayarGuvenlikModuIpucu",
    tip: "secim",
    secenekler: [
      { deger: "yonetim_ici", etiket: "ayarGuvenlikYonetimIci" },
      { deger: "dis_sirket", etiket: "ayarGuvenlikDisSirket" },
    ],
    adminOnly: true,
  },
  // --- (P160) okutma mesafe esigi ---
  {
    grup: "devriye",
    anahtar: "okutma_mesafe_esigi_m",
    etiket: "ayarOkutmaMesafe",
    ipucu: "ayarOkutmaMesafeIpucu",
    tip: "sayi",
    // Sinirlar SUNUCUYLA AYNI (sema CHECK + API Field): burada dar bir
    // aralik yazmak, sunucunun kabul ettigi bir degeri panelde
    // reddetmek olurdu.
    min: 1,
    max: 5000,
  },
  // --- (P165) rezervasyon gecmisi saklama penceresi ---
  {
    grup: "rezervasyon",
    anahtar: "rezervasyon_gecmis_ay",
    etiket: "ayarRezervasyonGecmis",
    ipucu: "ayarRezervasyonGecmisIpucu",
    tip: "sayi",
    // `0 = SINIRSIZ` ve alt sinir bu yuzden 0: ayar bir saklama
    // politikasini ZORLAMAMALI. Ust sinir 120 ay (10 yil) — daha uzugu
    // bir politika degil, yanlis girilmis bir deger olurdu. Sinirlar
    // sunucudaki `Field(ge=0, le=120)` ve DDL `CHECK` ile AYNI.
    min: 0,
    max: 120,
  },
  // --- P37 gurultu caydirici ---
  {
    // =====================================================================
    // (P218) YENI GIDER TURLERININ VARSAYILAN BORC HEDEFI
    // =====================================================================
    // Kat Mulkiyeti Kanunu md. 20 gideri turune gore ayiriyor (isletme
    // -> kullanan, bakim/onarim -> malik) AMA uygulamada siteler farkli
    // davraniyor: bazilari her seyi malige yaziyor, bazilari kira
    // sozlesmesine bakiyor. Urun bunlardan birini dayatamaz.
    //
    // ZORLAYICI DEGIL, YALNIZCA VARSAYILAN: tur bazinda her zaman
    // degistirilebilir (Tanimlar > Gelir/Gider turleri). Tenant
    // duzeyinde KILIT olsaydi, o siteye bir gun su faturasini kiraciya
    // yazmak gerektiginde ayar TUM turleri birden etkilerdi.
    grup: "finans",
    anahtar: "varsayilan_hedef_kurali",
    etiket: "ayarVarsayilanHedef",
    ipucu: "ayarVarsayilanHedefIpucu",
    tip: "secim",
    secenekler: [
      { deger: "kiraci_oncelikli", etiket: "tanimHedefKullanan" },
      { deger: "malik", etiket: "tanimHedefMalik" },
    ],
  },
  {
    grup: "gurultu",
    anahtar: "gurultu_esigi",
    etiket: "ayarGurultuEsigi",
    ipucu: "ayarGurultuEsigiIpucu",
    tip: "sayi",
    min: 1,
    max: 50,
  },
  {
    grup: "gurultu",
    anahtar: "gurultu_uyari_metni",
    etiket: "ayarGurultuMetni",
    ipucu: "ayarGurultuMetniIpucu",
    tip: "metin",
  },
  // --- (P208 §1) SAYIM PENCERESI / SUSMA / SAKINE BILDIRIM ---
  {
    grup: "gurultu",
    anahtar: "gurultu_pencere_gun",
    etiket: "ayarGurultuPencere",
    ipucu: "ayarGurultuPencereIpucu",
    tip: "sayi",
    // 0 = SINIRSIZ (P37 davranisi) — sinirlar sunucuyla AYNI.
    min: 0,
    max: 365,
  },
  {
    grup: "gurultu",
    anahtar: "gurultu_susma_gun",
    etiket: "ayarGurultuSusma",
    ipucu: "ayarGurultuSusmaIpucu",
    tip: "sayi",
    min: 0,
    max: 365,
  },
  {
    // (P213 §1) KACINCI ESIK ASIMINDAN SONRA GUVENLIGE.
    //
    // Eskiden KOD SABITIYDI (`asama >= 2`). Bir sitede ikinci uyari,
    // otekinde ucuncu uyari dogru olabilir: bina yogunlugu, guvenlik
    // ekibinin buyuklugu ve komsuluk iliskisi ayni degil.
    // Sinirlar sunucudaki `Field(ge=1, le=10)` ve DDL CHECK ile AYNI.
    grup: "gurultu",
    anahtar: "gurultu_eskalasyon_esigi",
    etiket: "ayarGurultuEskalasyon",
    ipucu: "ayarGurultuEskalasyonIpucu",
    tip: "sayi",
    min: 1,
    max: 10,
  },
  {
    // =====================================================================
    // (P219 §2) HARITADA GORUNME SURESI — SAYIM PENCERESIYLE KARISTIRMA
    // =====================================================================
    // Ikisi ayni grupta ve yan yana duruyor; bu BILINCLI: yonetici
    // ikisini bir arada gorup farki anlasin diye. Aciklamalarda da
    // birbirlerine gonderme var.
    //   `gurultu_pencere_gun`  -> kac GUN geriye SAYILIR   (esik mantigi)
    //   `sikayet_harita_saat`  -> kac SAAT haritada DURUR  (gorunurluk)
    //
    // "Sil" kelimesi HICBIR YERDE gecmiyor: bu bir gorunurluk filtresi
    // ve sikayet kaydi yerinde duruyor.
    grup: "gurultu",
    anahtar: "sikayet_harita_saat",
    etiket: "ayarHaritaSaat",
    ipucu: "ayarHaritaSaatIpucu",
    tip: "sayi",
    min: 0,
    max: 8760,
  },
  {
    grup: "gurultu",
    anahtar: "gurultu_sakin_uyarisi",
    etiket: "ayarGurultuSakin",
    ipucu: "ayarGurultuSakinIpucu",
    tip: "bool",
  },
];
