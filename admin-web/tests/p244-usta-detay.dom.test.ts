// @vitest-environment jsdom
//
// (P244 §9a) USTA-DETAY DUZENI — on bir defter, tek sutun.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// `/tanimlar` ON BIR kayit defterini sayfanin ustunde SARAN bir dugme
// sirasi olarak diziyordu: iki-uc satira yayilan dugmeler, yalnizca
// renkle belli olan secim ve her tiklamada asagi kayan icerik.
//
// ===========================================================================
// UC IDDIA
// ===========================================================================
// 1. GERCEK SEKME DESENI. Secim `aria-pressed` tasiyan dugmeler degil,
//    `role=tablist`/`role=tab`/`aria-selected` — ve DIKEY. Ekran
//    okuyucu "N ogeden K" der; `aria-pressed` bunu SOYLEMEZ.
// 2. SERITTE TEK KLAVYE DURAGI. On bir sekmenin her biri odaklanabilir
//    olsaydi klavye kullanicisi icerige ulasmak icin on bir kez Tab'a
//    basardi. Gezinme ok tuslariyla.
// 3. YALNIZ SECILI OLAN CIZILIR. Her defterin kendi `useSWR`i var;
//    hepsini birden kurmak bir istek yerine on bir istek demekti.
//
// (3) `Sekmeler` yerine ayri bir bilesen yazilmasinin SEBEBIDIR:
// `Sekmeler` icerigi kendi tutar (`sekme.icerik`), yani hepsini kurar.
import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TanimlarPage from "@/app/(protected)/tanimlar/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tanimlar",
  useSearchParams: () => new URLSearchParams(),
}));

function kur() {
  fetchSahtele({
    "/api/tanimlar": { meta: { total: 0 }, items: [] },
    "/api/muhasebe-ayarlari": {},
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §9a) tanimlar — usta-detay", () => {
  it("DEFTERLER DIKEY BIR `tablist` (dugme sirasi degil)", async () => {
    kur();
    ciz(TanimlarPage);
    const liste = await screen.findByRole("tablist");
    expect(liste.getAttribute("aria-orientation")).toBe("vertical");
    // On bir defter + "Ayarlar" — sayinin kendisi degisebilir, ama
    // duzenin ANLAMLI sayida oge tasidigi olculur.
    expect(within(liste).getAllByRole("tab").length).toBeGreaterThan(8);
  });

  it("SECIM `aria-selected` ile soylenir, renkle DEGIL", async () => {
    kur();
    ciz(TanimlarPage);
    const liste = await screen.findByRole("tablist");
    const sekmeler = within(liste).getAllByRole("tab");
    const secili = sekmeler.filter((x) => x.getAttribute("aria-selected") === "true");
    expect(secili.length, "tam olarak bir sekme secili olmali").toBe(1);
  });

  it("SERITTE TEK KLAVYE DURAGI", async () => {
    kur();
    ciz(TanimlarPage);
    const liste = await screen.findByRole("tablist");
    const duraklar = within(liste)
      .getAllByRole("tab")
      .filter((x) => x.getAttribute("tabindex") === "0");
    expect(duraklar.length, "seritte tek durak olmali").toBe(1);
  });

  it("OK TUSU sekme DEGISTIRIR (ARIA klavye deseni)", async () => {
    kur();
    ciz(TanimlarPage);
    const liste = await screen.findByRole("tablist");
    const sekmeler = within(liste).getAllByRole("tab");
    const ilkAd = sekmeler[0].textContent;
    sekmeler[0].focus();
    await userEvent.keyboard("{ArrowDown}");
    const yeniSecili = within(liste)
      .getAllByRole("tab")
      .find((x) => x.getAttribute("aria-selected") === "true");
    expect(yeniSecili?.textContent, "ok tusu secimi tasimadi").not.toBe(ilkAd);
  });

  it("YALNIZ SECILI DEFTERIN UCU CAGRILIR", async () => {
    // On bir defterin hepsi birden kurulsaydi, ilk cizimde on bir ayri
    // `/api/tanimlar/...` istegi giderdi.
    kur();
    ciz(TanimlarPage);
    await screen.findByRole("tablist");
    const defterIstekleri = new Set(
      cagrilanUrller()
        .filter((u) => u.includes("/api/tanimlar/"))
        .map((u) => u.split("?")[0]),
    );
    expect(defterIstekleri.size, `cagrilan defter uclari: ${[...defterIstekleri]}`).toBeLessThanOrEqual(1);
  });
});
