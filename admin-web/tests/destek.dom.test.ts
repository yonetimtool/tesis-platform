// @vitest-environment jsdom
// (P60) HATA VARKEN "kayit yok" IDDIASI EDILMEZ.
//
// Destek sayfasi listeyi `!data || items.length === 0` ile bosa
// dusuruyordu. Istek dustugunde `data` tanimsizdir — yani sayfa
// **"Destek talebi yok"** diyordu, hemen ustundeki hata kutusuyla
// CELISEREK. "Yuklenemedi" ile "hic yok" ayri seylerdir: ikincisi bir
// IDDIADIR ve yanlis oldugunda kullanici bekleyen talebi gormez.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import SupportPage from "@/app/(protected)/support/page";

import { ciz, fetchSahtele } from "./yardimci";

const BOS = { meta: { limit: 20, offset: 0, total: 0 }, items: [] };
const DOLU = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "b1", tenant_id: "t1", tenant_ad: "Acme Plaza",
            konu: "Giriş sorunu", mesaj: "Giremiyorum", durum: "acik",
            admin_cevap: null, created_at: "2026-02-01T10:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Destek", () => {
  it("UC DUSTUGUNDE 'talep yok' YAZILMAZ, hata gorunur", async () => {
    fetchSahtele({});
    ciz(SupportPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText(/Destek talebi yok/i)).not.toBeInTheDocument();
  });

  it("hata metninde 'Error:' ONEKI OLMAZ", async () => {
    fetchSahtele({
      "/api/support": {
        __durum: 500,
        error: { code: "server_error", message: "Sunucu hatası." },
      },
    });
    ciz(SupportPage);
    await waitFor(() =>
      expect(screen.getByText("Sunucu hatası.")).toBeInTheDocument(),
    );
    expect(screen.queryByText(/^Error:/)).not.toBeInTheDocument();
  });

  it("GERCEKTEN bos liste icin 'talep yok' YAZILIR", async () => {
    fetchSahtele({ "/api/support": BOS });
    ciz(SupportPage);
    await waitFor(() =>
      expect(screen.getByText(/Destek talebi yok/i)).toBeInTheDocument(),
    );
  });

  it("dolu liste cizilir", async () => {
    fetchSahtele({ "/api/support": DOLU });
    ciz(SupportPage);
    await waitFor(() =>
      expect(screen.getByText("Giriş sorunu")).toBeInTheDocument(),
    );
    expect(screen.queryByText(/Destek talebi yok/i)).not.toBeInTheDocument();
  });
});
