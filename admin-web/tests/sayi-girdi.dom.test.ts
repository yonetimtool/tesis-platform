// @vitest-environment jsdom
// (P56) SESSIZ TEMIZLEME sinifi — davranis tarafi.
//
// Panelde alti yerde ayni desen vardi: `Number(metin)` -> NaN -> `null`,
// ve `null` bu uclarda "ALANI TEMIZLE" demektir. Yani gecersiz (ya da
// yalnizca Turkce yazimla girilmis) bir deger, alani SESSIZCE
// siliyordu — kullanici hata bile almiyordu.
//
// Buradaki testler iki seyi sabitler: (1) gecersiz girdide istek HIC
// ATILMAZ ve neden soylenir, (2) Turkce yazim kabul edilir.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import CheckpointsPage from "@/app/(protected)/checkpoints/page";
import UnitsPage from "@/app/(protected)/units/page";

import { ciz, fetchSahtele } from "./yardimci";

// (P181) UnitsPage artık useRouter kullanıyor (6.2); DOM testinde app-router
// yok — standart mock (bkz. pano-widget-tiklama).
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/",
  useSearchParams: () => new URLSearchParams(),
}));

const DAIRELER = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "u1", no: "A-12", blok: "A", kat: 1, sira: 2,
            metrekare: 120.5, aktif: true, created_at: "2026-01-01T00:00:00Z" }],
};
const NOKTALAR = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };

/** Gonderilen govdeleri yakala (istek ATILDI MI sorusu icin). */
function govdeYakala(harita: Record<string, unknown>): unknown[] {
  const govdeler: unknown[] = [];
  fetchSahtele(harita);
  const oncekiFetch = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method && init.method !== "GET") {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return oncekiFetch(girdi, init);
  }) as typeof fetch;
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

describe("Daireler — metrekare", () => {
  it("TURKCE YAZIM kabul edilir (virgullu ondalik)", async () => {
    const govdeler = govdeYakala({ "/api/units": DAIRELER });
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);

    // Tabloda gorunen bicim ON-DOLGUDA da olmali (P49/P50 kurali).
    const m2 = screen.getByLabelText(/Metrekare/);
    expect(m2).toHaveValue("120,5");

    await userEvent.clear(m2);
    await userEvent.type(m2, "99,25");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(govdeler.length).toBe(1));
    expect((govdeler[0] as { metrekare: number }).metrekare).toBe(99.25);
  });

  it("GECERSIZ girdide istek ATILMAZ ve alan SESSIZCE SILINMEZ", async () => {
    const govdeler = govdeYakala({ "/api/units": DAIRELER });
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);

    const m2 = screen.getByLabelText(/Metrekare/);
    await userEvent.clear(m2);
    await userEvent.type(m2, "abc");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() =>
      expect(screen.getByText(/Metrekare geçersiz/)).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });
});

describe("NFC noktası — konum", () => {
  it("GECERSIZ koordinatta istek ATILMAZ", async () => {
    const govdeler = govdeYakala({ "/api/checkpoints": NOKTALAR });
    ciz(CheckpointsPage);
    await waitFor(() =>
      expect(screen.getAllByRole("button", { name: /Ekle|Yeni/ })[0]).toBeInTheDocument(),
    );
    await userEvent.click(screen.getAllByRole("button", { name: /Ekle|Yeni/ })[0]);
    await userEvent.type(screen.getByLabelText(/^Ad/), "Ana Kapı");
    // ZORUNLU alan bos birakilirsa TARAYICI dogrulamasi gonderimi keser ve
    // uygulamanin kendi dogrulamasi HIC calismaz (P45'te olculmustu).
    await userEvent.type(screen.getByLabelText(/NFC etiket UID/), "04A1B2C3D4E5F6");
    await userEvent.type(screen.getByLabelText(/GPS enlem/), "kuzey");
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));

    await waitFor(() =>
      expect(screen.getByText(/Konum geçersiz/)).toBeInTheDocument(),
    );
    expect(govdeler.length).toBe(0);
  });
});
