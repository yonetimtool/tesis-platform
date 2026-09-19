// (P243 §6c) BOS DURUM MESAJLARI REHBER OLMALI.
//
// =========================================================================
// OLCULEN SEY
// =========================================================================
// Brief: "Boş liste ekranlarında 'Kayıt yok' yerine ne yapması
// gerektiğini söyleyen mesaj olsun. TÜM boş ekranları tara ve düzelt."
//
// Tarama yapildi: panelde 58 `BosDurum` kullanimi vardi ve 42'sinde
// YALNIZCA BASLIK vardi — yani ekran "Kayit yok" deyip susuyordu.
// Yeni bir tesiste bu ekranlarin cogu BOS ACILIR; kullanicinin ilk
// sorusu "bozuk mu, ben mi yapmadim" olur ve baslik bunu yanitlamaz.
//
// =========================================================================
// NEDEN METIN TARAMASI, DOM TESTI DEGIL
// =========================================================================
// 42 ekrani tek tek cizen 42 test yazmak ayni kurali 42 kez tekrar
// etmek olurdu ve YENI eklenen bir ekrani yine kacirirdi. Kural
// YAPISALDIR: "her `BosDurum` bir `aciklama` alir". Tarama, bugun
// yazilmamis bir ekrani da yarin yakalar.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

function tsxDosyalari(dizin: string, biriktir: string[] = []): string[] {
  for (const ad of readdirSync(dizin)) {
    if (ad === "node_modules" || ad === ".next") continue;
    const yol = join(dizin, ad);
    if (statSync(yol).isDirectory()) tsxDosyalari(yol, biriktir);
    else if (ad.endsWith(".tsx")) biriktir.push(yol);
  }
  return biriktir;
}

/** `<BosDurum ...>` acilis etiketlerini (suslu parantezleri sayarak) ayikla. */
function bosDurumEtiketleri(kaynak: string): string[] {
  const etiketler: string[] = [];
  const desen = /<BosDurum\b/g;
  let eslesme: RegExpExecArray | null;
  while ((eslesme = desen.exec(kaynak)) !== null) {
    let i = eslesme.index;
    let derinlik = 0;
    while (i < kaynak.length) {
      const c = kaynak[i];
      if (c === "{") derinlik += 1;
      else if (c === "}") derinlik -= 1;
      else if (c === ">" && derinlik === 0) break;
      i += 1;
    }
    etiketler.push(kaynak.slice(eslesme.index, i + 1));
  }
  return etiketler;
}

describe("(P243 §6c) bos durum rehberi", () => {
  it("HER BosDurum bir `aciklama` tasir", () => {
    const suclular: string[] = [];
    for (const yol of [
      ...tsxDosyalari(join(KOK, "app")),
      ...tsxDosyalari(join(KOK, "components")),
    ]) {
      const kaynak = readFileSync(yol, "utf8");
      for (const etiket of bosDurumEtiketleri(kaynak)) {
        // Bilesenin KENDI tanimi haric (orada `aciklama` bir prop).
        if (yol.endsWith("durumlar.tsx")) continue;
        if (!/\baciklama=/.test(etiket)) {
          suclular.push(`${yol.slice(KOK.length + 1)} :: ${etiket.slice(0, 80)}`);
        }
      }
    }
    expect(suclular).toEqual([]);
  });

  it("TARAMA GERCEKTEN CALISIYOR (kilit kendini olcer)", () => {
    // Bir kilit, kirilmadigi surece gecerli sayilmaz. Burada sahte bir
    // kaynak uzerinde taranir: desen `aciklama`siz etiketi gorebiliyor
    // mu, ve suslu parantez icindeki `>` karakterini yutmuyor mu?
    const sahte = `
      <BosDurum baslik={t("a")} />
      <BosDurum baslik={n > 0 ? t("b") : t("c")} aciklama={t("d")} />
    `;
    const etiketler = bosDurumEtiketleri(sahte);
    expect(etiketler).toHaveLength(2);
    expect(etiketler.filter((e) => !/\baciklama=/.test(e))).toHaveLength(1);
  });
});
