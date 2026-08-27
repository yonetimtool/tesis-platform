// @vitest-environment jsdom
// (Duzeltme turu) DAIRE TIPI EKRANDA GORUNUYOR MU?
//
// OLCULEN KUSUR: `unit_tip_ad` API'den ZATEN geliyordu (P26 modeli, UnitOut
// alaninda) ama DAIRE LISTESI onu hic okumuyordu — kullanici tipi yalnizca
// bina tasarimcisinda gorebiliyordu.
//
// BINA TASARIMCISI KISMEN DOGRUYDU (P122): tip atanmis hucrede etiket ve
// renk vardi, ama tip ATANMAMIS hucre sessizce `#sira` gosteriyordu; "tip
// mi yok, sira mi?" ayirt edilemiyordu. Kural: tip yoksa "—".
import { screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import UnitsPage from "@/app/(protected)/units/page";

import { ciz } from "./yardimci";

// (P181) UnitsPage artık useRouter kullanıyor (6.2 "bina düzenleme" düğmesi);
// DOM testinde app-router yok — standart mock (bkz. pano-widget-tiklama).
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/",
  useSearchParams: () => new URLSearchParams(),
}));

const DAIRE = {
  id: "u1",
  no: "A-12",
  blok: "A",
  kat: 3,
  sira: 2,
  metrekare: 120,
  aktif: true,
  unit_tip_id: "t1",
  unit_tip_ad: "2+1",
  created_at: "2026-01-01T00:00:00Z",
};

function fetchTaklidi(daireler: unknown[]) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/api/units")
      ? { meta: { limit: 20, offset: 0, total: daireler.length }, items: daireler }
      : { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("daire listesi — TIP sutunu", () => {
  it("tip ATANMISSA adi gosterilir", async () => {
    fetchTaklidi([DAIRE]);
    ciz(UnitsPage);
    expect(await screen.findByText("A-12")).toBeInTheDocument();
    expect(screen.getByText("2+1")).toBeInTheDocument();
  });

  it("tip ATANMAMISSA tire gosterilir (bos hucre DEGIL)", async () => {
    // Bos hucre "veri gelmedi mi?" sorusunu uretir; tire "atanmamis" der.
    fetchTaklidi([{ ...DAIRE, unit_tip_id: null, unit_tip_ad: null }]);
    ciz(UnitsPage);
    await screen.findByText("A-12");
    const satir = screen.getByText("A-12").closest("tr");
    expect(satir?.textContent).toContain("—");
  });

  it("UZUN tip adi listede KIRPILMADAN gosterilir", async () => {
    // Kisaltma yalniz bina tasarimcisi HUCRESI icindir (64px); listede yer
    // vardir ve tam ad daha kullanislidir.
    fetchTaklidi([{ ...DAIRE, unit_tip_ad: "Dubleks Bahçe Katı" }]);
    ciz(UnitsPage);
    expect(await screen.findByText("Dubleks Bahçe Katı")).toBeInTheDocument();
  });
});
