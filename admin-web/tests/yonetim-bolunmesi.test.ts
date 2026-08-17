// (P167 §6.1) "YONETISIM" BASLIGININ KALDIRILMASI — KAYIP ISLEV KILIDI.
//
// =========================================================================
// KILITLENEN KUSUR SINIFI
// =========================================================================
// Brief "Yonetisim alt basligi tamamen kaldirilsin" diyor. O sayfanin
// icinde DORT bolum vardi: karar defteri, dokuman arsivi, KVKK aydinlatma
// metni ve gurultu uyarilari.
//
// Basligi silip yerine yalnizca brief'in ADIYLA andigi ikisini (karar
// defteri + dokuman) koymak, KVKK metnini ve gurultu uyarilarini
// SESSIZCE yok etmek olurdu: uclar duruyor, veri duruyor, ama panelde
// ulasilacak hicbir yol yok. Genel kisit acik — "Mevcut islev
// kaybolmayacak."
//
// Bu test o sinifi kilitler: eski sayfanin her bolumunun bugun bir
// menu satiri var mi.
import { describe, expect, it } from "vitest";

import { _OGELER as MENU } from "@/lib/menu";
import { ROTA_ROLLERI, TESIS_ROTALARI, rotaRoldeGorunur } from "@/lib/yuzey";

/** Eski `/yonetisim` sayfasinin dort bolumu -> bugunku rotasi. */
const ESKI_BOLUMLER: Record<string, string> = {
  kararDefteri: "/karar-defteri",
  dokumanArsivi: "/dokumanlar",
  kvkkMetni: "/kvkk-metinler",
  gurultuUyarilari: "/gurultu-uyarilari",
};

describe("(P167 §6.1) Yonetisim basligi kaldirildi", () => {
  it("`/yonetisim` menude ARTIK YOK", () => {
    expect(MENU.some((o) => o.href === "/yonetisim")).toBe(false);
  });

  it("`/yonetisim` yuzey haritasindan da CIKTI", () => {
    // Menuden cikarip yuzey haritasinda birakmak, kapisi olan ama
    // kapisina goturen yol olmayan bir sayfa birakirdi.
    expect(TESIS_ROTALARI).not.toContain("/yonetisim");
    expect(ROTA_ROLLERI["/yonetisim"]).toBeUndefined();
  });

  it("ESKI SAYFANIN DORT BOLUMU DE bugun bir menu satiri", () => {
    for (const [ad, rota] of Object.entries(ESKI_BOLUMLER)) {
      expect(MENU.some((o) => o.href === rota), ad).toBe(true);
    }
  });

  it("dordu de YONETIM grubunda ve ayni rolde", () => {
    for (const [ad, rota] of Object.entries(ESKI_BOLUMLER)) {
      const oge = MENU.find((o) => o.href === rota)!;
      expect(oge.grup, ad).toBe("yonetim");
      // Eski `/yonetisim` admin+yonetici idi; bolunme YETKI DEGISTIRMEZ.
      // Bolerken yanlislikla genisletmek, KVKK metnini yayinlama
      // yetkisini baska bir role acmak olurdu.
      expect(ROTA_ROLLERI[rota], ad).toEqual(["admin", "yonetici"]);
    }
  });

  it("SAHA ROLLERINE kapali kaldi", () => {
    for (const rota of Object.values(ESKI_BOLUMLER)) {
      for (const rol of ["security", "tesis_gorevlisi", "resident"] as const) {
        expect(rotaRoldeGorunur(rota, rol), `${rota}/${rol}`).toBe(false);
      }
    }
  });

  it("KVKK METNI ile `/kvkk` AYRI satirlar", () => {
    // Biri tesisin YAYINLADIGI aydinlatma metni, oteki kullanicinin KENDI
    // pazarlama tercihi. Ayni satira koymak ikisini karistirmak olurdu.
    expect(MENU.some((o) => o.href === "/kvkk")).toBe(true);
    expect(MENU.some((o) => o.href === "/kvkk-metinler")).toBe(true);
  });
});
