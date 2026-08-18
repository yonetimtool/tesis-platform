// (P168 §4) ETIKET KUMESI — ISTEMCI ILE SUNUCUNUN ESITLIGI.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI
// =========================================================================
// Cipler kullanicinin metnine `{bakiye}` gibi bir etiket yazar; sunucu
// gonderim aninda onu gercek veriyle degistirir.
//
// Istemcide OLUP sunucuda OLMAYAN bir etiket, mesajda HAM olarak
// KALIRDI — ve bu sessiz olurdu: sunucu bilmedigi etiketi BILEREK
// koruyor (bos birakmak yazim hatasini gizlerdi), yani sakine giden
// SMS'te "{bakiyem}" yaziyor olurdu.
//
// Tersi de kotu: sunucuda olup cipte olmayan bir etiket, kullanicinin
// ELLE yazmasi gereken gizli bir ozelliktir.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { ETIKETLER } from "@/components/mesaj/etiket-cipleri";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CEKIRDEK = join(KOK, "backend", "app", "mesajlasma.py");

/** Backend'in `ETIKETLER` demetini okur. */
function sunucuEtiketleri(): string[] {
  const kaynak = readFileSync(CEKIRDEK, "utf8");
  const m = /^ETIKETLER = \(([\s\S]*?)\)$/m.exec(kaynak);
  if (!m) throw new Error("backend ETIKETLER demeti bulunamadi");
  return [...m[1].matchAll(/"([a-z_]+)"/g)].map((x) => x[1]);
}

describe("(P168 §4) etiket kumesi", () => {
  it("olcum BOSA DUSMUYOR — sunucu kumesi okunabiliyor", () => {
    expect(sunucuEtiketleri().length).toBeGreaterThan(5);
  });

  it("CIPTEKI her etiket SUNUCUDA da VAR", () => {
    // Bu yon daha pahali: eksigi, sakine giden mesajda HAM etiket
    // birakirdi.
    const sunucu = new Set(sunucuEtiketleri());
    const eksik = ETIKETLER.map((e) => e.ad).filter((a) => !sunucu.has(a));
    expect(eksik).toEqual([]);
  });

  it("BRIEF'IN ON ETIKETI cipte VAR", () => {
    const cip = new Set(ETIKETLER.map((e) => e.ad));
    for (const ad of [
      "bakiye", "borc", "adi_soyadi", "adres", "tarih", "odeme_linki",
      "site_adi", "aidat_tutari", "kiraci_bakiyesi", "bakiye_detayli",
    ]) {
      expect(cip.has(ad), ad).toBe(true);
    }
  });

  it("cipler `{ad}` bicimini uretir", () => {
    // Sunucunun deseni `\{([a-z_]+)\}`; sussuz gonderilen bir ad hicbir
    // seyle eslesmezdi.
    const eklenen: string[] = [];
    ETIKETLER.forEach((e) => eklenen.push(`{${e.ad}}`));
    expect(eklenen.every((x) => /^\{[a-z_]+\}$/.test(x))).toBe(true);
  });
});
