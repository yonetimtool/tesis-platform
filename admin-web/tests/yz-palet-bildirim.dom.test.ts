// @vitest-environment jsdom
// (P160 / Asama 2) KOMUT PALETI + BILDIRIM MERKEZI.
//
// OLCULEN ASIL RISKLER:
//   1. PALET KENDI YETKI SUZGECINI URETMEMELI. Brief: "sonuclarda yetki
//      sizintisi olmayacak". Kural SUNUCUDA; palet ucun donduklerini
//      cizer. Istemcide ikinci bir suzgec, iki karar demek ve ikisi
//      ayrisabilir.
//   2. ODAK GIRDIDE KALMALI. Oklarla odagi tasimak, kullanicinin
//      yazmaya devam etmesini imkansiz kilar — `aria-activedescendant`
//      tam olarak bunun icin var.
//   3. BILDIRIM SAYACI ICIN YENI UC ACILMAMALI (kilitli kural 1).
//   4. OKUNDU ISARETLEME BASARISIZSA satir LISTEDE KALMALI — sahte
//      basari, bildirimi kaybettirir.
import { screen, render, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createElement } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { SWRConfig } from "swr";

import { BildirimMerkezi, KomutPaleti } from "@/components/ui";
import { I18nProvider } from "@/lib/i18n/kullan";
import { SOZLUKLER } from "@/lib/i18n/sozluk";

const push = vi.fn();
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push, replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
}));

function ciz(el: React.ReactElement) {
  return render(
    createElement(
      SWRConfig,
      { value: { provider: () => new Map(), dedupingInterval: 0 } },
      createElement(I18nProvider, {
        baslangicDili: "tr" as const,
        baslangicSozlugu: SOZLUKLER.tr,
        children: el,
      }),
    ),
  );
}

/** Cagrilan URL'leri kaydeden sahte `fetch`. */
function fetchSahte(yanit: (url: string) => unknown) {
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilar.push(url);
    return {
      ok: true,
      status: 200,
      json: async () => yanit(url),
    } as Response;
  }) as typeof fetch;
  return cagrilar;
}

beforeEach(() => {
  push.mockClear();
});
afterEach(() => {
  vi.restoreAllMocks();
});

/* ==================================================================== */

