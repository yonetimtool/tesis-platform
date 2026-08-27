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

describe("(P182 §2) ALTI widget", () => {
  it("sinir ALTI", () => {
    // (P182 §2) 7 DEGIL 6: sunucu semasi (widgetlar max_length=6) hep 6'ydi;
    // istemci 7'ye izin verince yedinci sessizce kaydedilmiyordu. Sinir 6'ya
    // hizalandi (istemci + sunucu + izgara lg:grid-cols-6).
    expect(WIDGET_SINIRI).toBe(6);
  });

  it("alti widget'in HEPSI cizilir", () => {
    // Alti kutu masaustunde 6 sutunlu izgarayi tam doldurur; sagda bos
    // sutun kalmaz.
    const alti = Array.from({ length: 6 }, (_, i) => ({
      rota: `/r${i}`,
      etiket: `W${i}`,
      bolum: "B",
      ikon: null,
    }));
    ciz(() =>
      React.createElement(WidgetSeridi, {
        adaylar: alti,
        secili: alti.map((w) => w.rota),
        duzenlemede: false,
        onDegisti: vi.fn(),
      }),
    );
    expect(screen.getAllByRole("link")).toHaveLength(6);
  });
});
