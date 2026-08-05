// @vitest-environment jsdom
// (P47) Pano, Daireler ve Tanimlar — kalan yuksek riskli sayfalar.
//
// Uc ayri hata sinifi: (1) panoda sayaclarin SUNUCU VERISINDEN turetilmesi
// (istemcide yeniden saymak, panoyla listenin ayrismasi demekti),
// (2) daire suzgecinin sayfayi BASA almasi, (3) tanimlar sayfasinda
// KURUS alanlarinin TL olarak cizilmesi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";
import TanimlarPage from "@/app/(protected)/tanimlar/page";
import UnitsPage from "@/app/(protected)/units/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

afterEach(() => vi.restoreAllMocks());

// ------------------------------- PANO --------------------------------- //
const CANLI = {
  generated_at: "2026-08-01T10:00:00Z",
  aktif_turlar: [
    { patrol_window_id: "w1", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
      pencere_baslangic: "2026-08-01T00:00:00Z", pencere_bitis: "2026-08-01T01:00:00Z",
      durum: "tamamlandi", beklenen_checkpoint_sayisi: 3, okutulan_checkpoint_sayisi: 3 },
    { patrol_window_id: "w2", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
      pencere_baslangic: "2026-08-01T01:00:00Z", pencere_bitis: "2026-08-01T02:00:00Z",
      durum: "kacirildi", beklenen_checkpoint_sayisi: 3, okutulan_checkpoint_sayisi: 1 },
    { patrol_window_id: "w3", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
      pencere_baslangic: "2026-08-01T02:00:00Z", pencere_bitis: "2026-08-01T03:00:00Z",
      durum: "bekliyor", beklenen_checkpoint_sayisi: 3, okutulan_checkpoint_sayisi: 0 },
  ],
  // (P133.3) Alarmlar GRUPLU geliyor.
  alarm_gruplari: [
    { tip: "kacirilan_tur", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
      mesaj: "Gece Turu kaçırıldı", sayi: 1, en_son: "2026-08-01T02:00:00Z",
      onem: "yuksek",
      olaylar: [{ olusma_zamani: "2026-08-01T02:00:00Z", patrol_window_id: "w2" }] },
  ],
  aidat_tahsilat_orani: 64,
  nfc_nokta_sayisi: 9,
};

describe("Pano", () => {
  it("SAYACLAR sunucu verisinden turetilir (istemcide yeniden sayilmaz)", async () => {
    fetchSahtele({ "/api/dashboard/live": CANLI });
    ciz(DashboardPage);
    // (P133.2) Pano artik pencere LISTESI cizmiyor; sayilar tint
    // bloklarda ozetleniyor. Olculen kural AYNI: sayilar sunucudan gelen
    // kumeden turer.
    //   3 pencere -> "Bugunku tur" = 3
    //   1 tamamlandi -> "Tamamlanan tur" = 1
    //   tahsilat orani sunucudan -> %64
    await waitFor(() => expect(screen.getByText("%64")).toBeInTheDocument());
    expect(screen.getAllByText("3").length).toBeGreaterThan(0);
    // Alarm da SUNUCUDAN gelen metinle cizilir: panelde yeniden cumle
    // kurmak, sunucunun dil katalogunu atlamak olurdu.
    expect(document.body.textContent ?? "").toContain("Gece Turu kaçırıldı");
  });

  it("UC DUSTUGUNDE hata gorunur — bos pano GOSTERILMEZ", async () => {
    fetchSahtele({});
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText("Gece Turu")).not.toBeInTheDocument();
  });
});

// ------------------------------ DAIRELER ------------------------------- //
const DAIRELER = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "u1", no: "A-1", blok: "A", kat: 1, sira: 1, metrekare: 120,
            aktif: true, created_at: "2026-01-01T00:00:00Z" }],
};

describe("Daireler", () => {
  it("BLOK suzgeci istegi yeniler ve sayfayi BASA alir", async () => {
    // Eski offset'te kalmak, suzgec sonrasi ilk sayfasi bos gorunen bir
    // liste demekti.
    fetchSahtele({ "/api/units": DAIRELER });
    ciz(UnitsPage);
    await waitFor(() => expect(screen.getByText("A-1")).toBeInTheDocument());

    await userEvent.type(screen.getByLabelText(/Blok/), "B");
    await waitFor(() =>
      expect(cagrilanUrller().some((u) => u.includes("blok=B"))).toBe(true),
    );
    expect(
      cagrilanUrller().some((u) => u.includes("blok=B") && u.includes("offset=0")),
    ).toBe(true);
  });
});

// ------------------------------ TANIMLAR ------------------------------- //
const KASALAR = {
  items: [{ id: "k1", kod: "MERKEZ", ad: "Merkez Kasa",
            acilis_bakiye_kurus: 500000, banka_mi: false, aktif: true }],
};

describe("Tanimlar", () => {
  it("KURUS alani TL olarak cizilir", async () => {
    // Defter tanimlari veri-suruculudur; `kurus` tipi alanin TL'ye
    // cevrilmemesi, 500000 kurusun ekranda "500000" gorunmesi demekti.
    fetchSahtele({ "/api/tanimlar/kasalar": KASALAR });
    ciz(TanimlarPage);
    await waitFor(() => expect(screen.getByText("Merkez Kasa")).toBeInTheDocument());
    expect(screen.getAllByText(/5\.000,00/).length).toBeGreaterThan(0);
  });

  it("SEKME degisince O DEFTERIN ucu cagrilir", async () => {
    fetchSahtele({
      "/api/tanimlar/kasalar": KASALAR,
      "/api/tanimlar/firmalar": { items: [] },
    });
    ciz(TanimlarPage);
    await waitFor(() => expect(screen.getByText("Merkez Kasa")).toBeInTheDocument());

    await userEvent.click(screen.getByRole("button", { name: "Firmalar" }));
    await waitFor(() =>
      expect(cagrilanUrller().some((u) => u.includes("/api/tanimlar/firmalar"))).toBe(true),
    );
  });
});
