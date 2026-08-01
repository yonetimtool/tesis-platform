// @vitest-environment jsdom
// (P71) Şeffaflık panosu — para BICIMI ve hata/bos ayrimi.
//
// Bu sayfa P48'in ICU bulgusunun cikis noktasiydi: ayni tutari `TL` ile
// yazan ayri bir bicimlendiricisi vardi ve `toLocaleString` uzerinden
// ORTAMA bagimliydi. Artik tek kaynak `lib/money.ts`tir; test bunu
// SABITLER — geri donus sessiz olurdu (acik temada dogru gorunen bir
// sayi, kucuk-ICU'lu bir ortamda `5,000,00 ₺` olurdu).
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import TransparencyPage from "@/app/(protected)/transparency/page";

import { ciz, fetchSahtele } from "./yardimci";

const AYLAR = {
  items: [{ ay: "2026-01", yayinlandi: true, net_kurus: 125000 }],
};
const PANO = {
  ay: "2026-01",
  yayinlandi: true,
  toplam_gelir_kurus: 500000,
  toplam_gider_kurus: 375000,
  net_kurus: 125000,
  gider_dagilimi: [{ ad: "Temizlik", toplam_kurus: 375000, yuzde: 100 }],
  aidat: {
    tahakkuk_kurus: 500000, tahsilat_kurus: 400000, tutar_orani_yuzde: 80,
    toplam_daire: 10, odeyen_daire: 8, daire_orani_yuzde: 80,
    geciken_daire_sayisi: 2,
  },
  onceki_ay_net_kurus: null,
};

afterEach(() => vi.restoreAllMocks());

describe("Şeffaflık panosu", () => {
  it("para TEK BICIMDE yazilir (binlik nokta, ondalik virgul, ₺)", async () => {
    fetchSahtele({ "/api/transparency": AYLAR, "/api/transparency/2026-01": PANO });
    ciz(TransparencyPage);
    await waitFor(() =>
      expect(screen.getAllByText(/5\.000,00 ₺/).length).toBeGreaterThan(0),
    );
    // ESKI BICIM GERI GELMEZ: `TL` eki ve ondalik NOKTA yasak.
    expect(screen.queryByText(/5000\.00/)).not.toBeInTheDocument();
    expect(screen.queryByText(/5\.000,00 TL/)).not.toBeInTheDocument();
  });

  it("ay listesi DUSTUGUNDE hata gorunur, 'veri yok' YAZILMAZ", async () => {
    fetchSahtele({});
    ciz(TransparencyPage);
    await waitFor(() =>
      expect(screen.getByText(/yüklenemedi/i)).toBeInTheDocument(),
    );
    expect(screen.queryByText(/^Veri yok$/)).not.toBeInTheDocument();
  });

  it("GERCEKTEN bos listede 'veri yok' YAZILIR", async () => {
    fetchSahtele({ "/api/transparency": { items: [] } });
    ciz(TransparencyPage);
    await waitFor(() =>
      expect(screen.getByText(/^Veri yok$/)).toBeInTheDocument(),
    );
  });
});
