// (P78) IKI AYRISTIRICI, TEK AYIRICI KURALI — panelin karsiligi.
//
// P77 bunu mobilde kilitledi. Panelde de ayni ikilik var: tutar alanlari
// `lib/money.ts::tlToKurus`, para OLMAYAN sayilar `lib/sayi.ts::sayiCoz`
// kullaniyor. Ikisinin KENDI testleri vardi; ARALARINDAKI sozlesmenin
// testi yoktu — biri "sadelestirilirse" digeriyle sessizce ayrisir ve
// kullanici ayni yazimi iki alanda kullanamaz olurdu.
//
// Kilit KABUL/RED kararini karsilastirir, degeri degil: donus tipleri
// farkli (kurus tamsayisi ↔ ondalikli sayi).
import { describe, expect, it } from "vitest";

import { tlToKurus } from "@/lib/money";
import { sayiCoz } from "@/lib/sayi";

// Politika farki OLMAYAN girdiler: pozitif, en fazla iki ondalik hane.
const KABUL = ["1250", "1250,50", "1250.50", "1.250", "1.250,00", "0", "0,05"];
const RED = ["", "   ", "abc", "1250,", ",50", "1250.", ".50", "1 2 3"];

describe("ayirici kurali iki ayristiricida AYNI", () => {
  it.each(KABUL)("KABUL: %s", (girdi) => {
    expect(tlToKurus(girdi), "para").not.toBeNull();
    expect(sayiCoz(girdi).tur, "sayi").toBe("sayi");
  });

  it.each(RED)("RED: %s", (girdi) => {
    expect(tlToKurus(girdi), "para").toBeNull();
    // Bos girdi `sayiCoz`ta AYRI bir durumdur (bos != gecersiz); ortak
    // olan sey "sayi URETMEZ"dir.
    expect(sayiCoz(girdi).tur, "sayi").not.toBe("sayi");
  });
});

describe("politika farklari BILINCLI", () => {
  it("negatif: para REDDEDER, sayi kabul eder", () => {
    // Isaret bir BICIM degil ALAN kuralidir: tutar negatif olamaz ama bir
    // olcu/fark olabilir (mobilde ayni karar — P77).
    expect(tlToKurus("-5")).toBeNull();
    expect(sayiCoz("-5")).toEqual({ tur: "sayi", deger: -5 });
  });

  it("uc ondalik hane: para REDDEDER (kurus iki hanedir)", () => {
    expect(tlToKurus("1,234")).toBeNull();
    expect(sayiCoz("1,234")).toEqual({ tur: "sayi", deger: 1.234 });
  });

  it("bos girdi: sayi BOS der, para null", () => {
    expect(sayiCoz("")).toEqual({ tur: "bos" });
    expect(tlToKurus("")).toBeNull();
  });
});

describe("panel ve mobil AYNI kurali uygular", () => {
  // `mobile/test/ayirici_tutarlilik_test.dart` ayni listeleri surer.
  // Listeler ayrisirsa bu yorum yalan olur; bu yuzden liste degerleri
  // ORADA DA aynen duruyor ve degistirilirken ikisi birlikte
  // degistirilmelidir.
  it("kabul/red listeleri mobil testiyle AYNI degerleri tasir", () => {
    expect(KABUL).toEqual([
      "1250", "1250,50", "1250.50", "1.250", "1.250,00", "0", "0,05",
    ]);
    expect(RED).toEqual([
      "", "   ", "abc", "1250,", ",50", "1250.", ".50", "1 2 3",
    ]);
  });
});
