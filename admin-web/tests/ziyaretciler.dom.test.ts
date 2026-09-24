// @vitest-environment jsdom
// (P126.4) ZIYARETCILER — guvenligin kapi ekrani.
//
// Iki kural olculur:
//  1. CIKIS DUGMESI yalniz ICERIDEKI ziyaretcide gorunur — cikmis birine
//     tekrar cikis yaptirmak kaydi ikinci kez damgalamak olurdu;
//  2. eksik alanla istek GONDERILMEZ (kapida hizli yazarken en sik hata).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import ZiyaretcilerPage from "@/app/(protected)/ziyaretciler/page";

import { ciz } from "./yardimci";

function taklit(harita: Record<string, unknown>) {
  const cagrilar: { url: string; method: string; body: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const anahtar = Object.keys(harita)
      .filter((k) => url.startsWith(k))
      .sort((a, b) => b.length - a.length)[0];
    if (anahtar === undefined) {
      return new Response(JSON.stringify({ error: { message: "yok" } }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(JSON.stringify(harita[anahtar]), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const ICERIDE = {
  id: "z1",
  unit_no: "A-12",
  ziyaretci_ad: "Ali Veli",
  notlar: null,
  giris_zamani: "2026-08-04T09:00:00Z",
  cikis_zamani: null,
};
const CIKMIS = { ...ICERIDE, id: "z2", ziyaretci_ad: "Ayşe Can", cikis_zamani: "2026-08-04T11:00:00Z" };

afterEach(() => vi.restoreAllMocks());

describe("Ziyaretçiler", () => {
  it("kayitlar listelenir", async () => {
    taklit({ "/api/visitors": { items: [ICERIDE] } });
    ciz(ZiyaretcilerPage);
    expect(await screen.findByText("Ali Veli")).toBeInTheDocument();
    expect(screen.getByText("A-12")).toBeInTheDocument();
  });

  it("CIKIS dugmesi yalniz ICERIDEKI ziyaretcide", async () => {
    taklit({ "/api/visitors": { items: [ICERIDE, CIKMIS] } });
    ciz(ZiyaretcilerPage);
    await screen.findByText("Ali Veli");
    // Iki kayit var ama tek cikis dugmesi olmali.
    expect(screen.getAllByRole("button", { name: /Çıkış ver/i })).toHaveLength(1);
  });

  it("CIKIS istegi dogru uca gider", async () => {
    const c = taklit({ "/api/visitors": { items: [ICERIDE] } });
    ciz(ZiyaretcilerPage);
    await userEvent.click(
      await screen.findByRole("button", { name: /Çıkış ver/i }),
    );
    await waitFor(() =>
      expect(
        c.some((x) => x.url === "/api/visitors/z1/checkout" && x.method === "POST"),
      ).toBe(true),
    );
  });

  it("EKSIK alanla kayit GONDERILMEZ", async () => {
    const c = taklit({ "/api/visitors": { items: [] } });
    ciz(ZiyaretcilerPage);
    // (P161) Form artik MODALDA: once acilir.
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni ziyaretçi girişi" }),
    );
    await userEvent.click(
      await screen.findByRole("button", { name: /Girişi kaydet/i }),
    );
    expect(await screen.findByText(/zorunludur/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });

  it("KAYIT daire NUMARASI + HEDEF SAKIN ile gonderilir", async () => {
    // Kapida gorevli daire NUMARASINI bilir, kaydin kimligini degil.
    //
    // (E2E 2026-09 / GUVENLIK-14) Olculen: govde `{unit_no, ziyaretci_ad}`
    // idi; `target_resident_user_id` sunucuda ZORUNLU oldugu icin her
    // kayit 422 aliyordu. Daire artik ARANIR (numara VEYA sakin adi —
    // mobildeki `units/ara`), sakin SECILIR.
    const c = taklit({
      "/api/visitors": { items: [] },
      "/api/units/ara": [
        {
          id: "u-a12",
          no: "A-12",
          blok: "A",
          sakinler: [
            { user_id: "s-1", ad: "Ayşe Can" },
            { user_id: "s-2", ad: "Mehmet Can" },
          ],
        },
      ],
    });
    ciz(ZiyaretcilerPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni ziyaretçi girişi" }),
    );
    await userEvent.type(await screen.findByLabelText(/Ziyaretçi adı/i), "Ali Veli");
    await userEvent.type(screen.getByLabelText(/Daire no veya sakin adı/i), "Can");
    // SAKIN ADIYLA arama sunucuya gider (numara bilinmeyebilir).
    await userEvent.click(await screen.findByRole("button", { name: /A-12/ }));
    await waitFor(() =>
      expect(c.some((x) => x.url.startsWith("/api/units/ara?q=Can"))).toBe(true),
    );

    // Iki sakin var: SECILMEDEN kayit GONDERILMEZ.
    await userEvent.click(screen.getByRole("button", { name: /Girişi kaydet/i }));
    expect(await screen.findByText(/bildirileceği sakini seçin/i)).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);

    await userEvent.selectOptions(screen.getByLabelText(/Bildirilecek sakin/i), "s-2");
    await userEvent.click(screen.getByRole("button", { name: /Girişi kaydet/i }));
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.body).toMatchObject({
        unit_no: "A-12",
        target_resident_user_id: "s-2",
        ziyaretci_ad: "Ali Veli",
      });
    });
  });

  it("TEK SAKINLI dairede sakin OTOMATIK secilir", async () => {
    const c = taklit({
      "/api/visitors": { items: [] },
      "/api/units/ara": [
        { id: "u-b5", no: "B-5", blok: "B", sakinler: [{ user_id: "s-9", ad: "Zeynep" }] },
      ],
    });
    ciz(ZiyaretcilerPage);
    await userEvent.click(
      await screen.findByRole("button", { name: "Yeni ziyaretçi girişi" }),
    );
    await userEvent.type(await screen.findByLabelText(/Ziyaretçi adı/i), "Kurye");
    await userEvent.type(screen.getByLabelText(/Daire no veya sakin adı/i), "B-5");
    await userEvent.click(await screen.findByRole("button", { name: /B-5/ }));
    await userEvent.click(screen.getByRole("button", { name: /Girişi kaydet/i }));
    await waitFor(() => {
      const post = c.find((x) => x.method === "POST");
      expect(post?.body).toMatchObject({ unit_no: "B-5", target_resident_user_id: "s-9" });
    });
  });
});
