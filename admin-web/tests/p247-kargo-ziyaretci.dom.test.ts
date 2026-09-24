// @vitest-environment jsdom
// (P247 §3) KARGO VE ZIYARETCI "BEKLIYOR"DA KALIYORDU — web yuzeyi.
//
// Sayfalar P129 geregi PARKTA (hicbir role acik degil); kod yine de
// sozlesmeyle ayni kalmali ki rol geri acildiginda kusur geri gelmesin.
// Olculen:
//  1. GUVENLIK bekleyen kargoda "Teslim et" gorur; secilen sakin PATCH
//     govdesine girer, secilmezse alan govdeye HIC yazilmaz.
//  2. Sunucunun `gecikmis` bayragi rozet olarak cizilir; suzgec
//     `?gecikmis=true` olarak GIDER (durum parametresine degil).
//  3. Firma bos ise POST gitmez (sunucu 422 veriyordu).
//  4. Ziyaretcide giris ani `created_at`ten okunur (tip `giris_zamani`
//     diyordu — sozlesmede yok); otomatik kapanan kayit "Cikis
//     kaydedilmedi" yazar ve cikis dugmesi gostermez.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import KargolarPage from "@/app/(protected)/kargolar/page";
import ZiyaretcilerPage from "@/app/(protected)/ziyaretciler/page";

import { ciz } from "./yardimci";

type Cagri = { url: string; method: string; body: unknown };

function taklit(harita: Record<string, unknown>): Cagri[] {
  const cagrilar: Cagri[] = [];
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
    const govde = anahtar === undefined ? { error: { message: "yok" } } : harita[anahtar];
    return new Response(JSON.stringify(govde), {
      status: anahtar === undefined ? 404 : 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

const BEKLEYEN = {
  id: "k1",
  unit_no: "A-1",
  firma: "Yurtiçi",
  notlar: null,
  durum: "bekliyor",
  gecikmis: true,
  created_at: "2026-09-20T09:00:00Z",
};

function kargoKur(rol: string, items: unknown[] = [BEKLEYEN]): Cagri[] {
  return taklit({
    "/api/me": { role: rol },
    "/api/kargo": { items, meta: { total: items.length } },
    "/api/units/ara": [
      {
        id: "u1",
        no: "A-1",
        blok: "A",
        sakinler: [
          { user_id: "r-1", ad: "Can Kiracı" },
          { user_id: "r-2", ad: "Zeynep Malik" },
        ],
      },
    ],
  });
}

describe("(P247 §3) kargo — guvenlik teslim eder", () => {
  it("GUVENLIK 'Teslim et' -> secilen sakin PATCH govdesinde", async () => {
    const c = kargoKur("security");
    ciz(KargolarPage);
    await userEvent.click(await screen.findByRole("button", { name: "Teslim et" }));
    const kutu = await screen.findByRole("dialog");
    const secim = within(kutu).getByRole("combobox");
    await waitFor(() =>
      expect(within(secim).getByRole("option", { name: "Zeynep Malik" })).toBeInTheDocument(),
    );
    await userEvent.selectOptions(secim, "r-2");
    await userEvent.click(within(kutu).getByRole("button", { name: "Teslim et" }));
    await waitFor(() => {
      const p = c.find((x) => x.method === "PATCH");
      expect(p?.url).toBe("/api/kargo/k1");
      expect(p?.body).toEqual({ durum: "teslim_alindi", teslim_alan_user_id: "r-2" });
    });
  });

  it("sakin secilmezse teslim_alan_user_id govdeye YAZILMAZ", async () => {
    const c = kargoKur("security");
    ciz(KargolarPage);
    await userEvent.click(await screen.findByRole("button", { name: "Teslim et" }));
    const kutu = await screen.findByRole("dialog");
    await userEvent.click(within(kutu).getByRole("button", { name: "Teslim et" }));
    await waitFor(() => {
      const p = c.find((x) => x.method === "PATCH");
      expect(p?.body).toEqual({ durum: "teslim_alindi" });
    });
  });

  it("SAKIN 'Teslim et' GORMEZ (o 'Teslim aldim' der)", async () => {
    kargoKur("resident");
    ciz(KargolarPage);
    expect(await screen.findByRole("button", { name: "Teslim aldım" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Teslim et" })).toBeNull();
  });

  it("gecikmis rozet cizilir; 'Gecikmiş' suzgeci ?gecikmis=true gonderir", async () => {
    const c = kargoKur("security");
    ciz(KargolarPage);
    expect(await screen.findByText("Gecikmiş", { selector: "span *, span" })).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText("Duruma göre süz"), "gecikmis");
    await waitFor(() =>
      expect(
        c.some((x) => x.url.startsWith("/api/kargo?") && x.url.includes("gecikmis=true")
          && !x.url.includes("durum=gecikmis")),
      ).toBe(true),
    );
  });

  it("firma bos ise POST GITMEZ", async () => {
    const c = kargoKur("security", []);
    ciz(KargolarPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni kargo teslim al" }));
    const kutu = await screen.findByRole("dialog");
    await userEvent.type(within(kutu).getByLabelText(/Daire no/i), "B-3");
    await userEvent.click(within(kutu).getByRole("button", { name: /Teslim al/i }));
    expect(await within(kutu).findByText("Kargo firması zorunludur.")).toBeInTheDocument();
    expect(c.some((x) => x.method === "POST")).toBe(false);
  });
});

describe("(P247 §3) ziyaretci — otomatik kapanis ve giris ani", () => {
  it("giris ani created_at'ten; otomatik kapanan kayit 'Cikis kaydedilmedi', dugmesiz", async () => {
    taklit({
      "/api/me": { role: "security" },
      "/api/visitors": {
        items: [
          {
            id: "v1",
            unit_no: "A-1",
            ziyaretci_ad: "Eski Misafir",
            notlar: null,
            created_at: "2026-09-22T09:00:00Z",
            cikis_zamani: "2026-09-23T10:00:00Z",
            cikis_otomatik: true,
          },
        ],
        meta: { total: 1 },
      },
    });
    ciz(ZiyaretcilerPage);
    expect(await screen.findByText("Çıkış kaydedilmedi")).toBeInTheDocument();
    expect(screen.queryByText(/Invalid Date|NaN/)).toBeNull();
    expect(screen.queryByText(/2026/)).not.toBeNull();
  });
});
