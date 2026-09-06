/** Dukkan kamu sitesi sabitleri. */
export const SITE_ADRESI =
  process.env.NEXT_PUBLIC_SITE_ADRESI ?? "https://dukkan.yonetiyor.com";
export const SITE_ADI = "Dükkan";

/** (docs/dukkan/05-seo.md §3) INCE ICERIK ESIGI — AYARLANABILIR.
 *
 * Turkiye'de ~45.000 mahalle x ~50 hizmet = 2+ milyon olasi URL. Ezici
 * cogunlugunda tek bir isletme bile yok. Hepsini uretmek, arama motoruna
 * "bu alan adi bos sayfa fabrikasi" demenin en hizli yolu — ve ceza sayfa
 * basina degil ALAN ADI GENELINE isler.
 *
 *   0        -> sayfa YOK (404), sitemap'te yok, ic baglanti yok
 *   1..ESIK-1-> sayfa var ama `noindex`, sitemap'te YOK
 *   >=ESIK   -> tam indekslenir
 *
 * 3 BASLANGIC DEGERI, olculmus bir esik DEGIL. Search Console verisiyle
 * ayarlanacak; bu yuzden ortam degiskeniyle degistirilebilir ve koda
 * gomulu bir sabit degil.
 */
export const INCE_ICERIK_ESIGI = Number(
  process.env.NEXT_PUBLIC_INCE_ICERIK_ESIGI ?? 3,
);
