// @vitest-environment jsdom
// (P181 Bölüm 9) REZERVASYON YÖNETİMİ — yönetim yüzeyi: ALAN yönetimi
// (liste + oluştur + pasifleştir) ve yönetim REZERVASYON listesi (iptal).
// Aynı veri modeli/uçlar; iş kuralları sunucuda (test yalnız UI akışını ölçer).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import RezervasyonYonetimiPage from "@/app/(protected)/rezervasyon-yonetimi/page";

import { cagrilanUrller, ciz, fetchSahtele } from "./yardimci";

const ALAN = {
  id: "a1", ad: "Toplantı Salonu", aciklama: "Zemin kat", aktif: true,
  acilis: "09:00", kapanis: "22:00", slot_dakika: 60,
};
const REZ = {
  id: "r1", alan_ad: "Toplantı Salonu", tarih: "2026-09-01",
  baslangic: "10:00", bitis: "11:00", kisi_sayisi: 4, durum: "onaylandi", gecmis: false,
};

afterEach(() => vi.restoreAllMocks());

describe("Rezervasyon yönetimi", () => {
  it("ALANLAR sekmesi alanları listeler + 'Yeni alan' ve 'Pasifleştir' sunar", async () => {
    fetchSahtele({
      "/api/common-areas": { items: [ALAN] },
      "/api/reservations": { items: [REZ] },
    });
    ciz(RezervasyonYonetimiPage);
    expect(await screen.findByText("Toplantı Salonu")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Yeni alan" })).toBeInTheDocument();
    // AKTİF alan için "Pasifleştir" (soft-delete) düğmesi.
    expect(screen.getByRole("button", { name: "Pasifleştir" })).toBeInTheDocument();
  });

  it("PASİFLEŞTİR alanın aktifliğini PATCH ile kapatır", async () => {
    fetchSahtele({
      "/api/common-areas": { items: [ALAN] },
      "/api/reservations": { items: [] },
    });
    ciz(RezervasyonYonetimiPage);
    await screen.findByText("Toplantı Salonu");
    await userEvent.click(screen.getByRole("button", { name: "Pasifleştir" }));
    await waitFor(() =>
      expect(cagrilanUrller().some((u) => u.includes("/api/common-areas/a1"))).toBe(true),
    );
  });

  it("REZERVASYONLAR sekmesi yönetim listesini gösterir (iptal düğmesiyle)", async () => {
    fetchSahtele({
      "/api/common-areas": { items: [ALAN] },
      "/api/reservations": { items: [REZ] },
    });
    ciz(RezervasyonYonetimiPage);
    await screen.findByText("Toplantı Salonu");
    // Sekme başlığına tıkla ("Rezervasyonlar"); yönetim listesi + iptal düğmesi.
    await userEvent.click(screen.getByRole("tab", { name: "Rezervasyonlar" }));
    expect(await screen.findByRole("button", { name: "İptal et" })).toBeInTheDocument();
  });
});
