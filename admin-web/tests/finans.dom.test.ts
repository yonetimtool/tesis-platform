// @vitest-environment jsdom
// (P43) Finans sayfasi — BILESEN testi (jsdom).
//
// Olculen sey "sayfa aciliyor mu" degil: PARA nasil cizilir, HATA sessiz
// kaliyor mu, ve YON isareti dogru mu. Ucuncusu onemli cunku P29'un karari
// geregi tutar HER ZAMAN POZITIFTIR; isaret `yon` alanindan gelir ve bu
// mantik yalnizca burada, cizim katmaninda yasar.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import FinansPage from "@/app/(protected)/finans/page";

import { ciz, fetchSahtele } from "./yardimci";

const OZET = {
  borclandirilan_ay_kurus: 150000,
  tahsil_edilen_ay_kurus: 100000,
  acik_borc_kurus: 50000,
  kasa_toplam_kurus: 250000,
  icra_acik_dosya: 2,
};
const KASALAR = {
  items: [{ kasa_id: "k1", kod: "MERKEZ", ad: "Merkez Kasa", bakiye_kurus: 250000 }],
  genel_toplam_kurus: 250000,
};
const HAREKETLER = {
  meta: { limit: 20, offset: 0, total: 2 },
  items: [
    {
      id: "h1", tip: "tahsilat", yon: "giris", tutar_kurus: 100000,
      tarih: "2026-08-01T10:00:00Z", kasa_ad: "Merkez Kasa",
      user_ad: "Ali Veli", belge_no: null, aciklama: "Aidat",
    },
    {
      id: "h2", tip: "gider", yon: "cikis", tutar_kurus: 25000,
      tarih: "2026-08-01T11:00:00Z", kasa_ad: "Merkez Kasa",
      user_ad: null, belge_no: "F-1", aciklama: null,
    },
  ],
};

afterEach(() => vi.restoreAllMocks());

describe("Finans sayfasi", () => {
  it("ozet, kasa ve hareketleri cizer; PARA kurustan TL'ye cevrilir", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);

    // 250000 kurus = 2.500,00 TL — panelde kurus GOSTERILMEZ.
    await waitFor(() => expect(screen.getAllByText(/2\.500,00/).length).toBeGreaterThan(0));
    expect(screen.getAllByText("Merkez Kasa").length).toBeGreaterThan(0);
    expect(screen.getByText("Ali Veli")).toBeInTheDocument();
  });

  it("YON isareti: giris +, cikis −  (tutar her zaman POZITIF)", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": KASALAR,
      "/api/panel/finans-hareketler": HAREKETLER,
    });
    ciz(FinansPage);

    await waitFor(() => expect(screen.getAllByText(/\+1\.000,00/).length).toBeGreaterThan(0));
    // U+2212 (matematiksel eksi) — ASCII tire DEGIL.
    expect(screen.getAllByText(/−250,00/).length).toBeGreaterThan(0);
  });

  it("UC DUSTUGUNDE hata gorunur — 'kayit yok' GOSTERILMEZ", async () => {
    // Bu ayrim tur 42'de bulunmustu: bos liste ile dusen uc ayni ekrani
    // veriyordu ve kullanici kasanin bos oldugunu saniyordu.
    fetchSahtele({ "/api/panel/finans-ozet": OZET });
    ciz(FinansPage);

    await waitFor(() =>
      expect(screen.getByText("Hareketler alınamadı.")).toBeInTheDocument(),
    );
    expect(screen.queryByText("Hareket yok")).not.toBeInTheDocument();
  });

  it("KASA YOKSA yonlendirici bos durum cizilir", async () => {
    fetchSahtele({
      "/api/panel/finans-ozet": OZET,
      "/api/panel/kasa-bakiyeleri": { items: [], genel_toplam_kurus: 0 },
      "/api/panel/finans-hareketler": { meta: { limit: 20, offset: 0, total: 0 }, items: [] },
    });
    ciz(FinansPage);

    await waitFor(() =>
      expect(screen.getByText("Kasa tanımlanmamış")).toBeInTheDocument(),
    );
    // Bos durum KULLANICIYA NE YAPACAGINI soyler.
    expect(screen.getByText(/Tanımlar sayfasından/)).toBeInTheDocument();
  });
});
