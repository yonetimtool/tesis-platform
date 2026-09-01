// @vitest-environment jsdom
// (P193 §7) BILDIRIM TANILAMA (eksik 5) ve ODEME KODLARI (eksik 10).
//
// Rehberde iki eksik:
//   5. "Sakine bildirim gitmiyor" sikayetinde yoneticinin bakabilecegi
//      HICBIR ekran yoktu; kisinin kendi ayarina bakmasi gerekiyordu.
//  10. Havale kodu sakinin uygulamasinda gorunuyordu ama yonetici
//      goremiyordu — yani "aciklamaya kodunuzu yazin" diye DUYURAMIYORDU.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import UsersPage from "@/app/(protected)/users/page";

import { ciz, fetchSahtele } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/users",
  useSearchParams: () => new URLSearchParams(),
}));

const SAKIN = {
  id: "cccccccc-0000-0000-0000-000000000001",
  ad: "Acme Sakin", email: "sakin@acme.com", role: "resident",
  is_active: true, created_at: "2026-01-01T00:00:00Z",
};

const DETAY = {
  ...SAKIN,
  telefon: "+905321112233", aranabilir: false, kayit_tamamlandi: true,
  daire_id: null,
  eposta_dogrulandi: false,
  bildirim_eposta: true, bildirim_sms: false, bildirim_mobil: true,
  mobil_cihaz_sayisi: 0,
  odeme_kodu: "TS-ABC123",
};

function kur() {
  fetchSahtele({
    "/api/users/odeme-kodlari": {
      uretilen: 2,
      items: [
        { user_id: SAKIN.id, ad: "Acme Sakin", daire_no: "A-1", odeme_kodu: "TS-ABC123" },
        { user_id: "x2", ad: "Ali Veli", daire_no: null, odeme_kodu: "TS-XYZ789" },
      ],
    },
    [`/api/users/${SAKIN.id}`]: DETAY,
    "/api/users": { meta: { total: 1 }, items: [SAKIN] },
    "/api/units": { meta: { total: 0 }, items: [] },
    "/api/blocks": { items: [] },
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P193 §7) bildirim tanılama", () => {
  it("DUZENLEMEDE kanal tercihleri, cihaz sayisi ve odeme kodu GORUNUR", async () => {
    kur();
    ciz(UsersPage);
    await userEvent.click(
      (await screen.findAllByRole("button", { name: /Düzenle/ }))[0],
    );
    const diyalog = await screen.findByRole("dialog");
    await waitFor(() =>
      expect(within(diyalog).getByText(/Bildirim tanılama/)).toBeInTheDocument(),
    );
    expect(within(diyalog).getByText(/SMS bildirimi/)).toBeInTheDocument();
    expect(within(diyalog).getByText(/Kayıtlı cihaz/)).toBeInTheDocument();
    expect(within(diyalog).getByText("TS-ABC123")).toBeInTheDocument();
    // ASIL TESHIS: tercih ACIK ama cihaz YOK -> bildirim gitmez, ve
    // sebebi acikca yazilir. Bu satir olmadan yonetici "acik gorunuyor,
    // neden gitmiyor" dongusunde kalirdi.
    expect(
      within(diyalog).getByText(/kayıtlı cihaz yok/i),
    ).toBeInTheDocument();
  });

  it("ODEME KODLARI listesi POST ile alinir ve daire ile gosterilir", async () => {
    kur();
    const cagrilar: { yol: string; metot: string }[] = [];
    const onceki = globalThis.fetch;
    globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
      if (init?.method && init.method !== "GET") {
        cagrilar.push({ yol: String(g), metot: init.method });
      }
      return onceki(g, init);
    }) as typeof fetch;

    ciz(UsersPage);
    await userEvent.click(
      await screen.findByRole("button", { name: /Ödeme kodları/ }),
    );
    await waitFor(() => expect(cagrilar.length).toBe(1));
    // POST cunku uc YAZAR: eksik kodlari uretir.
    expect(cagrilar[0]).toEqual({
      yol: "/api/users/odeme-kodlari", metot: "POST",
    });
    const diyalog = await screen.findByRole("dialog");
    expect(await within(diyalog).findByText("TS-XYZ789")).toBeInTheDocument();
    // Daire numarasi da gorunur: ayni isimli iki sakin ayirt edilemezdi.
    expect(within(diyalog).getByText(/A-1 · Acme Sakin/)).toBeInTheDocument();
  });
});
