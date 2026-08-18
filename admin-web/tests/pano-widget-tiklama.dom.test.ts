// @vitest-environment jsdom
// (P168 §1.1) WIDGET TIKLAMA — OLU BAGLANTI SINIFININ KILIDI.
//
// =========================================================================
// BILDIRILEN HATA VE KOK NEDENI (olculdu, tahmin edilmedi)
// =========================================================================
// "Widget'lar gorunuyor ama tiklaninca hicbir sey olmuyor."
//
// Kok neden: kartlar `<Kart as="a" {...{ href }}>` yaziyordu. `Kart`
// FAZLADAN PROP'LARI YAYMAZ — `href` bilesene hic ulasmiyordu ve `<a>`
// HREF'SIZ ciziliyordu. Href'siz bir `<a>`:
//   * tiklanmaz,
//   * klavyeyle ODAKLANAMAZ (tab sirasinda yok),
//   * ekran okuyucuya "baglanti" diye duyurulmaz.
//
// Derleyici de susmustu: JSX spread'i TypeScript'in fazla-ozellik
// denetiminden KACAR. Yani tip sistemi, test ve goz denetimi -- ucu de
// kaciracak bir kusur sinifi.
//
// AYNI KUSUR IKI YERDEYDI: widget seridi VE finansal ozet kartlari.
// Test ikisini de olcer.
import { screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import React from "react";

import { Kart } from "@/components/ui";
import { WidgetSeridi } from "@/components/pano/widget-seridi";
import { WIDGET_SINIRI } from "@/lib/pano-tercihi";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
}));

const ADAYLAR = [
  { rota: "/finans", etiket: "Finans", bolum: "Finansal İşlemler", ikon: null },
  { rota: "/tasks", etiket: "Görevler", bolum: "Tesis", ikon: null },
  { rota: "/raporlar", etiket: "Raporlar", bolum: "Finansal İşlemler", ikon: null },
];

describe("(P168 §1.1) widget seridi TIKLANABILIR", () => {
  it("her widget GERCEK bir baglanti — href DOLU", () => {
    ciz(() =>
      React.createElement(WidgetSeridi, {
        adaylar: ADAYLAR,
        secili: ["/finans", "/tasks"],
        duzenlemede: false,
        onDegisti: vi.fn(),
      }),
    );

    // `getByRole("link")` HREF'SIZ `<a>`yi BULMAZ — testin gucu tam
    // olarak burada: eski kod bu satirda duserdi.
    const baglantilar = screen.getAllByRole("link");
    expect(baglantilar).toHaveLength(2);
    expect(baglantilar.map((a) => a.getAttribute("href"))).toEqual([
      "/finans",
      "/tasks",
    ]);
  });

  it("DUZENLEME KIPINDE baglanti YOK", () => {
    // Duzenleme kipinde kart suruklenip gizlenen bir OGEDIR, gidilecek
    // bir yer degil. Baglanti birakmak, siralamak isteyen kullaniciyi
    // baska sayfaya atardi.
    ciz(() =>
      React.createElement(WidgetSeridi, {
        adaylar: ADAYLAR,
        secili: ["/finans"],
        duzenlemede: true,
        onDegisti: vi.fn(),
      }),
    );
    expect(screen.queryAllByRole("link")).toHaveLength(0);
  });
});

describe("(P168 §1.1) `Kart` href SOZLESMESI", () => {
  it("href verilince baglanti cizilir", () => {
    ciz(() => React.createElement(Kart, { href: "/finans", children: "Kasa" }));
    expect(screen.getByRole("link")).toHaveAttribute("href", "/finans");
  });

  it("href YOKKEN baglanti CIZILMEZ", () => {
    // Karsilik olcumu: "her kart baglanti" gibi bir asiri duzeltme
    // yapilmadigini kilitler.
    ciz(() => React.createElement(Kart, { children: "Kasa" }));
    expect(screen.queryByRole("link")).toBeNull();
  });
});

describe("(P168 §1.2) YEDI widget", () => {
  it("sinir YEDI", () => {
    expect(WIDGET_SINIRI).toBe(7);
  });

  it("yedi widget'in HEPSI cizilir", () => {
    // Sinir 7 olup izgara 6 sutunda kalsaydi, yedinci kutu alt satira
    // tek basina duser ve "tam genislikte yedi esit alan" bozulurdu.
    const yedi = Array.from({ length: 7 }, (_, i) => ({
      rota: `/r${i}`,
      etiket: `W${i}`,
      bolum: "B",
      ikon: null,
    }));
    ciz(() =>
      React.createElement(WidgetSeridi, {
        adaylar: yedi,
        secili: yedi.map((w) => w.rota),
        duzenlemede: false,
        onDegisti: vi.fn(),
      }),
    );
    expect(screen.getAllByRole("link")).toHaveLength(7);
  });
});
