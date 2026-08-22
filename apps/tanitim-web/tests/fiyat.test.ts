import { describe, expect, it } from "vitest";

import {
  DAIRE_EN_AZ,
  DAIRE_EN_COK,
  DAIRE_VARSAYILAN,
  KDV_UYARISI,
  sinirla,
  tutarBicimle,
  yillikTutar,
} from "@/config/fiyat";

// (P177 §9.4) KABUL KRITERI: "50 daire -> 5.000 TL, altinda
// 'Fiyatlarımıza KDV dahil değildir.'"
describe("fiyat hesaplayici", () => {
  it("kabul kriteri: 50 daire -> 5.000", () => {
    expect(yillikTutar(50)).toBe(5000);
    expect(tutarBicimle(yillikTutar(50))).toBe("5.000 ₺");
  });

  it("KDV uyarisi BIREBIR sartnamedeki cumle", () => {
    expect(KDV_UYARISI).toBe("Fiyatlarımıza KDV dahil değildir.");
  });

  it("varsayilan 50, aralik 1-500", () => {
    expect(DAIRE_VARSAYILAN).toBe(50);
    expect(DAIRE_EN_AZ).toBe(1);
    expect(DAIRE_EN_COK).toBe(500);
  });

  it("kademe YOK — tutar dogrusal", () => {
    // Iki uctaki birim fiyat AYNI olmali; kademe eklenirse bu duser.
    expect(yillikTutar(1) / 1).toBe(yillikTutar(500) / 500);
  });

  it("sinir disi girdi sinirlanir (elle 9999 yazan kullanici)", () => {
    expect(sinirla(9999)).toBe(500);
    expect(sinirla(0)).toBe(1);
    expect(sinirla(-40)).toBe(1);
    expect(yillikTutar(9999)).toBe(50_000);
  });

  it("bozuk girdi varsayilana duser, NaN uretmez", () => {
    expect(sinirla(Number.NaN)).toBe(DAIRE_VARSAYILAN);
    expect(Number.isFinite(yillikTutar(Number.NaN))).toBe(true);
  });

  it("uc rakamli ayrac Turkce", () => {
    expect(tutarBicimle(50000)).toBe("50.000 ₺");
  });
});
