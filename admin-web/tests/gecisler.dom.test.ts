// @vitest-environment jsdom
// (P161 §3) GECISLER — davranis + hareket-azaltma kilidi.
//
// Brief'in gecis maddeleri "guzel gorunsun" degil, OLCULEBILIR kurallar:
//
//   * tablo satirlari 30 ms arayla girer,
//   * MALI TUTARLAR SAYARAK GELMEZ (gercek olmayan bakiye gosterilmez),
//   * tiklanabilir kart hover'da yukselir,
//   * `prefers-reduced-motion` acikken HICBIRI calismaz.
//
// Sonuncusu en kolay unutulan: her yeni gecis kendi kosulunu yazmak
// zorunda kalirsa biri mutlaka atlanir. Bu yuzden kural CSS'te TEK bir
// blokta duruyor ve burada KAYNAK TARAMASIYLA kilitleniyor.
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { screen } from "@testing-library/react";
import { createElement } from "react";
import { describe, expect, it } from "vitest";

import { Kart, Kpi, VeriTablosu, type Kolon } from "@/components/ui";
import { SIRA_GECIKMESI, SIRA_TAVANI, siraGecikmesi } from "@/lib/hareket";

import { ciz } from "./yardimci";

describe("siraGecikmesi", () => {
  it("30 ms adimlarla ilerler", () => {
    expect(siraGecikmesi(0, true)).toBe(0);
    expect(siraGecikmesi(1, true)).toBeCloseTo(SIRA_GECIKMESI, 6);
    expect(siraGecikmesi(5, true)).toBeCloseTo(5 * SIRA_GECIKMESI, 6);
  });

  it("TAVANI VAR — uzun tabloda son satir dakikalarca beklemez", () => {
    const tavan = SIRA_TAVANI * SIRA_GECIKMESI;
    expect(siraGecikmesi(SIRA_TAVANI + 40, true)).toBeCloseTo(tavan, 6);
    // 25 satirlik bir tabloda toplam gecikme yarim saniyeyi asmamali.
    expect(tavan).toBeLessThanOrEqual(0.5);
  });

  it("hareket kapaliyken SIFIR", () => {
    expect(siraGecikmesi(9, false)).toBe(0);
  });
});

interface Satir {
  id: string;
  ad: string;
}

describe("VeriTablosu — sirali giris", () => {
  const satirlar: Satir[] = [
    { id: "a", ad: "Bir" },
    { id: "b", ad: "Iki" },
    { id: "c", ad: "Uc" },
  ];
  const kolonlar: Kolon<Satir>[] = [
    { id: "ad", baslik: "Ad", hucre: (s) => s.ad },
  ];

  it("her satir giris sinifini ve ARTAN gecikmeyi tasir", () => {
    ciz(() =>
      createElement(VeriTablosu<Satir>, {
        satirlar,
        kolonlar,
        satirId: (s) => s.id,
      }),
    );
    const trler = screen
      .getAllByRole("row")
      .filter((r) => r.classList.contains("yz-satir-giris"));
    expect(trler).toHaveLength(3);
    const gecikmeler = trler.map((r) => parseFloat(r.style.animationDelay));
    expect(gecikmeler[0]).toBe(0);
    expect(gecikmeler[1]).toBeGreaterThan(gecikmeler[0]);
    expect(gecikmeler[2]).toBeGreaterThan(gecikmeler[1]);
  });
});

describe("Kpi — MALI TUTAR SAYMAZ", () => {
  it("para isaretliyken deger ILK KAREDE tamdir", () => {
    ciz(() =>
      createElement(Kpi, {
        deger: 12400,
        para: true,
        etiket: "Bakiye",
        bicimle: (n: number) => `${n} TL`,
      }),
    );
    // `Kpi` degeri IKI KEZ yazar: gorsel rakam (`aria-hidden`) ve ekran
    // okuyucu icin tek parca metin. Ikisi de tam deger olmali.
    expect(screen.getAllByText(/12400 TL/).length).toBeGreaterThan(0);
    // Sayan bir deger ilk karede 0 olurdu; ekranda yolun ortasindaki bir
    // rakam GORUNSEYDI o rakam YANLIS BIR BAKIYE olurdu.
    expect(screen.queryByText(/^0 TL$/)).toBeNull();
  });

  it("adet degeri para DEGILDIR — sayma yolu acik kalir", () => {
    ciz(() => createElement(Kpi, { deger: 7, etiket: "Gecikme" }));
    // Sayma yolu acik olsa da SON deger dogru olmali (sayac hedefi asip
    // geri donerse burada yakalanir).
    expect(screen.getAllByText(/Gecikme/).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/\b7\b/).length).toBeGreaterThan(0);
  });
});

describe("Kart — tiklanabilir kart YUKSELIR", () => {
  it("onClick varsa yukselme sinifi gelir", () => {
    ciz(() => createElement(Kart, { onClick: () => {}, children: "Ac" }));
    expect(screen.getByRole("button").classList.contains("yz-lift")).toBe(true);
  });

  it("tiklanamayan kart yukselmez (yanlis etkilesim vaadi vermez)", () => {
    ciz(() => createElement(Kart, { children: "Duz" }));
    expect(document.querySelector(".yz-lift")).toBeNull();
  });

  it("cagiran ACIKCA kapatabilir", () => {
    ciz(() => createElement(Kart, { onClick: () => {}, kalkan: false, children: "Ac" }));
    expect(screen.getByRole("button").classList.contains("yz-lift")).toBe(false);
  });
});

describe("HAREKET AZALTMA — kural TEK yerde ve GENEL", () => {
  // jsdom kipinde `import.meta.url` belge tabanina gore cozulur (dosya
  // yoluna DEGIL) — bu yuzden calisma dizini kullaniliyor.
  const globals = readFileSync(join(process.cwd(), "app", "globals.css"), "utf8");

  it("genel `prefers-reduced-motion` blogu VAR ve sureleri sifirlar", () => {
    const blok = globals.slice(globals.indexOf("@media (prefers-reduced-motion: reduce)"));
    expect(blok).toContain("animation-duration: 0.01ms !important");
    expect(blok).toContain("transition-duration: 0.01ms !important");
    // Basma geri bildirimi de kalkar.
    expect(blok).toContain("button:active");
  });

  it("kural EVRENSEL SECICIYLE yazilmis — yeni gecis eklemek onu atlatamaz", () => {
    const blok = globals.slice(globals.indexOf("@media (prefers-reduced-motion: reduce)"));
    expect(blok).toMatch(/\*,\s*\*::before,\s*\*::after/);
  });
});
