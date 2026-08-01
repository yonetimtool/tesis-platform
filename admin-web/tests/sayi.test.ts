// (P55) Para OLMAYAN sayilar — bicim ve ayristirma.
//
// Kusur olculdu: metrekare sunucudan `120.5` gelir ve panel bunu OLDUGU
// GIBI yaziyordu. Turkce'de nokta BINLIK ayiricidir; ayni tablo parayi
// `1.250,00 ₺` diye yazarken metrekareyi `120.5` yaziyordu — iki farkli
// yazim, ayni satirda.
//
// Daha agiri girdi tarafindaydi: eski `numOrNull`, `Number("120,5")` NaN
// oldugu icin `null` donuyordu ve `null` "alani TEMIZLE" anlamina
// geliyordu. Yani Turkce yazimla metrekare giren kullanici alani
// SESSIZCE SILDIRIYORDU — hata da almiyordu.
import { describe, expect, it } from "vitest";

import { sayiBicimi, sayiCoz } from "@/lib/sayi";

describe("sayiBicimi", () => {
  it("ondalik VIRGULLE, binlik NOKTAYLA yazilir", () => {
    expect(sayiBicimi(120.5)).toBe("120,5");
    expect(sayiBicimi(1250)).toBe("1.250");
    expect(sayiBicimi(1250.75)).toBe("1.250,75");
    expect(sayiBicimi(-3.25)).toBe("-3,25");
  });

  it("sondaki sifirlar ATILIR — olculmemis hassasiyet gosterilmez", () => {
    expect(sayiBicimi(120)).toBe("120");
    expect(sayiBicimi(120.5)).not.toBe("120,50");
  });

  it("bos deger icin yer tutucu doner", () => {
    expect(sayiBicimi(null)).toBe("—");
    expect(sayiBicimi(undefined)).toBe("—");
    expect(sayiBicimi(null, "")).toBe("");
  });

  it("float artigi URETMEZ", () => {
    // `abs - Math.floor(abs)` yaklasimi `120,50000000000001` verirdi.
    expect(sayiBicimi(120.1)).toBe("120,1");
    expect(sayiBicimi(0.3)).toBe("0,3");
  });
});

describe("sayiCoz", () => {
  it("BOS ile GECERSIZ ayrilir (asil kusur buydu)", () => {
    expect(sayiCoz("")).toEqual({ tur: "bos" });
    expect(sayiCoz("   ")).toEqual({ tur: "bos" });
    expect(sayiCoz("abc")).toEqual({ tur: "gecersiz" });
  });

  it("uygulamanin GOSTERDIGI bicimi kabul eder", () => {
    expect(sayiCoz("120,5")).toEqual({ tur: "sayi", deger: 120.5 });
    expect(sayiCoz("1.250")).toEqual({ tur: "sayi", deger: 1250 });
    expect(sayiCoz("1.250,75")).toEqual({ tur: "sayi", deger: 1250.75 });
  });

  it("sayisal klavyeden gelen NOKTA ondaligi da kabul edilir", () => {
    expect(sayiCoz("120.5")).toEqual({ tur: "sayi", deger: 120.5 });
  });

  it("YARIM giris ve ICERIDEKI bosluk reddedilir", () => {
    for (const g of ["120,", ",5", "120.", ".5", "1 2 3"]) {
      expect(sayiCoz(g), g).toEqual({ tur: "gecersiz" });
    }
  });
});
