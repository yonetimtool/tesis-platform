// (P220 §4) SAKINLER BLOKLARA GORE GRUPLANIR — web tarafi.
//
// Mobildeki `bloklaraGore` ile AYNI kurallari olcuyor: bloklar
// alfabetik, BLOKSUZLAR EN SONDA ve GIZLENMEZ. Iki yuzeyin ayni listeyi
// farkli siralamasi, yoneticinin hangisine bakacagini bilememesi
// olurdu.
import { describe, expect, it } from "vitest";

import { bloklaraGore } from "@/lib/sakin-gruplama";
import type { ResidentListItem } from "@/lib/types";

function uye(
  ad: string,
  blok: string | null = null,
  unitNo: string | null = null,
): ResidentListItem {
  return { user_id: `u-${ad}`, ad, blok, unit_no: unitNo, is_active: true };
}

describe("(P220 §4) bloklaraGore", () => {
  it("BLOKLAR ALFABETIK, BLOKSUZ EN SONDA", () => {
    const gruplar = bloklaraGore([
      uye("Zeynep", "B"),
      uye("Dairesiz"),
      uye("Ayse", "A"),
      uye("Mehmet", "A"),
    ]);
    expect(gruplar.map((g) => g.blok)).toEqual(["A", "B", null]);
    expect(gruplar[0].sakinler.map((s) => s.ad)).toEqual(["Ayse", "Mehmet"]);
  });

  it("BLOKSUZ SAKIN GIZLENMEZ", () => {
    // Gizlemek, siteden ayrilmis ama hesabi duran bir sakini BULUNAMAZ
    // yapardi — sayfanin varlik sebebi tam olarak onu bulup silmek.
    const gruplar = bloklaraGore([uye("Dairesiz")]);
    expect(gruplar).toHaveLength(1);
    expect(gruplar[0].blok).toBeNull();
    expect(gruplar[0].sakinler[0].ad).toBe("Dairesiz");
  });

  it("TURKCE SIRALAMA: C ve S dogru yere duser", () => {
    // `sort()` varsayilani kod noktasina gore siralar ve `C` ile `S`
    // alfabenin SONUNA duserdi. `localeCompare(_, "tr")" gerekli.
    const gruplar = bloklaraGore([
      uye("a", "D"),
      uye("b", "Ç"),
      uye("c", "C"),
      uye("d", "Ş"),
      uye("e", "S"),
    ]);
    expect(gruplar.map((g) => g.blok)).toEqual(["C", "Ç", "D", "S", "Ş"]);
  });

  it("BOS LISTE BOS GRUP", () => {
    expect(bloklaraGore([])).toEqual([]);
  });

  it("AYNI BLOKTA IKI DAIRESI OLAN SAKIN TEK GRUPTA", () => {
    // Sunucu `string_agg(DISTINCT ...)` ile tek blok adi donuyor.
    const gruplar = bloklaraGore([uye("Ali", "A", "A-1, A-2")]);
    expect(gruplar).toHaveLength(1);
    expect(gruplar[0].blok).toBe("A");
  });
});
