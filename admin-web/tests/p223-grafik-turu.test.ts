// (P223 §4) GRAFIK TURU VERIYE UYGUN SECILIR.
//
// =========================================================================
// KILITLENEN KURAL
// =========================================================================
// "Pasta dilimi: butunun parcalari — ama 6-7 dilimden fazlasinda okunmaz
// olur, o durumda cubuk kullan."
//
// Kural TEK YERDE (`grafikTuruSec`): her cagiranin ayri ayri karar
// vermesi, ayni veriyi iki ekranda iki farkli bicimde gostermek olurdu.
import { describe, expect, it } from "vitest";

import { PASTA_DILIM_SINIRI, grafikTuruSec } from "@/components/ui/grafik";

describe("P223 grafik turu secimi", () => {
  it("AZ DILIMDE pasta", () => {
    expect(grafikTuruSec("otomatik", 1)).toBe("pasta");
    expect(grafikTuruSec("otomatik", PASTA_DILIM_SINIRI)).toBe("pasta");
  });

  it("SINIRI ASINCA cubuga doner — pasta okunmaz olurdu", () => {
    expect(grafikTuruSec("otomatik", PASTA_DILIM_SINIRI + 1)).toBe("cubuk");
    expect(grafikTuruSec("otomatik", 20)).toBe("cubuk");
  });

  it("ACIKCA ISTENEN tur KORUNUR — otomatik onu EZMEZ", () => {
    // Zaman serisi 3 noktaya duserse bile cizgi kalmali: "az veri"
    // pastaya cevirmek, zaman eksenini yok etmek olurdu.
    expect(grafikTuruSec("cizgi", 3)).toBe("cizgi");
    expect(grafikTuruSec("yatay", 4)).toBe("yatay");
    expect(grafikTuruSec("pasta", 30)).toBe("pasta");
  });

  it("SINIR 6 — kullanicinin verdigi kural", () => {
    expect(PASTA_DILIM_SINIRI).toBe(6);
  });
});
