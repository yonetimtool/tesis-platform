// (P136) TARAYICILARIN KENDISI KILITLENDI.
//
// Bu depoda "su yok" diyen bir dizi kaynak tarayicisi var (sabit metin,
// ham enum, sessiz fetch, koyu tema...). Yokluk iddialari BOS KUME
// uzerinde HER ZAMAN dogrudur: gezinme bozulursa tarayici hicbir sey
// olcmeden yesil kalir.
//
// Bu tam olarak olculdu (P136): sekiz tarayicinin gezinmesi `[]`
// dondurecek sekilde degistirildi ve SEKIZI DE GECTI. Cozum ortak
// gezinme (`tarama.ts`) — bos sonuc orada HATA firlatir.
//
// BU DOSYA COZUMUN GERI ALINMAMASINI SAGLAR: biri yeni bir tarayici
// yazip kendi sessiz gezinmesini kopyalarsa burasi duser.
import { readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

import { describe, expect, it } from "vitest";

import { taranacakDosyalar } from "./tarama";

const TESTLER = resolve(__dirname);

const KENDI = "tarayici-kilidi.test.ts";

function testDosyalari(): [string, string][] {
  return readdirSync(TESTLER)
    .filter((a) => a.endsWith(".test.ts"))
    // KENDINI DISLA: bu dosya arayacagi kalibi metin olarak tasiyor ve
    // kendini yakalardi (ilk kosumda tam bunu yapti).
    .filter((a) => a !== KENDI)
    .map((a) => [a, readFileSync(join(TESTLER, a), "utf8")]);
}

describe("(P136) tarayicilar sessizce bosa dusemez", () => {
  it("hicbir test KENDI `dosyalar()` gezinmesini tasimiyor", () => {
    // Kaldirilan kalip: `function dosyalar(kok: string): string[]` —
    // sekiz dosyada AYNEN kopyalanmisti ve hicbirinde taban yoktu.
    const kopyalar = testDosyalari()
      .filter(([, s]) => /function dosyalar\s*\(/.test(s))
      .map(([ad]) => ad);
    expect(
      kopyalar,
      "ortak `taranacakDosyalar` yerine yerel gezinme kopyalanmis",
    ).toEqual([]);
  });

  it("bilinen tarayicilar ORTAK gezinmeyi kullaniyor", () => {
    const TARAYICILAR = [
      "canli-bolge.test.ts",
      "erisilebilir-etiket.test.ts",
      "guvenlik-hijyeni.test.ts",
      "ham-enum.test.ts",
      "hata-mesaji.test.ts",
      "koyu-tema.test.ts",
      "sabit-metin.test.ts",
      "sessiz-fetch.test.ts",
    ];
    const kaynak = new Map(testDosyalari());
    for (const ad of TARAYICILAR) {
      const s = kaynak.get(ad);
      expect(s, `${ad} yok — yeniden adlandirildiysa liste guncellensin`).toBeTruthy();
      expect(s!, ad).toContain("taranacakDosyalar");
    }
  });

  it("ORTAK gezinme bos sonucta HATA firlatiyor", () => {
    // Kilidin kendisi olculur: `tarama.ts` bos kokle cagrilinca patlamali.
    // Gecmeseydi butun kurulum sussuz bir suslemeye donerdi.
    // VAR OLAN bir dizin, ama eslesme uretmeyen bir uzanti suzgeci:
    // "gezinme calisti ama hicbir sey bulamadi" hâli tam olarak budur.
    expect(() => taranacakDosyalar(["app"], [".boyle-bir-uzanti-yok"])).toThrow(
      /TARAMA BOS DONDU/,
    );
  });
});
