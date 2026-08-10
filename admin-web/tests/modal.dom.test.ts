// @vitest-environment jsdom
// (P154 / Asama 6.1) MODAL — DAVRANIS testi.
//
// OLCULEN SEY GORUNUM DEGIL: ESC kapatiyor mu, dis tik kapatiyor ama IC
// tik kapatmiyor mu, odak iceri girip cagirana donuyor mu, Tab modalin
// icinde sariyor mu, kirli formda onay soruluyor mu.
//
// Bunlarin hepsi "her ekran kendi acilir alanini yazarsa unutulacak"
// sinifindan. Tek bilesende toplanmalarinin TEK gerekcesi bu — o yuzden
// testi de davranis uzerinden yaziliyor.
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement, useState } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { Modal, ModalEylemler } from "@/components/Modal";

import { ciz } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

/** Acma dugmesi + modal — odagin CAGIRANA donusunu olcebilmek icin. */
function Sarmal({ kirli = false }: { kirli?: boolean }) {
  const [acik, setAcik] = useState(false);
  return createElement(
    "div",
    null,
    createElement(
      "button",
      { onClick: () => setAcik(true), "data-testid": "ac" },
      "Ac",
    ),
    // `children` PROP OLARAK verilir: `createElement`in ucuncu argumani,
    // `children`i ZORUNLU ilan eden bilesenlerin tip denetimini gecmiyor
    // (bkz. tests/yardimci.ts — ayni tuzak Next derlemesini kirmisti).
    createElement(Modal, {
      baslik: "Kasa ekle",
      acik,
      kirli,
      kapat: () => setAcik(false),
      altBilgi: createElement(ModalEylemler, { iptal: () => setAcik(false) }),
      children: [
        createElement("input", { key: "kod", "aria-label": "Kod" }),
        createElement("input", { key: "ad", "aria-label": "Ad" }),
      ],
    }),
  );
}

describe("(P154) Modal — erisilebilirlik ve kapanma", () => {
  it("kapaliyken HICBIR SEY cizmez", () => {
    ciz(() => createElement(Sarmal));
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("acilinca dialog rolu + baslik BAGLI gelir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));

    const d = screen.getByRole("dialog");
    expect(d.getAttribute("aria-modal")).toBe("true");
    // Ekran okuyucu "hangi pencere" sorusunu yanitlayabilmeli: baslik
    // ELEMENTI bagli olmali, yalniz ekranda durmasi yetmez.
    expect(d).toHaveAccessibleName("Kasa ekle");
  });

  it("ODAK iceri girer, kapaninca CAGIRANA doner", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    const acDugmesi = screen.getByTestId("ac");
    await k.click(acDugmesi);

    // Ilk odaklanabilir oge — modalin ICINDE.
    expect(screen.getByRole("dialog").contains(document.activeElement)).toBe(true);

    await k.keyboard("{Escape}");
    // Odak `<body>`ye dusseydi klavyeyle calisan kullanici listenin
    // basina savrulurdu.
    expect(document.activeElement).toBe(acDugmesi);
  });

  it("ESC kapatir", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));
    expect(screen.getByRole("dialog")).toBeTruthy();
    await k.keyboard("{Escape}");
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("DIS tik kapatir, IC tik KAPATMAZ", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));

    // Ic tiklama: metin secerken birakma hareketi ortuyle bitse bile
    // kullanici yazdigini kaybetmemeli.
    await k.click(screen.getByLabelText("Kod"));
    expect(screen.queryByRole("dialog")).toBeTruthy();

    const ortu = screen.getByRole("dialog").parentElement!;
    await k.click(ortu);
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("KIRLI formda onay sorulur; VAZGECILIRSE acik kalir", async () => {
    const k = userEvent.setup();
    const onay = vi.spyOn(window, "confirm").mockReturnValue(false);
    ciz(() => createElement(Sarmal, { kirli: true }));
    await k.click(screen.getByTestId("ac"));

    await k.keyboard("{Escape}");
    expect(onay).toHaveBeenCalled();
    expect(screen.queryByRole("dialog")).toBeTruthy();

    onay.mockReturnValue(true);
    await k.keyboard("{Escape}");
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("ODAK TUZAGI: son ogeden Tab ILKE doner", async () => {
    const k = userEvent.setup();
    ciz(() => createElement(Sarmal));
    await k.click(screen.getByTestId("ac"));

    const d = screen.getByRole("dialog");
    const odaklanabilir = Array.from(
      d.querySelectorAll<HTMLElement>("button,input"),
    );
    odaklanabilir[odaklanabilir.length - 1].focus();
    await k.tab();
    // Sarmalamadan odak ARKA PLANA kacar ve kullanici "kapali" sandigi
    // bir formun arkasinda gezinir.
    expect(d.contains(document.activeElement)).toBe(true);
  });
});
