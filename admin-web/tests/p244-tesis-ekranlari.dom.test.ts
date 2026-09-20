// @vitest-environment jsdom
// (P244 §6b) TESIS EKRANLARI — DAIRE DETAYI CEKMECEDE.
//
// ===========================================================================
// OLCULEN KUSUR
// ===========================================================================
// Daire detayi TABLONUN ALTINDA aciliyor ve sayfa oraya KAYDIRILIYORDU
// (`useAcilinca`). Kullanici listedeki yerini kaybediyor, geri donunce
// suzgecleri ve kaydirmayi yeniden kuruyordu; bir daireden otekine
// bakmak her seferinde asagi-yukari gitmek demekti.
//
// Ayrica: asama 3'te yazilan `DetayCekmecesi` alti tur boyunca HICBIR
// sayfada kullanilmiyordu. Ilk tuketicisi bu ekran.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UnitsPage from "@/app/(protected)/units/page";

import { ciz } from "./yardimci";

const kanca = (ad: string): HTMLElement | null =>
  document.querySelector<HTMLElement>(`[data-test="${ad}"]`);

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/units",
  useSearchParams: () => new URLSearchParams(),
}));

const DAIRE = {
  id: "u1",
  no: "A-12",
  blok: "A",
  kat: 3,
  tip: null,
  aktif: true,
  arsa_payi: null,
};

function taklit() {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    // SIRA ONEMLI: `/api/units/{id}/residents` da `/api/units` iceriyor.
    // Genel dali one almak, dizi bekleyen bir uca NESNE dondurup
    // bileseni `filter is not a function` ile dusuruyordu (olculdu).
    const govde = url.includes("/residents")
      ? []
      : url.includes("/dues")
        ? { donemler: [], bakiye_kurus: 0 }
        : url.includes("/api/units/arsa-payi-ozeti")
          ? { daire_sayisi: 40, girilmis: 28, girilmemis: 12, toplam: 1000 }
          : url.includes("/api/blocks")
            ? { items: [{ id: "b1", ad: "A" }] }
            : url.includes("/api/units")
              ? { items: [DAIRE], meta: { total: 1, limit: 25, offset: 0 } }
              : { items: [], meta: { total: 0 } };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §6b) daireler", () => {
  it("OZET SERIDI arsa payi eksigini SAYIYLA soyler", async () => {
    // Eskiden bu bilgi tablonun ALTINDA duz bir cumleydi; sayfanin
    // ustunde ve sayi olarak durmasi "eksik var mi" sorusunu tek
    // bakista yanitliyor.
    taklit();
    ciz(UnitsPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    const kart = screen.getByText("Arsa payı girilmemiş").closest("div")!.parentElement!;
    expect(kart.textContent).toContain("12");
  });

  it("DETAY CEKMECEDE acilir — liste YERINDE kalir", async () => {
    taklit();
    const { container } = ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    // Acilmadan once diyalog YOK.
    expect(screen.queryByRole("dialog")).toBeNull();
    await userEvent.click(screen.getByRole("button", { name: /Detay/i }));
    const cekmece = await screen.findByRole("dialog");
    expect(cekmece).toHaveAccessibleName(/A-12/);
    // ARKADAKI TABLO DURUYOR: cekmecenin tum mesele bu.
    expect(container.querySelector("table")).not.toBeNull();
  });

  it("CEKMECE ESC ile kapanir", async () => {
    taklit();
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: /Detay/i }));
    await screen.findByRole("dialog");
    await userEvent.keyboard("{Escape}");
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  });

  it("SATIR TIKLAMASI EKLENMEDI — tablo SECILEBILIR", async () => {
    // Olculmus karar: satira tiklamak secilebilir bir tabloda
    // kullanicilarin cogunda "sec" anlamina gelir. Iki anlami ayni
    // harekete yuklemek, toplu islem yapmak isteyene her seferinde
    // cekmece acardi.
    taklit();
    const { container } = ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    const satir = container.querySelector("tbody tr") as HTMLElement;
    expect(satir.getAttribute("role")).toBeNull();
    // Secim kutusu ise DURUYOR.
    expect(container.querySelector('tbody input[type="checkbox"]')).not.toBeNull();
  });
});
