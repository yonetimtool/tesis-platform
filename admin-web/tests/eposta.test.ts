// (P233 §4) E-POSTA KURALI — mobil ikiziyle AYNI tablo
// (`mobile/test/p233_eposta_test.dart`).
//
// Iki yuzey ayrisirsa kullanici panelde kabul edilen bir adresi mobilde
// reddedilmis gorur.
import { describe, expect, it } from "vitest";

import {
  EPOSTA_SINIR,
  EPOSTA_YEREL_SINIR,
  epostaHatasi,
  epostaNormalle,
} from "@/lib/eposta";

const GECERLI = [
  "ayse@ornek.com",
  "a.b+etiket@alt.ornek.co.uk",
  "AYSE@ORNEK.COM",
  "  bosluklu@ornek.com  ",
];

const BOZUK = [
  "ayse",
  "ayse@",
  "@ornek.com",
  "ayse@ornek",
  "ayse@@ornek.com",
  "ay se@ornek.com",
  "ayse@.com",
  "ayse@ornek.",
  ".ayse@ornek.com",
  "ayse..b@ornek.com",
];

describe("epostaHatasi", () => {
  it("GECERLI adresler -> null", () => {
    for (const e of GECERLI) expect(epostaHatasi(e), e).toBeNull();
  });

  it("BOZUK bicim -> 'bicim'", () => {
    for (const e of BOZUK) expect(epostaHatasi(e), e).toBe("bicim");
  });

  it("BOS: zorunluysa hata, degilse gecerli", () => {
    expect(epostaHatasi("")).toBe("bos");
    expect(epostaHatasi("   ")).toBe("bos");
    expect(epostaHatasi("", false)).toBeNull();
  });

  it("YEREL KISIM 64'u gecemez (RFC 5321)", () => {
    const tam = `${"a".repeat(EPOSTA_YEREL_SINIR)}@ornek.com`;
    const fazla = `${"a".repeat(EPOSTA_YEREL_SINIR + 1)}@ornek.com`;
    expect(epostaHatasi(tam)).toBeNull();
    expect(epostaHatasi(fazla)).toBe("yerelUzun");
  });

  it("TOPLAM 254'u gecemez", () => {
    // Yerel kisim sinirda tutulur ki olculen sey TOPLAM uzunluk olsun.
    const alan = `${"b".repeat(240)}.com`;
    const uzun = `${"a".repeat(10)}@${alan}`;
    expect(uzun.length).toBeGreaterThan(EPOSTA_SINIR);
    expect(epostaHatasi(uzun)).toBe("cokUzun");
  });

  it("UZUNLUK bicimden ONCE sorulur", () => {
    // Cok uzun VE bozuk bir adreste kullanici asil engeli gormeliydi;
    // "bicim gecersiz" deyip uzunlugu gizlemek, adresi duzeltip yine
    // reddedilmesine yol acardi.
    const uzunVeBozuk = "a".repeat(300);
    expect(epostaHatasi(uzunVeBozuk)).toBe("cokUzun");
  });
});

describe("epostaNormalle", () => {
  it("kirpar ve KUCUK HARFE indirir", () => {
    expect(epostaNormalle("  Ayse@Ornek.COM ")).toBe("ayse@ornek.com");
  });
});
