// @vitest-environment jsdom
// (P160 / Asama 6) NFC NOKTALARI ve DEVRIYE PLANLARI — tasima gerilemesi.
//
// Bu dosyanin en onemli testi sonuncu bolumde: devriye planinin nokta
// atamasi cekilemedigi halde cekmece BOS aciliyor ve "Kaydet" aktif
// kaliyordu. `PUT` tam listeyi degistirdigi icin bir tik, planin butun
// noktalarini SILIYORDU — devriye o gece bos kaliyordu ve hicbir yerde
// uyari yoktu. Test o kapiyi kilitliyor.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import CheckpointsPage from "@/app/(protected)/checkpoints/page";
import PatrolPlansPage from "@/app/(protected)/patrol-plans/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/checkpoints",
  useSearchParams: () => new URLSearchParams(),
}));

const NOKTA = {
  id: "c1",
  ad: "A blok giris",
  nfc_tag_uid: "04A1B2C3D4",
  gps_lat: 41.015137,
  gps_lng: 28.97953,
  aktif: true,
};

const PLAN = {
  id: "p1",
  ad: "Gece devriyesi",
  shift_id: "v1",
  baslangic_saat: "23:00",
  bitis_saat: "06:00",
  periyot_dakika: 60,
  aktif: true,
};

const VARDIYA = { id: "v1", ad: "Gece", baslangic_saat: "23:00", bitis_saat: "07:00", gun_tipi: "her_gun" };

type Cagri = { url: string; method: string; body?: unknown };

/**
 * Sahte uc. `atamaHatasi` true ise plan-nokta atamasi 500 doner —
 * gercek kusurun yasandigi durum.
 */
function sahte(opts: { atama?: string[]; atamaHatasi?: boolean } = {}) {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const method = init?.method ?? "GET";
    cagrilar.push({
      url,
      method,
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });

    if (/\/api\/patrol-plans\/[^/]+\/checkpoints/.test(url)) {
      if (method === "GET" && opts.atamaHatasi) {
        return {
          ok: false,
          status: 500,
          json: async () => ({ error: { message: "atama okunamadi" } }),
        } as Response;
      }
      if (method === "GET") {
        return {
          ok: true,
          status: 200,
          json: async () =>
            (opts.atama ?? ["c1"]).map((cid, i) => ({
              checkpoint_id: cid,
              sira: i,
            })),
        } as Response;
      }
      return { ok: true, status: 200, json: async () => ({}) } as Response;
    }

    const govde = url.includes("/api/patrol-plans")
      ? [PLAN]
      : url.includes("/api/shifts")
        ? [VARDIYA]
        : [NOKTA];
    return {
      ok: true,
      status: 200,
      json: async () => ({ meta: { limit: 25, offset: 0, total: govde.length }, items: govde }),
    } as Response;
  }) as typeof fetch;
  return cagrilar;
}

afterEach(() => vi.restoreAllMocks());

/* ==================================================================== */

describe("(P160) NFC Noktalari — tasima sonrasi", () => {
  it("liste cizilir; UID ve GPS korundu", async () => {
    sahte();
    ciz(CheckpointsPage);
    await waitFor(() => expect(screen.getByText("A blok giris")).toBeInTheDocument());
    expect(screen.getByText("04A1B2C3D4")).toBeInTheDocument();
    expect(screen.getByText("41.015137, 28.97953")).toBeInTheDocument();
  });

  it("form MODALDA acilir", async () => {
    sahte();
    ciz(CheckpointsPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni nokta" }));
    const modal = await screen.findByRole("dialog");
    expect(within(modal).getByRole("button", { name: "Kaydet" })).toBeInTheDocument();
  });

  it("GPS TURKCE YAZIMLA girilebilir ve koordinat KAYBOLMAZ (P56 korumasi)", async () => {
    const cagrilar = sahte();
    ciz(CheckpointsPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni nokta" }));
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText(/^Ad/), "Yeni");
    await userEvent.type(within(modal).getByLabelText(/NFC/), "0401");
    await userEvent.type(within(modal).getByLabelText(/enlem/i), "41,0082");
    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));

    // Eski `Number("41,0082")` NaN -> null idi: kullanici koordinati
    // SESSIZCE SILDIRIYORDU. `sayiCoz` virgulu ondalik ayirici sayar.
    await waitFor(() => {
      const post = cagrilar.find((c) => c.method === "POST");
      expect(post, "POST atilmadi").toBeTruthy();
      expect((post!.body as { gps_lat: unknown }).gps_lat).toBe(41.0082);
    });
  });

  it("YARIM koordinat (`41,`) SESSIZCE null'a cevrilmez — uyarir", async () => {
    const cagrilar = sahte();
    ciz(CheckpointsPage);
    await userEvent.click(await screen.findByRole("button", { name: "Yeni nokta" }));
    const modal = await screen.findByRole("dialog");
    await userEvent.type(within(modal).getByLabelText(/^Ad/), "Yeni");
    await userEvent.type(within(modal).getByLabelText(/NFC/), "0401");
    await userEvent.type(within(modal).getByLabelText(/enlem/i), "41,");
    await userEvent.click(within(modal).getByRole("button", { name: "Kaydet" }));

    await waitFor(() =>
      expect(within(modal).getByRole("alert")).toBeInTheDocument(),
    );
    expect(cagrilar.some((c) => c.method === "POST")).toBe(false);
  });

  it("UID tek aralikli yazi tipiyle cizilir (gozle karsilastirma)", async () => {
    sahte();
    ciz(CheckpointsPage);
    const uid = await screen.findByText("04A1B2C3D4");
    expect(uid.className).toContain("font-mono");
  });

  it("UC DUSTUGUNDE hata cikar, 'nokta yok' YAZMAZ", async () => {
    globalThis.fetch = (async () =>
      ({ ok: false, status: 500, json: async () => ({ error: { message: "sunucu" } }) }) as Response) as typeof fetch;
    ciz(CheckpointsPage);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Tekrar dene" })).toBeInTheDocument(),
    );
    expect(screen.queryByText(/Kayıtlı NFC noktası yok|Nokta yok/i)).toBeNull();
  });
});