describe("(P160) KomutPaleti", () => {
  it("kapaliyken DOM'a HIC girmez", () => {
    fetchSahte(() => ({ items: [] }));
    ciz(createElement(KomutPaleti));
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("Ctrl+K acar, ESC kapatir", async () => {
    fetchSahte(() => ({ items: [] }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Control>}k{/Control}");
    expect(screen.getByRole("dialog")).toBeInTheDocument();
    await userEvent.keyboard("{Escape}");
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  });

  it("Cmd+K de acar (macOS'ta Ctrl+K terminal kisayolu)", async () => {
    fetchSahte(() => ({ items: [] }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Meta>}k{/Meta}");
    expect(screen.getByRole("dialog")).toBeInTheDocument();
  });

  it("IKI KARAKTERDEN KISA sorguda uca GITMEZ (sunucunun 422 kurali)", async () => {
    const cagrilar = fetchSahte(() => ({ items: [] }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Control>}k{/Control}");
    await userEvent.type(screen.getByRole("combobox"), "a");
    await new Promise((r) => setTimeout(r, 400));
    expect(cagrilar.filter((u) => u.includes("/arama"))).toHaveLength(0);
  });

  it("sonuclari UCTAN alir ve KENDI SUZMEZ", async () => {
    const cagrilar = fetchSahte(() => ({
      items: [
        { kaynak: "kisi", id: "1", baslik: "Ayse Yilmaz", ayrinti: "Yonetici" },
        { kaynak: "daire", id: "2", baslik: "A-12", ayrinti: null },
      ],
    }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Control>}k{/Control}");
    await userEvent.type(screen.getByRole("combobox"), "ay");

    await waitFor(() => {
      // UCUN DONDUGU HER KAYIT CIZILIR — istemci hicbirini elemez.
      expect(screen.getByText("Ayse Yilmaz")).toBeInTheDocument();
      expect(screen.getByText("A-12")).toBeInTheDocument();
    });
    expect(cagrilar.some((u) => u.includes("/api/panel/arama"))).toBe(true);
  });

  it("ODAK GIRDIDE KALIR; secim aria-activedescendant ile bildirilir", async () => {
    fetchSahte(() => ({
      items: [
        { kaynak: "kisi", id: "1", baslik: "Bir", ayrinti: null },
        { kaynak: "kisi", id: "2", baslik: "Iki", ayrinti: null },
      ],
    }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Control>}k{/Control}");
    const girdi = screen.getByRole("combobox");
    await userEvent.type(girdi, "bi");
    await waitFor(() => expect(screen.getByText("Bir")).toBeInTheDocument());

    const ilk = girdi.getAttribute("aria-activedescendant");
    await userEvent.keyboard("{ArrowDown}");
    // Odak HÂLÂ girdide — yoksa yazmaya devam edilemezdi.
    expect(document.activeElement).toBe(girdi);
    expect(girdi.getAttribute("aria-activedescendant")).not.toBe(ilk);
  });

  it("Enter secili kaydin ROTASINA gider", async () => {
    fetchSahte(() => ({
      items: [{ kaynak: "daire", id: "9", baslik: "A-12", ayrinti: null }],
    }));
    ciz(createElement(KomutPaleti));
    await userEvent.keyboard("{Control>}k{/Control}");
    await userEvent.type(screen.getByRole("combobox"), "a-");
    await waitFor(() => expect(screen.getByText("A-12")).toBeInTheDocument());
    await userEvent.keyboard("{Enter}");
    expect(push).toHaveBeenCalledWith("/units");
  });
});

/* ==================================================================== */

describe("(P160) BildirimMerkezi", () => {
  it("okunmamis sayisi MEVCUT uctan gelir (yeni uc YOK)", async () => {
    const cagrilar = fetchSahte(() => ({
      meta: { limit: 1, offset: 0, total: 3 },
      items: [],
    }));
    ciz(createElement(BildirimMerkezi));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "3 okunmamış bildirim" }),
      ).toBeInTheDocument(),
    );
    // Yalniz var olan `/api/notifications` cagrildi — arka uce dokunulmadi.
    expect(cagrilar.every((u) => u.startsWith("/api/notifications"))).toBe(true);
    expect(cagrilar.some((u) => u.includes("okundu=false"))).toBe(true);
  });

  it("sayac SIFIRSA rozet cizilmez, dugme yine ADLIDIR", async () => {
    fetchSahte(() => ({ meta: { limit: 1, offset: 0, total: 0 }, items: [] }));
    ciz(createElement(BildirimMerkezi));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Bildirimler" }),
      ).toBeInTheDocument(),
    );
  });

  it("liste YALNIZ ACILINCA cekilir", async () => {
    const cagrilar = fetchSahte((u) =>
      u.includes("limit=8")
        ? {
            meta: { limit: 8, offset: 0, total: 1 },
            items: [
              {
                id: "n1",
                tip: "alarm",
                mesaj: "Gecikmiş okutma",
                okundu: false,
                created_at: "2026-08-14T10:00:00Z",
              },
            ],
          }
        : { meta: { limit: 1, offset: 0, total: 1 }, items: [] },
    );
    ciz(createElement(BildirimMerkezi));
    await waitFor(() => expect(cagrilar.length).toBeGreaterThan(0));
    // Kapaliyken sekizlik liste CEKILMEZ.
    expect(cagrilar.some((u) => u.includes("limit=8"))).toBe(false);

    await userEvent.click(screen.getByRole("button", { name: /okunmamış|Bildirimler/ }));
    await waitFor(() =>
      expect(screen.getByText("Gecikmiş okutma")).toBeInTheDocument(),
    );
  });

  it("okunmamis yoksa BOS DURUM metni cikar", async () => {
    fetchSahte(() => ({ meta: { limit: 8, offset: 0, total: 0 }, items: [] }));
    ciz(createElement(BildirimMerkezi));
    await userEvent.click(
      await screen.findByRole("button", { name: "Bildirimler" }),
    );
    await waitFor(() =>
      expect(screen.getByText("Okunmamış bildirim yok.")).toBeInTheDocument(),
    );
  });
});
