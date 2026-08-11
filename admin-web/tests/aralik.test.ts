// (P154 / Asama 5) DAIRE ARALIK IFADESI — "3,5,7-12".
//
// Bu ayristirma ARAYUZDE yapilir (bkz. `lib/aralik.ts` modul basligi) ve
// yanlisi PAHALIDIR: kullanici "12 daire sectim" deyip 9'unu islerse,
// toplu degisiklik yanlis dairelere gider ve geri almasi zordur.
import { describe, expect, it } from "vitest";

import { aralikCoz, sayisalKuyruk } from "@/lib/aralik";

const SATIRLAR = [
  { id: "i1", no: "A-1" },
  { id: "i3", no: "A-3" },
  { id: "i5", no: "A-5" },
  { id: "i7", no: "A-7" },
  { id: "i8", no: "A-8" },
  { id: "i12", no: "A-12" },
];

describe("(P154/5) sayisal kuyruk", () => {
  it("onekli numaradan sayiyi cikarir", () => {
    expect(sayisalKuyruk("A-7")).toBe(7);
    expect(sayisalKuyruk("12")).toBe(12);
    expect(sayisalKuyruk("B-101 ")).toBe(101);
  });

  it("sayisal kuyrugu OLMAYAN numara null doner", () => {
    expect(sayisalKuyruk("zemin")).toBeNull();
  });
});

describe("(P154/5) aralik cozumu", () => {
  it("tekil + aralik birlikte calisir (brief'in ornegi)", () => {
    const s = aralikCoz("3,5,7-12", SATIRLAR);
    expect(s.idler).toEqual(["i3", "i5", "i7", "i8", "i12"]);
    expect(s.bulunamayan).toEqual([]);
  });

  it("TAM NUMARA da yazilabilir", () => {
    expect(aralikCoz("A-5", SATIRLAR).idler).toEqual(["i5"]);
  });

  it("TERS ARALIK calisir — niyet belli", () => {
    // "gecersiz" demek, duzeltilecek bir sey olmayan bir hata olurdu.
    expect(aralikCoz("12-7", SATIRLAR).idler).toEqual(["i7", "i8", "i12"]);
  });

  it("ESLESMEYEN parca SESSIZCE DUSMEZ", () => {
    // "12 daire sectim" deyip 9'unu islemek en kotu sonuctur.
    const s = aralikCoz("3,99,200-300", SATIRLAR);
    expect(s.idler).toEqual(["i3"]);
    expect(s.bulunamayan).toEqual(["99", "200-300"]);
  });

  it("AYNI KUYRUK birden fazla satira denk gelirse IKISI de secilir", () => {
    // Suzgec daraltilmadiysa kullanici ikisini de goruyordur.
    const cok = [...SATIRLAR, { id: "b7", no: "B-7" }];
    expect(aralikCoz("7", cok).idler.sort()).toEqual(["b7", "i7"]);
  });

  it("KOPYA uretmez", () => {
    expect(aralikCoz("7,7,7-8", SATIRLAR).idler).toEqual(["i7", "i8"]);
  });

  it("BOS ifade gecersizdir", () => {
    expect(aralikCoz("   ", SATIRLAR).gecersiz).toBe(true);
    expect(aralikCoz("", SATIRLAR).idler).toEqual([]);
  });
});