/* ==================================================================== */

describe("(P160) Devriye Planlari — tasima sonrasi", () => {
  it("liste cizilir; vardiya ADI ve periyot korundu", async () => {
    sahte();
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    // Kimlik degil AD gosterilir.
    expect(screen.getByText("Gece")).toBeInTheDocument();
    expect(screen.getByText(/23:00–06:00/)).toBeInTheDocument();
  });

  it("nokta atamasi CEKMECEDE acilir ve mevcut sira yuklenir", async () => {
    sahte({ atama: ["c1"] });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(cekmece).getByText("A blok giris")).toBeInTheDocument(),
    );
  });

  it("KAYDET secilen SIRAYI gonderir", async () => {
    const cagrilar = sahte({ atama: ["c1"] });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(cekmece).getByText("A blok giris")).toBeInTheDocument(),
    );
    await userEvent.click(
      within(cekmece).getByRole("button", { name: "Atamayı kaydet" }),
    );
    await waitFor(() => {
      const put = cagrilar.find((c) => c.method === "PUT");
      expect(put, "PUT atilmadi").toBeTruthy();
      expect((put!.body as { items: unknown[] }).items).toEqual([
        { checkpoint_id: "c1", sira: 0 },
      ]);
    });
  });
});

/* ==================================================================== */

describe("(P160) KUSUR: atama okunamayinca KAYDETMEK plani BOSALTIYORDU", () => {
  it("atama cekilemezse SEBEP gorunur", async () => {
    sahte({ atamaHatasi: true });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(
        within(cekmece).getByRole("button", { name: "Tekrar dene" }),
      ).toBeInTheDocument(),
    );
  });

  it("atama cekilemezse KAYDET KAPALI — bos liste kaydedilemez", async () => {
    sahte({ atamaHatasi: true });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(
        within(cekmece).getByRole("button", { name: "Tekrar dene" }),
      ).toBeInTheDocument(),
    );
    expect(
      within(cekmece).getByRole("button", { name: "Atamayı kaydet" }),
    ).toBeDisabled();
  });

  it("kapali dugmeye tiklamak PUT ATMAZ (veri kaybi kapisi)", async () => {
    const cagrilar = sahte({ atamaHatasi: true });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(
        within(cekmece).getByRole("button", { name: "Tekrar dene" }),
      ).toBeInTheDocument(),
    );
    await userEvent.click(
      within(cekmece).getByRole("button", { name: "Atamayı kaydet" }),
    );
    expect(cagrilar.some((c) => c.method === "PUT")).toBe(false);
  });

  it("BOS atama (gercekten bos) kaydedilebilir — kusur duzeltmesi mesru islemi engellemedi", async () => {
    const cagrilar = sahte({ atama: [] });
    ciz(PatrolPlansPage);
    await waitFor(() => expect(screen.getByText("Gece devriyesi")).toBeInTheDocument());
    await userEvent.click(screen.getByRole("button", { name: "Noktalar" }));
    const cekmece = await screen.findByRole("dialog");
    const kaydet = within(cekmece).getByRole("button", { name: "Atamayı kaydet" });
    await waitFor(() => expect(kaydet).toBeEnabled());
    await userEvent.click(kaydet);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.method === "PUT")).toBe(true),
    );
  });
});
