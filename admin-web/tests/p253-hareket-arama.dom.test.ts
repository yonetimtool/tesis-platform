// @vitest-environment jsdom
// (P253 A2) Hareket listesi: serbest arama (`q`) ve durum suzgeci SUNUCUYA
// gider (istemcide suzmek sayfalamayi bozardi). BFF beyaz listesi de iki
// parametreyi tasir — tasimasaydi vekil sessizce duserdi (P226 dersi).
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

import BorclularPage from "@/app/(protected)/finans/borclular/page";
import GiderlerPage from "@/app/(protected)/finans/giderler/page";
import { SUZGECLER } from "@/lib/panel-vekil";

import { ciz, fetchSahtele } from "./yardimci";

function hareketIstekleri(): string[] {
  const kayit: string[] = [];
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    if (url.startsWith("/api/panel/finans-hareketler?")) kayit.push(url);
    return onceki(girdi, init);
  }) as typeof fetch;
  return kayit;
}

describe("(P253 A2) hareket aramasi + durum suzgeci", () => {
  it("arama ve durum SUNUCU SORGUSUNA girer, sayfa basa doner", async () => {
    fetchSahtele({
      "/api/panel/finans-hareketler": { meta: { total: 0 }, items: [] },
      "/api/panel/kasalar": { items: [] },
    });
    const istekler = hareketIstekleri();
    ciz(GiderlerPage);
    await waitFor(() => expect(istekler.length).toBeGreaterThan(0));

    await userEvent.type(screen.getByLabelText("Hareketlerde ara"), "şahin");
    await waitFor(() =>
      expect(istekler.some((u) => new URL(u, "http://x").searchParams.get("q") === "şahin")).toBe(true),
    );
    await userEvent.selectOptions(screen.getByLabelText("Durum"), "onay_bekliyor");
    await waitFor(() => {
      const son = new URL(istekler[istekler.length - 1], "http://x").searchParams;
      expect(son.get("durum")).toBe("onay_bekliyor");
      expect(son.get("q")).toBe("şahin");
      expect(son.get("offset")).toBe("0");
    });
  });

  it("BFF beyaz listesi q ve durum'u tasir", () => {
    expect(SUZGECLER["finans-hareketler"]).toEqual(expect.arrayContaining(["q", "durum"]));
  });
});

// (P253 §C-1) Web "Faizi affet" eskiden ONAYSIZ calisiyordu.
describe("(P253 §C) borclular — faiz affi onay ister", () => {
  it("onay diyalogunda hedef daireler; onaylanmadan istek YOK", async () => {
    const daireler = [
      { unit_id: "u1", unit_no: "A-1", en_eski_gun: 10, kova: "0-30", kalan_kurus: 100000, borclu_ad: null },
      { unit_id: "u2", unit_no: "A-2", en_eski_gun: 20, kova: "0-30", kalan_kurus: 200000, borclu_ad: null },
    ];
    fetchSahtele({
      "/api/panel/yaslandirma": {
        kovalar: [{ kova: "0-30", daire: 2, kalan_kurus: 300000, daireler }],
        toplam_kalan_kurus: 300000, toplam_daire: 2,
      },
      "/api/panel/tahsilat-gostergesi": { donem: "2026-10", tahakkuk_kurus: 0, tahsilat_kurus: 0 },
      "/api/panel/borclulara-faiz-affi": { affedilen_kalem: 2, toplam_kurus: 900 },
    });
    const yazilan: string[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method === "POST") yazilan.push(String(g));
      return onceki(g, init);
    }) as typeof fetch;
    ciz(BorclularPage);
    await userEvent.click(await screen.findByRole("button", { name: /0-30/ }));
    await userEvent.click(await screen.findByLabelText("A-1"));
    await userEvent.click(screen.getByLabelText("A-2"));
    await userEvent.click(screen.getByRole("button", { name: "Faizi affet" }));
    const diyalog = await screen.findByRole("dialog");
    expect(diyalog.textContent).toContain("A-1, A-2");
    expect(yazilan).toEqual([]);
    await userEvent.click(within(diyalog).getByRole("button", { name: "Faizi affet" }));
    await waitFor(() => expect(yazilan).toEqual(["/api/panel/borclulara-faiz-affi"]));
  });
});
