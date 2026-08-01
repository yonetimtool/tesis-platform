// @vitest-environment jsdom
// (P53) Tel degeri EKRANA CIKMAZ — davranis tarafi.
//
// `tests/ham-enum.test.ts` sizintiyi KAYNAKTA arar; buradaki testler
// cizimin gercekten cevirdigini ve TANINMAYAN degerde rozetin BOS
// KALMADIGINI gosterir. Ikisi ayri sey: kilit yeni bir sizintiyi
// engeller, bu testler kuralin kendisini sabitler.
//
// SECILEN DEGERLER BILINCLI: Turkce karsiligi tel degeriyle AYNI olan
// degerler (`zimmetli`, `ekipman`, `bekliyor`) bu testte hicbir sey
// kanitlamaz — cevrilmemis olsa da gecerdi. Bu yuzden ayristigi
// degerler secildi: `kacirildi`→"kaçırıldı", `musait`→"müsait",
// `arac`→"araç".
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AssetsPage from "@/app/(protected)/assets/page";
import DashboardPage from "@/app/(protected)/dashboard/page";

import { ciz, fetchSahtele } from "./yardimci";

const PANO = {
  generated_at: "2026-02-01T10:00:00Z",
  aktif_turlar: [
    { patrol_window_id: "w1", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
      pencere_baslangic: "2026-02-01T00:00:00Z", pencere_bitis: "2026-02-01T06:00:00Z",
      durum: "kacirildi", beklenen_checkpoint_sayisi: 4, okutulan_checkpoint_sayisi: 1 },
    { patrol_window_id: "w2", patrol_plan_id: "p1", patrol_plan_ad: "Gündüz Turu",
      pencere_baslangic: "2026-02-01T08:00:00Z", pencere_bitis: "2026-02-01T14:00:00Z",
      durum: "yeni_bir_durum", beklenen_checkpoint_sayisi: 4, okutulan_checkpoint_sayisi: 4 },
  ],
  son_alarmlar: [
    { tip: "kacirilan_tur", olusma_zamani: "2026-02-01T06:05:00Z", mesaj: "Tur kaçırıldı." },
  ],
};

const DEMIRBASLAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "a1", ad: "Telsiz", kategori: "arac", nfc_tag_uid: null,
            durum: "musait", aciklama: null, aktif: true,
            created_at: "2026-01-01T00:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Pano", () => {
  it("tur durumu ve alarm tipi CEVRILIR; taninmayan durum HAM kalir", async () => {
    fetchSahtele({ "/api/dashboard/live": PANO });
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Gece Turu")).toBeInTheDocument());

    expect(screen.getByText("kaçırıldı")).toBeInTheDocument();
    expect(screen.queryByText("kacirildi")).not.toBeInTheDocument();
    // Alarm rozeti bildirimler sayfasiyla AYNI haritayi kullanir.
    expect(screen.getByText("kaçırılan tur")).toBeInTheDocument();
    // Sunucu yeni bir durum eklerse rozet BOS KALMAZ.
    expect(screen.getByText("yeni_bir_durum")).toBeInTheDocument();
  });
});

describe("Demirbaş", () => {
  it("kategori ve durum CEVRILIR", async () => {
    fetchSahtele({
      "/api/assets": DEMIRBASLAR,
      "/api/users": { meta: { limit: 200, offset: 0, total: 0 }, items: [] },
    });
    ciz(AssetsPage);
    await waitFor(() => expect(screen.getByText("Telsiz")).toBeInTheDocument());
    expect(screen.getByText("müsait")).toBeInTheDocument();
    expect(screen.getByText("araç")).toBeInTheDocument();
  });
});
