// @vitest-environment jsdom
// (E2E 2026-09) BAKIM — ozet yukleniyor/hata, CSV, kayit ekleri.
//
// TESIS-14: veri gelmeden `yasal_eksik ?? []` bos sayiliyor ve ilk
// cizimde "Zorunlu bakımların hepsi yapılmış." yaziliyordu.
// TESIS-05: sunucu `bakim_kaydi` ekini kabul ediyordu ama hicbir ekran
// onu cizmiyordu.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import BakimPage from "@/app/(protected)/bakim/page";
import { bakimOzetCsv } from "@/lib/bakim-ozet-csv";
import { tr } from "@/lib/i18n/sozluk/tr";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

const BOS_LISTE = { meta: { limit: 200, offset: 0, total: 0 }, items: [] };

async function ozetSekmesi() {
  await screen.findByRole("heading", { name: "Periyodik bakım", level: 1 });
  await userEvent.click(screen.getByRole("tab", { name: tr.bakimOzetBaslik }));
}

describe("(E2E 2026-09) bakim yillik ozeti", () => {
  it("YUKLENIRKEN 'hepsi yapilmis' DEMEZ", async () => {
    const sahte = globalThis.fetch;
    fetchSahtele({
      "/api/bakim/ekipmanlar": BOS_LISTE,
      "/api/bakim/kayitlar": BOS_LISTE,
    });
    const temel = globalThis.fetch;
    // Ozet ucu HIC donmez: yukleniyor durumu kalici.
    globalThis.fetch = ((girdi: RequestInfo | URL, init?: RequestInit) =>
      String(girdi).startsWith("/api/bakim/ozet")
        ? new Promise<Response>(() => {})
        : temel(girdi, init)) as typeof fetch;
    ciz(BakimPage);
    await ozetSekmesi();
    expect(el("bakim-ozet-yukleniyor")).toBeTruthy();
    expect(document.body.textContent).not.toContain(tr.bakimYasalEksikYok);
    expect(el("bakim-ozet-csv")).toBeNull();
    globalThis.fetch = sahte;
  });

  it("HATADA 'hepsi yapilmis' DEMEZ", async () => {
    fetchSahtele({
      "/api/bakim/ekipmanlar": BOS_LISTE,
      "/api/bakim/kayitlar": BOS_LISTE,
      "/api/bakim/ozet": { __durum: 500, error: { message: "x" } },
    });
    ciz(BakimPage);
    await ozetSekmesi();
    await waitFor(() => expect(el("bakim-ozet-yukleniyor")).toBeNull());
    expect(document.body.textContent).not.toContain(tr.bakimYasalEksikYok);
  });

  it("VERI GELINCE yasal eksik ve CSV dugmesi", async () => {
    fetchSahtele({
      "/api/bakim/ekipmanlar": BOS_LISTE,
      "/api/bakim/kayitlar": BOS_LISTE,
      "/api/bakim/ozet": {
        yil: 2026, toplam_kurus: 0, yasal_eksik: ["Jeneratör"], satirlar: [],
      },
    });
    ciz(BakimPage);
    await ozetSekmesi();
    await waitFor(() => expect(el("bakim-ozet-csv")).toBeTruthy());
    expect(el("bakim-yasal-eksik")?.textContent).toContain("Jeneratör");
  });
});

describe("(E2E 2026-09) bakim ozeti CSV", () => {
  it("BOM + noktali virgul + kurus TL'ye + kacis", () => {
    const csv = bakimOzetCsv(
      {
        yil: 2026,
        satirlar: [
          {
            ad: 'Asansör "A"; blok', yasal: true, bakim_sayisi: 2,
            toplam_kurus: 480050, son_bakim: "2026-03-01", sonraki_bakim: "2026-09-01",
          },
        ],
      },
      ["Ad", "Yasal", "Sayi", "Toplam", "Son", "Sonraki"],
      "Yasal",
    );
    expect(csv.startsWith("﻿")).toBe(true);
    const satirlar = csv.slice(1).split("\n");
    expect(satirlar[0]).toBe("Ad;Yasal;Sayi;Toplam;Son;Sonraki");
    expect(satirlar[1]).toBe('"Asansör ""A""; blok";Yasal;2;4800,50;2026-03-01;2026-09-01');
  });
});

describe("(E2E 2026-09) bakim kaydi ekleri", () => {
  it("GECMIS SATIRINDAN EK PENCERESI ACILIR (bakim_kaydi)", async () => {
    fetchSahtele({
      "/api/bakim/ekipmanlar": BOS_LISTE,
      "/api/bakim/kayitlar": {
        meta: { total: 1 },
        items: [{
          id: "k1", ekipman_id: "e1", ekipman_ad: "Asansör", tarih: "2026-09-20",
          firma_ad: null, yapan_ad: null, islem: null, tutar_kurus: null,
          hareket_id: null,
        }],
      },
      "/api/bakim/ozet": { yil: 2026, toplam_kurus: 0, yasal_eksik: [], satirlar: [] },
      "/api/panel/ekler": { items: [] },
    });
    ciz(BakimPage);
    await screen.findByRole("heading", { name: "Periyodik bakım", level: 1 });
    await userEvent.click(screen.getByRole("tab", { name: tr.bakimGecmis }));
    const dugme = await waitFor(() => {
      const d = el("bakim-kayit-ekler-k1");
      expect(d).toBeTruthy();
      return d as HTMLElement;
    });
    await userEvent.click(dugme);
    await screen.findByText(tr.ekYok);
    expect(
      cagrilanUrller().some(
        (u) => u.includes("/api/panel/ekler") && u.includes("varlik_tipi=bakim_kaydi")
          && u.includes("varlik_id=k1"),
      ),
    ).toBe(true);
  });
});
