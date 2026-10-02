// (P251 §10) YONETICININ GORDUGU SADE TESLIM DURUMU.
//
// Ham saglayici hatasi (535, 5.7.8, bounce) yoneticiye gosterilmez; o
// ayrinti platformdaki "Gonderim gunlugu"nde. Yonetici baglam icinde
// (odeme kodu satiri, hatirlatma e-postasi) yalniz ne olduguna ve NE
// YAPACAGINA dair kisa bir cumle gorur: yanlis e-posta adresini ancak
// "Ulasmadi — e-posta adresi gecersiz olabilir" sayesinde fark eder.
import type { SozlukAnahtari } from "@/lib/i18n/sozluk/tipler";

const ACIKLAMA: Record<string, SozlukAnahtari> = {
  geri_dondu: "teslimAciklama_geri_dondu",
  basarisiz: "teslimAciklama_basarisiz",
  yapilandirilmadi: "teslimAciklama_yapilandirilmadi",
};

/** Ulasmayan / gonderilemeyen durumda yoneticiye gosterilecek aciklama. */
export function teslimAciklamasi(durum: string | null | undefined): SozlukAnahtari | null {
  if (!durum) return null;
  return ACIKLAMA[durum] ?? null;
}
