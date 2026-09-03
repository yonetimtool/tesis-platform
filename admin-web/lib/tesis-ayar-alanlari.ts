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

/** Operasyon ayari alan tanimi. `anahtar` backend alan adidir. */
export interface Ayar {
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
    anahtar: "tur_gecikme_toleransi_dk",
    etiket: "ayarTurTolerans",
    ipucu: "ayarTurToleransIpucu",
    tip: "sayi",
    min: 1,
    max: 240,
  },
  {
    anahtar: "tur_alarm_tekrar_sayisi",
    etiket: "ayarTurTekrar",
    ipucu: "ayarTurTekrarIpucu",
    tip: "sayi",
    min: 0,
    max: 10,
  },
  {
    anahtar: "tur_baslangic_foto_zorunlu",
    etiket: "ayarTurFoto",
    ipucu: "ayarTurFotoIpucu",
    tip: "bool",
  },
  // --- (P207 §3) VARDIYA HATIRLATMA ---
  {
    anahtar: "vardiya_hatirlatma_dk",
    etiket: "ayarVardiyaHatirlatma",
    ipucu: "ayarVardiyaHatirlatmaIpucu",
    // METIN, sayi DEGIL: kademe listesi ("30,5"). Sayi alani yapmak
    // tek kademeye mahkum ederdi; bos birakmak KAPALI demektir ve
    // sunucu bunu 422 ile degil sessizce "kapali" diye okur.
    tip: "metin",
  },
  {
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
    anahtar: "gurultu_esigi",
    etiket: "ayarGurultuEsigi",
    ipucu: "ayarGurultuEsigiIpucu",
    tip: "sayi",
    min: 1,
    max: 50,
  },
  { anahtar: "gurultu_uyari_metni", etiket: "ayarGurultuMetni", ipucu: "ayarGurultuMetniIpucu", tip: "metin" },
];
