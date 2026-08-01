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
