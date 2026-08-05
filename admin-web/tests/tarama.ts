// (P136) KAYNAK TARAYICILARININ ORTAK GEZINMESI — vakum yapisal olarak
// imkânsiz.
//
// SORUN (mutasyonla olculdu, varsayim degil): sekiz tarayici testi kendi
// `dosyalar()` kopyasini tasiyordu ve hicbiri "gercekten dosya gordum"u
// olcmuyordu. Gezinme `[]` dondurecek sekilde degistirildiginde SEKIZI DE
// GECTI:
//
//     canli-bolge · erisilebilir-etiket · guvenlik-hijyeni · ham-enum
//     hata-mesaji · koyu-tema · sabit-metin · sessiz-fetch
//
// Bu testlerin hepsi "SU YOK" diyor (`toEqual([])`, `not.toContain`).
// Yokluk iddialari bos kume uzerinde HER ZAMAN dogrudur — yani gezinme bir
// gun bozulursa (dizin yeniden adlandirilir, uzanti suzgeci kayar, bir
// istisna yutulur) sekiz kilit birden HICBIR SEY OLCMEDEN yesil kalir ve
// bunu kimse fark etmez.
//
// Bu oturumda ayni sinif IKI KEZ daha gerceklesti: (1) koyu tema token
// kilidinin regex'i Python kacisi yuzunden backspace karakteri tasiyordu ve
// hicbir sey eslesmiyordu; (2) `goc` kapisinin hata yolu hic surulmemisti
// (P135). Bir olcum aracinin "yesil" demesi, olctugu anlamina gelmez.
//
// COZUM: gezinme TEK YERDE ve BOS SONUC BIR HATADIR. Tarayici yazan kisi
// tabani eklemeyi unutabilir; unutamayacagi sey, aracin kendisinin
// patlamasidir.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

/** Varsayilan uzantilar — sayfalar ve bilesenler. */
const VARSAYILAN_UZANTILAR = [".tsx"];

/**
 * `kokler` altindaki kaynak dosyalari — BOSSA HATA FIRLATIR.
 *
 * Neden `expect` degil `throw`: yardimci, test dosyasindan BAGIMSIZ
 * calismali. `expect` kullanmak tabanin yine cagrilana bagli olmasi
 * demekti; hata firlatmak, cagiran ne yaparsa yapsin kosumu durdurur.
 */
export function taranacakDosyalar(
  kokler: string[],
  uzantilar: string[] = VARSAYILAN_UZANTILAR,
): string[] {
  const cikti: string[] = [];
  const gez = (kok: string) => {
    for (const ad of readdirSync(kok)) {
      const yol = join(kok, ad);
      if (statSync(yol).isDirectory()) gez(yol);
      else if (uzantilar.some((u) => ad.endsWith(u))) cikti.push(yol);
    }
  };
  for (const k of kokler) gez(k);

  if (cikti.length === 0) {
    throw new Error(
      `TARAMA BOS DONDU (${kokler.join(", ")}) — bu bir kilit arizasidir. ` +
        "Yokluk iddialari bos kume uzerinde her zaman dogrudur; tarayici " +
        "hicbir sey olcmeden yesil kalirdi. Dizin adi ya da uzanti suzgeci " +
        "degismis olabilir.",
    );
  }
  return cikti;
}

/** Taranacak dosyalari `[yol, icerik]` ciftleri olarak dondurur. */
export function taranacakKaynaklar(
  kokler: string[],
  uzantilar: string[] = VARSAYILAN_UZANTILAR,
): [string, string][] {
  return taranacakDosyalar(kokler, uzantilar).map((y) => [
    y,
    readFileSync(y, "utf8"),
  ]);
}
