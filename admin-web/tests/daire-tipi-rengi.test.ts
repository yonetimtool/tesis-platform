// (P122) TIP RENGI — panel ile mobilin AYNI rengi uretmesi kilidi.
//
// NEDEN KILIT: ayni daire tipi iki yuzeyde AYNI rengi almalidir. Yonetici
// panelde bakip mobilde dogruluyor; renk ayrisirsa iki ekrandan biri
// "yanlis" gorunur ve guven kaybi teknik bir hatadan pahaliya patlar.
// Iki ayri dilde yazilmis iki fonksiyonun ayni kalmasini ancak PAYLASILAN
// bir beklenen-deger tablosu garanti eder: asagidaki tablonun AYNISI
// `mobile/test/daire_tipi_rengi_test.dart` icinde de vardir. Biri
// degistirilirse o taraf duser.
import { describe, expect, it } from "vitest";

import {
  DAIRE_TIPI_PALETI,
  daireTipiKisa,
  daireTipiRengi,
} from "@/lib/daire-tipi-rengi";

/** PAYLASILAN TABLO — mobil testiyle BIREBIR ayni. */
const BEKLENEN: Record<string, string> = {
  "2+1": "#3949AB",
  "3+1": "#00897B",
  "1+1": "#5D4037",
  "4+1": "#8E24AA",
  Dubleks: "#8E24AA",
  Dükkan: "#00838F",
  Villa: "#C62828",
  Stüdyo: "#5D4037",
  "Bahçe Katı": "#43A047",
  "Çatı Katı": "#43A047",
};

describe("daireTipiRengi", () => {
  it("PAYLASILAN TABLOYU birebir uretir (mobil ile ayni)", () => {
    for (const [ad, renk] of Object.entries(BEKLENEN)) {
      expect(daireTipiRengi(ad), `tip: ${ad}`).toBe(renk);
    }
  });

  it("BOS/tanimsiz -> varsayilan indigo", () => {
    expect(daireTipiRengi(null)).toBe(DAIRE_TIPI_PALETI[0]);
    expect(daireTipiRengi(undefined)).toBe(DAIRE_TIPI_PALETI[0]);
    expect(daireTipiRengi("   ")).toBe(DAIRE_TIPI_PALETI[0]);
  });

  it("BUYUK/kucuk harf ve bosluk FARK ETMEZ", () => {
    expect(daireTipiRengi(" 2+1 ")).toBe(daireTipiRengi("2+1"));
    expect(daireTipiRengi("DUBLEKS")).toBe(daireTipiRengi("dubleks"));
  });

  it("KARARLI: ayni ad her cagride ayni rengi verir", () => {
    const bir = daireTipiRengi("Bahçe Katı");
    for (let i = 0; i < 50; i++) expect(daireTipiRengi("Bahçe Katı")).toBe(bir);
  });

  it("palet DISINA cikmaz", () => {
    for (const ad of ["a", "bb", "ccc", "çç", "🏠 Daire", "x".repeat(200)]) {
      expect(DAIRE_TIPI_PALETI).toContain(daireTipiRengi(ad));
    }
  });
});

describe("daireTipiKisa", () => {
  it("KISA ad oldugu gibi kalir", () => {
    expect(daireTipiKisa("2+1")).toBe("2+1");
    expect(daireTipiKisa("Dubleks")).toBe("Dubleks");
  });

  it("UZUN ad kirpilir; SONUC sinir kadar uzun olur", () => {
    // Sinir SONUCUN uzunlugudur (nokta dahil), kirpma noktasi degil:
    // 7 sinirinda "Dublek" + "…" = 7 karakter. Ilk yazimda beklenti
    // "Dubleks…" (8) idi ve test dustu — hucre genisligi hesabi sonucun
    // uzunluguna gore yapildigi icin dogru olan kodun davranisi.
    expect(daireTipiKisa("Dubleks Bahçe Katı")).toBe("Dublek…");
    expect([...daireTipiKisa("Dubleks Bahçe Katı")]).toHaveLength(7);
  });

  it("EMOJI/birlesik karakter ORTADAN BOLUNMEZ", () => {
    // `slice` kod BIRIMIYLE calissaydi vekil cifti yarilanir ve ekranda
    // bozuk karakter cikardi.
    const k = daireTipiKisa("🏠🏠🏠🏠🏠🏠🏠🏠🏠");
    expect([...k]).toHaveLength(7);
    expect(k.endsWith("…")).toBe(true);
  });

  it("BOS ad bos doner", () => {
    expect(daireTipiKisa(null)).toBe("");
    expect(daireTipiKisa("  ")).toBe("");
  });
});
