// @vitest-environment jsdom
// (P72) Duyurular — "düzenlendi" eki ve hata/boş ayrımı.
//
// Duyuru satirinda `updated_at !== created_at` ise "(duzenlendi)" eki
// cikar. Bu KUCUK ama ANLAMLI bir isarettir: sakin, okudugu duyurunun
// sonradan degistigini ancak buradan anlar. Sunucu her PATCH'te
// `updated_at`i tazeler; ek yanlis kosullanirsa ya HIC cikmaz (degisiklik
// gizlenir) ya da HER duyuruda cikar (isaret anlamsizlasir).
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AnnouncementsPage from "@/app/(protected)/announcements/page";

import { ciz, fetchSahtele } from "./yardimci";

const T0 = "2026-02-01T10:00:00Z";
const T1 = "2026-02-02T11:00:00Z";

function liste(items: unknown[]) {
  return { meta: { limit: 20, offset: 0, total: items.length }, items };
}
const DUYURU = {
  id: "d1", baslik: "Su kesintisi", govde: "Yarın 09:00-12:00",
  foto_key: null, foto_url: null, olusturan_user_id: "u1",
  olusturan_ad: "Ayşe Yönetici", created_at: T0, updated_at: T0,
};

afterEach(() => vi.restoreAllMocks());

describe("Duyurular", () => {
  it("DEGISMEMIS duyuruda 'duzenlendi' eki CIKMAZ", async () => {
    fetchSahtele({ "/api/announcements": liste([DUYURU]) });
    ciz(AnnouncementsPage);
    await waitFor(() =>
      expect(screen.getByText("Su kesintisi")).toBeInTheDocument(),
    );
    expect(screen.queryByText(/düzenlendi/i)).not.toBeInTheDocument();
  });

  it("DEGISMIS duyuruda 'duzenlendi' eki CIKAR", async () => {
    fetchSahtele({
      "/api/announcements": liste([{ ...DUYURU, updated_at: T1 }]),
    });
    ciz(AnnouncementsPage);
    await waitFor(() =>
      expect(screen.getByText(/düzenlendi/i)).toBeInTheDocument(),
    );
  });

  it("UC DUSTUGUNDE hata gorunur, 'duyuru yok' YAZILMAZ", async () => {
    fetchSahtele({});
    ciz(AnnouncementsPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText(/Duyuru yok/i)).not.toBeInTheDocument();
  });

  it("GERCEKTEN bos listede 'duyuru yok' YAZILIR", async () => {
    fetchSahtele({ "/api/announcements": liste([]) });
    ciz(AnnouncementsPage);
    await waitFor(() =>
      expect(screen.getByText(/Duyuru yok/i)).toBeInTheDocument(),
    );
  });
});

// (E2E 2026-09, BILDIRIM-12) HEDEF KITLE. Eskiden duyuru herkese gidiyordu;
// form hedef sormuyordu. Kilit: (1) secilen hedef POST govdesine girer,
// (2) personel-yalniz secimde blok/sakin tipi GOVDEDEN temizlenir (gizli
// suzgec kalmaz), (3) hedefli duyuru listede rozetle gorunur.
describe("Duyuru hedef kitlesi (BILDIRIM-12)", () => {
  function sahteFetch(govdeler: unknown[]) {
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      const json = (v: unknown, status = 200) =>
        new Response(JSON.stringify(v), {
          status,
          headers: { "Content-Type": "application/json" },
        });
      if (init?.method === "POST" && url.startsWith("/api/announcements")) {
        govdeler.push(JSON.parse(String(init.body)));
        return json({ ...DUYURU, id: "yeni" }, 201);
      }
      if (url.startsWith("/api/blocks")) {
        return json({ items: [{ id: "b1", ad: "A", unit_sayisi: 3, created_at: T0 }] });
      }
      if (url.startsWith("/api/announcements")) return json(liste([]));
      return json({ error: { message: "yok" } }, 404);
    }) as typeof fetch;
  }

  it("secilen BLOK ve SAKIN TIPI POST govdesine girer", async () => {
    const { default: userEvent } = await import("@testing-library/user-event");
    const govdeler: Record<string, unknown>[] = [];
    sahteFetch(govdeler);
    const { container } = ciz(AnnouncementsPage);
    await userEvent.click((await screen.findAllByRole("button", { name: "Yeni duyuru" }))[0]);
    await userEvent.type(screen.getByLabelText(/Başlık/), "Su");
    await userEvent.type(screen.getByLabelText(/Duyuru metni/), "Kesinti");
    await waitFor(() =>
      expect(container.ownerDocument.querySelector('[data-test="duyuru-blok-A"]')).not.toBeNull(),
    );
    await userEvent.click(container.ownerDocument.querySelector('[data-test="duyuru-blok-A"]')!);
    await userEvent.selectOptions(
      container.ownerDocument.querySelector('[data-test="duyuru-sakin-tipi"]')!,
      "malik",
    );
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(govdeler).toHaveLength(1));
    expect(govdeler[0]).toMatchObject({
      hedef_roller: [],
      hedef_sakin_tipi: "malik",
      hedef_bloklar: ["A"],
    });
  });

  it("YALNIZ PERSONEL secilince blok/sakin tipi govdeden TEMIZLENIR", async () => {
    const { default: userEvent } = await import("@testing-library/user-event");
    const govdeler: Record<string, unknown>[] = [];
    sahteFetch(govdeler);
    const { container } = ciz(AnnouncementsPage);
    const doc = container.ownerDocument;
    await userEvent.click((await screen.findAllByRole("button", { name: "Yeni duyuru" }))[0]);
    await userEvent.type(screen.getByLabelText(/Başlık/), "Toplanti");
    await userEvent.type(screen.getByLabelText(/Duyuru metni/), "Saat 9");
    await waitFor(() => expect(doc.querySelector('[data-test="duyuru-blok-A"]')).not.toBeNull());
    await userEvent.click(doc.querySelector('[data-test="duyuru-blok-A"]')!);
    await userEvent.click(doc.querySelector('[data-test="duyuru-hedef-security"]')!);
    // sakin suzgeci anlamsiz -> gizlendi
    expect(doc.querySelector('[data-test="duyuru-blok-A"]')).toBeNull();
    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(govdeler).toHaveLength(1));
    expect(govdeler[0]).toMatchObject({
      hedef_roller: ["security"],
      hedef_sakin_tipi: null,
      hedef_bloklar: [],
    });
  });

  it("HEDEFLI duyuru listede rozetle, hedefsiz rozetsiz", async () => {
    fetchSahtele({
      "/api/announcements": liste([
        { ...DUYURU, id: "h1", baslik: "Hedefli", hedef_roller: [], hedef_bloklar: ["A"], hedef_sakin_tipi: "malik" },
        { ...DUYURU, id: "h2", baslik: "Herkese", hedef_roller: [], hedef_bloklar: [] },
      ]),
    });
    const { container } = ciz(AnnouncementsPage);
    await waitFor(() => expect(screen.getByText("Hedefli")).toBeInTheDocument());
    const rozetler = container.querySelectorAll('[data-test="duyuru-hedef-rozet"]');
    expect(rozetler).toHaveLength(1);
    expect(rozetler[0].textContent).toContain("Blok: A");
    expect(rozetler[0].textContent).toContain("Yalnız malikler");
  });
});
