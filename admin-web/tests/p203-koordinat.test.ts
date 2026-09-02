// (P203 §1) KOORDINAT AYRISTIRMA — NFC noktasi 500'unun kok nedeni.
//
// =========================================================================
// OLCULEN KUSUR
// =========================================================================
// `PATCH /api/checkpoints/{id}` koordinat girilince **500** donuyordu.
// Sebep sunucuda degil BURADAYDI: form `sayiCoz` kullaniyordu ve
// `sayiCoz` bir PARA ayristiricisidir — noktadan sonra 2'den fazla
// basamak varsa noktayi BINLIK AYRACI sayip SILER.
//
//     sayiCoz("41.008238") -> 41008238        (olculdu)
//
// Sunucudaki sutun `Numeric(9, 6)`; 41008238 tasti ve yakalanmamis bir
// istisna 500 uretti.
import { describe, expect, it } from "vitest";

import { koordinatBoylamCoz, koordinatEnlemCoz, sayiCoz } from "@/lib/sayi";

describe("kusurun kendisi kayit altinda", () => {
  it("PARA ayristiricisi koordinati BOZAR — bu yuzden ayri bir tane var", () => {
    // Bu test `sayiCoz`u SUCLAMAZ: para icin davranisi DOGRUDUR
    // ("1.234" bin iki yuz otuz dorttur). Kayit altina aldigi sey,
    // birinin bir gun koordinati yine ona vermesinin NEDEN yanlis
    // olacagi.
    expect(sayiCoz("41.008238")).toEqual({ tur: "sayi", deger: 41008238 });
    expect(koordinatEnlemCoz("41.008238")).toEqual({
      tur: "sayi",
      deger: 41.008238,
    });
  });
});

describe("iki ayirac da ONDALIKTIR", () => {
  // Koordinatin binlik ayraci YOKTUR (enlem <= 90, boylam <= 180), o
  // yuzden nokta da virgul de ondalik demektir. Kullanici haritadan
  // kopyaladigini yapistirir; hangi ayraci kullandigi onemli olmamali.
  const esdeger: [string, string, number][] = [
    ["41.008238", "41,008238", 41.008238],
    ["-41.008238", "-41,008238", -41.008238],
    ["0.5", "0,5", 0.5],
    ["41", "41", 41],
  ];
  for (const [nokta, virgul, beklenen] of esdeger) {
    it(`${nokta} == ${virgul} == ${beklenen}`, () => {
      expect(koordinatEnlemCoz(nokta)).toEqual({ tur: "sayi", deger: beklenen });
      expect(koordinatEnlemCoz(virgul)).toEqual({ tur: "sayi", deger: beklenen });
    });
  }
});

describe("sinirlar", () => {
  it("enlem -90..90 KABUL, disi RED", () => {
    for (const g of ["90", "-90", "89.999999", "0"]) {
      expect(koordinatEnlemCoz(g).tur, g).toBe("sayi");
    }
    for (const g of ["90.000001", "-90.1", "91", "1234.5"]) {
      expect(koordinatEnlemCoz(g).tur, g).toBe("gecersiz");
    }
  });

  it("boylam -180..180 KABUL, disi RED", () => {
    for (const g of ["180", "-180", "179.999", "0"]) {
      expect(koordinatBoylamCoz(g).tur, g).toBe("sayi");
    }
    for (const g of ["180.1", "-181", "5678.9"]) {
      expect(koordinatBoylamCoz(g).tur, g).toBe("gecersiz");
    }
  });

  it("enlem sinirinda gecerli olan bir deger BOYLAMDA da gecerli", () => {
    // Ters yon: 100 enlem DEGIL ama boylam OLABILIR. Iki sinirin
    // karistirilmasi, gecerli bir boylami reddetmek olurdu.
    expect(koordinatEnlemCoz("100").tur).toBe("gecersiz");
    expect(koordinatBoylamCoz("100").tur).toBe("sayi");
  });
});

describe("bos ve gecersiz AYRI", () => {
  it("BOS koordinat silme niyetidir, hata DEGIL", () => {
    // Ikisini birlestirmek, alani temizleyen kullaniciya hata
    // gostermek ya da (kotusu) gecersiz girisi sessizce silmek olurdu.
    expect(koordinatEnlemCoz("")).toEqual({ tur: "bos" });
    expect(koordinatEnlemCoz("   ")).toEqual({ tur: "bos" });
  });

  for (const g of ["abc", "41.", ".5", "41..5", "4 1", "1.234,5", "41,008.238", "--41"]) {
    it(`"${g}" GECERSIZ`, () => {
      expect(koordinatEnlemCoz(g).tur).toBe("gecersiz");
    });
  }

  it("GRUPLANMIS yazim SESSIZCE yorumlanmaz", () => {
    // "1.234,5" para yazimidir. Koordinat sanip 1234.5 uretmek,
    // kullanicinin yanlis bir noktayi kaydetmesi olurdu — tam da
    // 500'e goturen sinif.
    expect(koordinatEnlemCoz("1.234,5").tur).toBe("gecersiz");
  });
});
