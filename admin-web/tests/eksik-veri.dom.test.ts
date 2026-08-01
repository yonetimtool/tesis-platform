// @vitest-environment jsdom
// (P58) IKINCIL ARAMA DUSTUGUNDE sayfa YANILTMAZ.
//
// Sayfalarin cogu ana listenin yaninda bir arama listesi ceker
// (vardiyalar, kullanicilar, kategoriler, daireler). O istegin hatasi
// HICBIR YERDE gorunmuyordu: acilir liste bos kaliyor ve "kayit yok"
// gibi okunuyordu; ad sutununda ise `3f2a91c8` gibi bir kimlik parcasi
// beliriyor ve VERI SANILIYORDU.
//
// Iki sey sabitlenir: (1) arama dustugunde uyari GORUNUR, (2) ad
// bulunamadiginda gosterilen sey ADA BENZEMEZ (`#` onekli).
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AssetsPage from "@/app/(protected)/assets/page";

import { ciz, fetchSahtele } from "./yardimci";

const DEMIRBASLAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "a1", ad: "Telsiz", kategori: "arac", nfc_tag_uid: null,
            durum: "zimmetli", aciklama: null, aktif: true,
            created_at: "2026-01-01T00:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Demirbaş — kullanıcı araması düştüğünde", () => {
  it("UYARI gorunur — sessizce bos liste GOSTERILMEZ", async () => {
    // `/api/users` haritada YOK => yardimci 404 doner.
    fetchSahtele({ "/api/assets": DEMIRBASLAR });
    ciz(AssetsPage);
    await waitFor(() => expect(screen.getByText("Telsiz")).toBeInTheDocument());
    await waitFor(() =>
      expect(screen.getByText(/seçenekler yüklenemedi/i)).toBeInTheDocument(),
    );
  });

  it("arama BASARILI iken uyari CIKMAZ", async () => {
    fetchSahtele({
      "/api/assets": DEMIRBASLAR,
      "/api/users": { meta: { limit: 200, offset: 0, total: 0 }, items: [] },
    });
    ciz(AssetsPage);
    await waitFor(() => expect(screen.getByText("Telsiz")).toBeInTheDocument());
    expect(screen.queryByText(/seçenekler yüklenemedi/i)).not.toBeInTheDocument();
  });
});

describe("kisaKimlik", () => {
  it("kimlik parcasi ADA BENZEMEZ", async () => {
    const { kisaKimlik } = await import("@/lib/kimlik");
    expect(kisaKimlik("3f2a91c8-1111-2222-3333-444444444444")).toBe("#3f2a91c8");
  });
});
