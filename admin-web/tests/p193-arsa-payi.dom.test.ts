// @vitest-environment jsdom
// (P193 §6) ARSA PAYI — TOPLU GIRIS EKRANI.
//
// Rehberde eksik 6: arsa payi YALNIZ tek tek girilebiliyordu ve listede
// HIC gorunmuyordu. 100 daireli bir sitede bu 100 ayri form demekti;
// ustelik arsa payi girilmemis daire, arsa payina gore dagitimin DISINDA
// kaldigi icin eksik giris SESSIZ bir yanlis paylasima donusuyordu.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UnitsPage from "@/app/(protected)/units/page";

import { ciz, fetchSahtele } from "./yardimci";

// UnitsPage `useRouter` kullaniyor; DOM testinde app-router yok
// (bkz. daire-tipi-gosterim.dom.test.ts — ayni standart mock).
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/",
  useSearchParams: () => new URLSearchParams(),
}));

const DAIRELER = [
  { id: "aaaaaaaa-0000-0000-0000-000000000001", no: "A-1", blok: "A",
    kat: 1, sira: 1, metrekare: 120, arsa_payi: 0.0125, aktif: true },
  { id: "aaaaaaaa-0000-0000-0000-000000000002", no: "A-2", blok: "A",
    kat: 1, sira: 2, metrekare: 95, arsa_payi: null, aktif: true },
];

function kur() {
  fetchSahtele({
    "/api/units/arsa-payi-ozeti": {
      daire_sayisi: 2, girilmis: 1, girilmemis: 1, toplam: 0.0125,
    },
    "/api/units": { meta: { total: 2 }, items: DAIRELER },
    "/api/blocks": { items: [{ id: "b1", ad: "A" }] },
    "/api/tanimlar/unit-tipleri": { items: [] },
  });
  const govdeler: { yol: string; govde: Record<string, unknown> }[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method === "PATCH" && init.body) {
      govdeler.push({ yol: String(g), govde: JSON.parse(String(init.body)) });
    }
    return onceki(g, init);
  }) as typeof fetch;
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

describe("(P193 §6) arsa payı toplu giriş", () => {
  it("TOPLAM ve EKSIK GIRIS sayisi gorunur", async () => {
    kur();
    ciz(UnitsPage);
    // Toplam AYRI UCTAN gelir: liste sayfalidir, gorunen satirlarin
    // toplami "toplam arsa payi" DEGILDIR.
    expect(await screen.findByText(/Arsa payı toplamı/)).toBeInTheDocument();
    expect(
      screen.getByText(/1 dairede arsa payı yok/),
      "eksik giris uyarisi gorunmuyor",
    ).toBeInTheDocument();
  });

  it("SECILI dairelere DAIRE BASINA farkli deger yazilir", async () => {
    const govdeler = kur();
    ciz(UnitsPage);
    await screen.findByText("A-1");

    // Iki daireyi sec (satir onay kutulari).
    const kutular = screen.getAllByRole("checkbox");
    await userEvent.click(kutular[1]);
    await userEvent.click(kutular[2]);

    await userEvent.click(
      screen.getByRole("button", { name: /Arsa payı gir/ }),
    );
    const diyalog = await screen.findByRole("dialog");
    // MEVCUT DEGER ON DOLU gelir: kullanici hangi dairede ne oldugunu
    // gormeden yeni deger yazamaz.
    expect(within(diyalog).getByLabelText("A-1")).toHaveValue("0,0125");
    const ikinci = within(diyalog).getByLabelText("A-2");
    await userEvent.type(ikinci, "0,02");
    await userEvent.click(within(diyalog).getByRole("button", { name: /Kaydet/ }));

    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(govdeler[0].yol).toContain("/api/units/arsa-payi");
    expect(govdeler[0].govde.satirlar).toEqual([
      { id: DAIRELER[0].id, arsa_payi: 0.0125 },
      { id: DAIRELER[1].id, arsa_payi: 0.02 },
    ]);
  });

  it("BOZUK SAYI istegi ATMAZ, sebebini soyler", async () => {
    const govdeler = kur();
    ciz(UnitsPage);
    await screen.findByText("A-1");
    const kutular = screen.getAllByRole("checkbox");
    await userEvent.click(kutular[1]);
    await userEvent.click(screen.getByRole("button", { name: /Arsa payı gir/ }));
    const diyalog = await screen.findByRole("dialog");
    const alan = within(diyalog).getByLabelText("A-1");
    await userEvent.clear(alan);
    await userEvent.type(alan, "yok");
    await userEvent.click(within(diyalog).getByRole("button", { name: /Kaydet/ }));
    expect(
      await within(diyalog).findByText(/Arsa payı sayı olmalı/),
    ).toBeInTheDocument();
    expect(govdeler.length, "bozuk deger sunucuya GITMEMELI").toBe(0);
  });
});
