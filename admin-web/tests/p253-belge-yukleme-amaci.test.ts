// (P253 A2) PDF KABUL EDEN HER YUKLEYICI `amac: "belge"` GONDERIR.
//
// Sunucu (`PresignRequest`) PDF'i yalniz `amac="belge"` ile kabul eder;
// varsayilan `gorsel`. Ayni kusur iki kez olculdu: Ekler (E2E 2026-09) ve
// Dokumanlar (P253 A2 — web'den PDF yukleme 422). Kilit KAYNAKTAN olcer:
// dosya secicisi PDF kabul eden bir dosyada presign istegi belge amacini
// tasimali.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

const KOK = join(__dirname, "..");

/** Yorumlar atilir: aciklama metninde gecen `amac: "belge"` kodu temsil etmez. */
function kod(f: string): string {
  return readFileSync(join(KOK, f), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|\s)\/\/.*$/gm, "$1");
}

function dosyalar(d: string): string[] {
  const out: string[] = [];
  for (const ad of readdirSync(join(KOK, d))) {
    const g = `${d}/${ad}`;
    if (statSync(join(KOK, g)).isDirectory()) {
      if (ad === "api") continue;
      out.push(...dosyalar(g));
    } else if (/\.tsx?$/.test(ad)) out.push(g);
  }
  return out;
}

describe("(P253 A2) belge yukleme amaci", () => {
  it("PDF kabul eden ve presign isteyen her dosya amac: \"belge\" gonderir", () => {
    const eksik = [...dosyalar("app"), ...dosyalar("components")].filter((f) => {
      const s = kod(f);
      return /application\/pdf|\.pdf\b/.test(s) && /uploads\/presign/.test(s) && !/amac:\s*"belge"/.test(s);
    });
    expect(eksik).toEqual([]);
  });

  it("olcum bos degil: en az iki belge yukleyicisi taraniyor", () => {
    const belge = [...dosyalar("app"), ...dosyalar("components")].filter((f) => {
      const s = kod(f);
      return /application\/pdf|\.pdf\b/.test(s) && /uploads\/presign/.test(s);
    });
    expect(belge.length).toBeGreaterThanOrEqual(2);
  });
});
