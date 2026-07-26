// Para = KURUS (integer). Bu dosyanin isi: TL<->kurus donusumunun TAM SAYI
// aritmetigiyle yapildigini ve gecersiz girdinin SESSIZCE 0'a donmedigini
// (null dondugunu) kilitlemek. Aidat tutarlari buradan geciyor; kayan nokta
// hatasi para hatasidir.
import { describe, expect, it } from "vitest";

import { kurusToTL, tlToKurus } from "@/lib/money";

describe("tlToKurus", () => {
  it("tam lira: kurus kismi 00 ile doldurulur", () => {
    expect(tlToKurus("750")).toBe(75000);
    expect(tlToKurus("0")).toBe(0);
  });

  it("virgul VE nokta ayirici kabul edilir (klavye farki)", () => {
    expect(tlToKurus("750,50")).toBe(75050);
    expect(tlToKurus("750.50")).toBe(75050);
  });

  it("tek haneli kurus 10'luk olarak yorumlanir (750,5 = 750,50)", () => {
    expect(tlToKurus("750,5")).toBe(75050);
    expect(tlToKurus("0,5")).toBe(50);
  });

  it("bastaki/sondaki bosluk kirpilir", () => {
    expect(tlToKurus("  750,50  ")).toBe(75050);
  });

  it("GECERSIZ girdi null doner — 0 DEGIL (sessiz sifir tutar yazamaz)", () => {
    for (const v of [
      "",
      "   ",
      "abc",
      "750,555", // 2'den fazla kurus hanesi
      "750,",
      ",50",
      "-750", // negatif tutar girisi yok (iade ayri akis)
      "1 000",
      "1.000,50", // binlik ayirici DESTEKLENMEZ (belirsiz)
      "7e2",
      "+750",
    ]) {
      expect(tlToKurus(v), `girdi: "${v}"`).toBeNull();
    }
  });

  it("float hatasi YOK: 0.07 gibi degerler tam sayiya oturur", () => {
    // 0.07 * 100 = 7.000000000000001 (IEEE754). Integer aritmetigi bunu elemeli.
    expect(tlToKurus("0,07")).toBe(7);
    expect(Number.isInteger(tlToKurus("1234,56"))).toBe(true);
    expect(tlToKurus("1234,56")).toBe(123456);
  });
});

describe("kurusToTL", () => {
  it("binlik ayirici tr-TR (nokta) + iki haneli kurus + simge", () => {
    expect(kurusToTL(75000)).toBe("750,00 ₺");
    expect(kurusToTL(123456)).toBe("1.234,56 ₺");
    expect(kurusToTL(100000000)).toBe("1.000.000,00 ₺");
  });

  it("kurus tek haneliyken solu sifirla doldurur", () => {
    expect(kurusToTL(7)).toBe("0,07 ₺");
    expect(kurusToTL(70)).toBe("0,70 ₺");
  });

  it("sifir ve negatif (bakiye/iade) dogru bicimlenir", () => {
    expect(kurusToTL(0)).toBe("0,00 ₺");
    expect(kurusToTL(-75050)).toBe("-750,50 ₺");
    expect(kurusToTL(-7)).toBe("-0,07 ₺");
  });
});

describe("gidis-donus (round-trip)", () => {
  it("kurus -> TL -> kurus AYNI degeri verir", () => {
    for (const kurus of [0, 1, 7, 99, 100, 75050, 123456, 999999999]) {
      const metin = kurusToTL(kurus)
        .replace(" ₺", "")
        .replace(/\./g, ""); // binlik ayiricilari at, virgul kalir
      expect(tlToKurus(metin), `kurus: ${kurus}`).toBe(kurus);
    }
  });
});
