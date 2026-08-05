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
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AssetsPage from "@/app/(protected)/assets/page";
import DashboardPage from "@/app/(protected)/dashboard/page";
import PatrolsReportPage from "@/app/(protected)/reports/patrols/page";

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
  alarm_gruplari: [],
  aidat_tahsilat_orani: null,
  nfc_nokta_sayisi: 0,
};

const DEMIRBASLAR = {
  meta: { limit: 20, offset: 0, total: 1 },
  items: [{ id: "a1", ad: "Telsiz", kategori: "arac", nfc_tag_uid: null,
            durum: "musait", aciklama: null, aktif: true,
            created_at: "2026-01-01T00:00:00Z" }],
};

afterEach(() => vi.restoreAllMocks());

describe("Pano", () => {
  // (P133.2) PANO ARTIK PENCERE LISTESI CIZMIYOR: kahraman blok + tint
  // bloklar + gruplu alarmlar geldi, "Bugunku Turlar" tablosu kalkti
  // (onaylanan yonun bir parcasi: panoda kilcal izgara tablo yok).
  //
  // Bu yuzden TUR DURUMU cevirisi burada olculemez oldu — kayboLMASIN
  // diye `/reports/patrols`a tasindi (durum rozetini o sayfa ciziyor);
  // asagidaki test ALARM TIPI cevirisini panoda olcmeye devam ediyor.
  it("alarm tipi CEVRILIR (grup basliginda)", async () => {
    // Plan adi OLMAYAN grup: baslik tipin cevirisine duser — o yolun
    // cizildigini olcmenin tek yolu budur.
    fetchSahtele({
      "/api/dashboard/live": {
        ...PANO,
        alarm_gruplari: [
          {
            tip: "kacirilan_tur",
            patrol_plan_id: null,
            patrol_plan_ad: null,
            mesaj: "Tur kaçırıldı.",
            sayi: 1,
            en_son: "2026-02-01T06:05:00Z",
            onem: "yuksek",
            olaylar: [{ olusma_zamani: "2026-02-01T06:05:00Z" }],
          },
        ],
      },
    });
    ciz(DashboardPage);
    await waitFor(() =>
      expect(screen.getByText("kaçırılan tur")).toBeInTheDocument(),
    );
    // Ham enum SIZMAZ.
    expect(screen.queryByText("kacirilan_tur")).not.toBeInTheDocument();
  });
});

describe("Devriye raporu", () => {
  // (P133.2) Pano pencere listesini birakti; TUR DURUMU cevirisinin
  // kilidi buraya TASINDI — kapsam kaybolmasin diye. Olculen kural ayni:
  // taninan durum CEVRILIR, taninmayan HAM kalir (rozet bos kalmaz).
  it("tur durumu CEVRILIR; taninmayan durum HAM kalir", async () => {
    fetchSahtele({
      "/api/patrol-plans?limit=200&offset=0": {
        meta: { limit: 200, offset: 0, total: 1 },
        items: [{ id: "p1", ad: "Gece Turu", baslangic_saat: "00:00",
                  bitis_saat: "06:00", periyot_dakika: 60, aktif: true }],
      },
      "/api/patrol-windows": {
        meta: { limit: 20, offset: 0, total: 2 },
        ozet: { toplam: 2, tamamlandi: 0, kacirildi: 1, bekliyor: 1 },
        items: [
          { id: "w1", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
            pencere_baslangic: "2026-02-01T00:00:00Z",
            pencere_bitis: "2026-02-01T06:00:00Z", durum: "kacirildi" },
          { id: "w2", patrol_plan_id: "p1", patrol_plan_ad: "Gece Turu",
            pencere_baslangic: "2026-02-01T06:00:00Z",
            pencere_bitis: "2026-02-01T12:00:00Z", durum: "yeni_bir_durum" },
        ],
      },
    });
    ciz(PatrolsReportPage);
    // Sayfa suzgec GONDERILENE kadar liste istemez (`committed === null`).
    fireEvent.click(screen.getByRole("button", { name: /raporu getir|getir/i }));
    await waitFor(() =>
      expect(screen.getByText("kaçırıldı")).toBeInTheDocument(),
    );
    expect(screen.queryByText("kacirildi")).not.toBeInTheDocument();
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
