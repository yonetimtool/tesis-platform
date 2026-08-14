// @vitest-environment jsdom
// (P160 / Asama 6) BILDIRIMLER ve VARDIYALAR — tasima gerilemesi.
//
// KILITLI KURAL 2 odakli: gorunum degisti, DAVRANIS degismedi.
//
// Bildirimlerde ayrica bir ERISILEBILIRLIK KAZANIMI kilitleniyor: secili
// suzgec eskiden YALNIZ RENKLE anlatiliyordu ve ekran okuyucu hangisinin
// acik oldugunu soyleyemiyordu. Artik `aria-pressed` tasiyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import NotificationsPage from "@/app/(protected)/notifications/page";
import ShiftsPage from "@/app/(protected)/shifts/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/notifications",
  useSearchParams: () => new URLSearchParams(),
}));

const BILDIRIM = {
  id: "n1",
  tip: "gecikmis_okutma",
  mesaj: "A blok noktasi okutulmadi",
  okundu: false,
  created_at: "2026-08-14T10:00:00Z",
};

const VARDIYA = {
  id: "v1",
  ad: "Gece",
  baslangic_saat: "23:00",
  bitis_saat: "07:00",
  gun_tipi: "hepsi",
};

function sahte(items: unknown[], toplam?: number) {
  const cagrilar: { url: string; method: string; body?: unknown }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      method: init?.method ?? "GET",
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    return {
      ok: true,
      status: 200,
      json: async () => ({
        meta: { limit: 25, offset: 0, total: toplam ?? items.length },
        items,
      }),
    } as Response;
  }) as typeof fetch;
  return cagrilar;
}

function bozukUc() {
  globalThis.fetch = (async () =>
    ({
      ok: false,
      status: 500,
      json: async () => ({ error: { message: "sunucu" } }),
    }) as Response) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) Bildirimler — tasima sonrasi", () => {
  it("liste cizilir; okunmamis rozeti korundu", async () => {
    sahte([BILDIRIM]);
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("A blok noktasi okutulmadi")).toBeInTheDocument(),
    );
    expect(screen.getByText("yeni")).toBeInTheDocument();
  });

  it("SECILI SUZGEC ekran okuyucuya bildirilir (aria-pressed) — yeni kazanim", async () => {
    sahte([BILDIRIM]);
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("A blok noktasi okutulmadi")).toBeInTheDocument(),
    );
    // Baslangicta "Tümü" secili.
    expect(screen.getByRole("button", { name: "Tümü" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await userEvent.click(screen.getByRole("button", { name: "Okunmamış" }));
    expect(screen.getByRole("button", { name: "Okunmamış" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });

  it("SUZGEC istege yansir ve sayfayi SIFIRLAR", async () => {
    const cagrilar = sahte([BILDIRIM]);
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("A blok noktasi okutulmadi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Okunmamış" }));
    await waitFor(() =>
      expect(
        cagrilar.some((c) => c.url.includes("okundu=false") && c.url.includes("offset=0")),
      ).toBe(true),
    );
  });

  it("OKUNDU ISARETLEME `apiSend` ile gider (PATCH govdesi dogru)", async () => {
    const cagrilar = sahte([BILDIRIM]);
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("A blok noktasi okutulmadi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getByRole("button", { name: "Okundu" }));
    await waitFor(() => {
      const patch = cagrilar.find((c) => c.method === "PATCH");
      expect(patch, "PATCH atilmadi").toBeTruthy();
      expect((patch!.body as { okundu: boolean }).okundu).toBe(true);
    });
  });

  it("OKUNMUS bildirimde 'Okundu' dugmesi CIZILMEZ", async () => {
    sahte([{ ...BILDIRIM, okundu: true }]);
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByText("A blok noktasi okutulmadi")).toBeInTheDocument(),
    );
    expect(screen.queryByRole("button", { name: "Okundu" })).toBeNull();
    expect(screen.queryByText("yeni")).toBeNull();
  });

  it("UC DUSTUGUNDE hata + TEKRAR DENE, bos liste GOSTERILMEZ", async () => {
    bozukUc();
    ciz(NotificationsPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText("Bildirim yok.")).toBeNull();
  });
});

/* ==================================================================== */

describe("(P160) Vardiyalar — tasima sonrasi", () => {
  it("liste cizilir; saat araligi korundu", async () => {
    sahte([VARDIYA]);
    ciz(ShiftsPage);
    await waitFor(() => expect(screen.getByText("Gece")).toBeInTheDocument());
    expect(screen.getByText("23:00 – 07:00")).toBeInTheDocument();
  });

  it("form MODALDA acilir", async () => {
    sahte([VARDIYA]);
    ciz(ShiftsPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni vardiya" }));
    const modal = await screen.findByRole("dialog");
    expect(within(modal).getByRole("button", { name: "Kaydet" })).toBeInTheDocument();
  });

  it("GECE VARDIYASI uyarisi baslangic > bitis iken cikar (korundu)", async () => {
    sahte([VARDIYA]);
    ciz(ShiftsPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni vardiya" }));
    const modal = await screen.findByRole("dialog");

    // Once uyari YOK.
    expect(within(modal).queryByText(/ertesi gün|gece/i)).toBeNull();

    const bas = within(modal).getByLabelText(/Başlangıç/);
    const bit = within(modal).getByLabelText(/Bitiş/);
    await userEvent.clear(bas);
    await userEvent.type(bas, "23:00");
    await userEvent.clear(bit);
    await userEvent.type(bit, "07:00");

    await waitFor(() =>
      expect(within(modal).getByText(/ertesi gün|gece/i)).toBeInTheDocument(),
    );
  });

  it("SAYFA BASINA KAYIT secimi istege yansir (yeni kazanim)", async () => {
    const cagrilar = sahte([VARDIYA], 300);
    ciz(ShiftsPage);
    await waitFor(() => expect(screen.getByText("Gece")).toBeInTheDocument());
    await userEvent.selectOptions(screen.getByLabelText(/Sayfa başına/), "100");
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url.includes("limit=100"))).toBe(true),
    );
  });

  it("UC DUSTUGUNDE hata + TEKRAR DENE", async () => {
    bozukUc();
    ciz(ShiftsPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
  });
});
