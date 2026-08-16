// (P167) KURULUM SIHIRBAZI — ADIM HEDEFLERI.
//
// NEDEN `lib`DE, SAYFA ICINDE DEGIL: Next.js sayfa dosyalari yalnizca
// bilinen disa aktarimlara izin verir (`default`, `metadata`, `dynamic`...);
// baska bir `export` DERLEME HATASIDIR. Tablo sayfada durdugu surece
// testten okunamiyordu ve `tsc` bunu yakaladi
// (`lib/tanimlar.ts` basliginda ayni tuzak kayitli).
//
// Tabloyu disari almak ayrica dogru yer: bu bir YONLENDIRME kaydidir
// (hangi adim hangi ekranda tamamlanir), cizim detayi degil.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk";

export interface KurulumHedefi {
  etiket: SozlukAnahtari;
  aciklama: SozlukAnahtari;
  rota: string;
  /**
   * Adimi TAMAMLAMAK icin gereken roller. Verilmezse adim, sihirbazi
   * gorebilen her rolde tamamlanabilir.
   */
  rolGerekli?: readonly string[];
}

/**
 * Adim kodu -> (etiket, aciklama, gidilecek ekran, [tamamlamak icin gereken rol]).
 *
 * (P166 §8.3) `rolGerekli` bir CIKMAZI gorunur kilmak icin eklendi:
 * sihirbaz admin + yonetici'ye goruntlenirken `POST /dues/assessments`
 * YALNIZ ADMIN'di. Yonetici "Aidat" adiminda "Git"e basiyor, `/dues`a
 * gidiyor ve toplu tahakkuk dugmesinde 403 aliyordu.
 *
 * (P167) O CIKMAZ ARTIK YOK: Kerem karari verdi ve uc yoneticiye ACILDI
 * (aidat yazmak site yoneticisinin asil isi). `aidat` adimindaki
 * `rolGerekli` kaldirildi.
 *
 * ALAN SILINMEDI ve bu bilincli. Kaldirdigimiz sey bir KUSURDU, mekanizma
 * degil: bir adimin ucu bir gun yine dar bir role kilitlenirse, kullaniciyi
 * 403'e yollamak yerine tek satirla isaretlemek gerekir. Mekanizmayi silip
 * yeniden yazmak, ayni dersi ikinci kez ogrenmek olurdu.
 * `kurulum-rol-kapisi.dom.test.ts` alanin CALISTIGINI ayrica olcuyor.
 */
export const KURULUM_HEDEFLERI: Record<string, KurulumHedefi> = {
  blok: {
    etiket: "kurulumBlok",
    aciklama: "kurulumBlokAlt",
    rota: "/building-editor",
  },
  daire: {
    etiket: "kurulumDaire",
    aciklama: "kurulumDaireAlt",
    rota: "/building-editor",
  },
  daire_tipi: {
    etiket: "kurulumDaireTipi",
    aciklama: "kurulumDaireTipiAlt",
    rota: "/tanimlar?defter=unit-tipleri",
  },
  sakin: {
    etiket: "kurulumSakin",
    aciklama: "kurulumSakinAlt",
    rota: "/users",
  },
  personel: {
    etiket: "kurulumPersonel",
    aciklama: "kurulumPersonelAlt",
    rota: "/tanimlar?defter=personel-kayitlari",
  },
  gorev_alani: {
    etiket: "kurulumGorevAlani",
    aciklama: "kurulumGorevAlaniAlt",
    // (P166 §8.3) HEDEF DEGISTI: `/tasks` -> kategori DEFTERI.
    //
    // Adimin sunucudaki olcusu `TaskCategory` sayisidir (bkz.
    // `routers/kurulum.py`), yani "gorev alani" = KATEGORI. `/tasks`
    // kategorileri yalniz OKUYOR; kullanici oraya gidip adimi
    // tamamlayamiyordu. Adim, olculen seyin YARATILDIGI ekrana bakmali.
    rota: "/tanimlar?defter=gorev-kategorileri",
  },
  nfc_noktasi: {
    etiket: "kurulumNfc",
    aciklama: "kurulumNfcAlt",
    rota: "/checkpoints",
  },
  aidat: {
    etiket: "kurulumAidat",
    aciklama: "kurulumAidatAlt",
    rota: "/dues",
    // (P167) `rolGerekli` KALKTI: `POST /dues/assessments` yoneticiye
    // acildi, yani adim artik yoneticinin KENDI hesabiyla tamamlanabilir.
    // Alan mekanizma olarak DURUYOR (asagidaki nota bak) — yarin baska bir
    // adim ayni duruma duserse tek satirla isaretlenir.
  },
};

