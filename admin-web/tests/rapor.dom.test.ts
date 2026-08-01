// @vitest-environment jsdom
// (P44) Rapor sayfasi — PARAMETRE GOVDESI ve INDIRME.
//
// Olculen sey tablo cizimi degil, iki sessiz hata sinifi: (1) bos alanin
// govdeye girmesi (sunucuda dogrulama hatasi uretir), (2) dosya adinin
// panelde UYDURULMASI (indirilen dosya ile raporun adi ayrisir).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import RaporlarPage from "@/app/(protected)/raporlar/page";

import { ciz, fetchSahtele } from "./yardimci";

const KATALOG = {
  items: [
    { kod: "borc_alacak", baslik: "Borç/Alacak", aciklama: "Daire bazlı bakiye" },
    { kod: "ihtar_yazisi", baslik: "İhtar Yazısı", aciklama: "KMK m.20" },
  ],
};

afterEach(() => vi.restoreAllMocks());

async function katalogYuklendi(): Promise<void> {
  await waitFor(() => expect(screen.getByText("Borç/Alacak")).toBeInTheDocument());
}

describe("Rapor sayfasi", () => {
  it("katalog SUNUCUDAN gelir — sayfa rapor adi TASIMAZ", async () => {
    fetchSahtele({ "/api/panel/rapor-katalog": KATALOG });
    ciz(RaporlarPage);
    await katalogYuklendi();
    expect(screen.getByText("İhtar Yazısı")).toBeInTheDocument();
    expect(screen.getByText("KMK m.20")).toBeInTheDocument();
  });

  it("BOS parametre govdeye GIRMEZ", async () => {
    // Bos dizgeyi tarih diye gondermek sunucuda dogrulama hatasi uretirdi.
    fetchSahtele({ "/api/panel/rapor-katalog": KATALOG });
    const govdeler: Record<string, unknown>[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (String(girdi).includes("/api/panel/rapor/") && init?.body) {
        govdeler.push(JSON.parse(String(init.body)));
        return new Response(
          JSON.stringify({
            kod: "borc_alacak", baslik: "Borç/Alacak",
            sutunlar: [{ ad: "daire", etiket: "Daire" }],
            satirlar: [{ daire: "A-1" }], toplamlar: {}, metin: null,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      return onceki(girdi, init);
    }) as typeof fetch;

    ciz(RaporlarPage);
    await katalogYuklendi();
    await userEvent.click(screen.getByText("Borç/Alacak"));
    await userEvent.click(screen.getByRole("button", { name: "Göster" }));

    await waitFor(() => expect(govdeler.length).toBe(1));
    // Yalniz `ismi_goster` gitmeli; bos tarih/blok alanlari YOK.
    expect(Object.keys(govdeler[0]).sort()).toEqual(["ismi_goster"]);
    expect(govdeler[0].ismi_goster).toBe(true);
  });

  it("dolu parametreler govdeye GIRER", async () => {
    fetchSahtele({ "/api/panel/rapor-katalog": KATALOG });
    const govdeler: Record<string, unknown>[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (String(girdi).includes("/api/panel/rapor/") && init?.body) {
        govdeler.push(JSON.parse(String(init.body)));
        return new Response(
          JSON.stringify({ kod: "x", baslik: "x", sutunlar: [], satirlar: [], toplamlar: {}, metin: null }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      return onceki(girdi, init);
    }) as typeof fetch;

    ciz(RaporlarPage);
    await katalogYuklendi();
    await userEvent.click(screen.getByText("Borç/Alacak"));
    await userEvent.type(screen.getByLabelText("Blok"), "A");
    // KVKK (P31): kapiya asilacak listede ad OLMAMALI.
    await userEvent.click(screen.getByLabelText("Ad sütunu"));
    await userEvent.click(screen.getByRole("button", { name: "Göster" }));

    await waitFor(() => expect(govdeler.length).toBe(1));
    expect(govdeler[0]).toMatchObject({ blok: "A", ismi_goster: false });
  });

  it("SATIR YOKSA yonlendirici bos durum — bos tablo cizilmez", async () => {
    fetchSahtele({ "/api/panel/rapor-katalog": KATALOG });
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      if (String(girdi).includes("/api/panel/rapor/")) {
        return new Response(
          JSON.stringify({ kod: "x", baslik: "Borç/Alacak", sutunlar: [], satirlar: [], toplamlar: {}, metin: null }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      return onceki(girdi, init);
    }) as typeof fetch;

    ciz(RaporlarPage);
    await katalogYuklendi();
    await userEvent.click(screen.getByText("Borç/Alacak"));
    await userEvent.click(screen.getByRole("button", { name: "Göster" }));
    await waitFor(() => expect(screen.getByText("Satır yok")).toBeInTheDocument());
  });
});
