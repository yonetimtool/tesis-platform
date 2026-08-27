// @vitest-environment jsdom
// (P160) PANO OLCU SINIRI — DIL DEGISTI, KURAL KALDI.
//
// P133.2'nin kurali soyleydi: "ekran basina en cok 1 kahraman + 4 ikincil
// TINT BLOK. Renk SINYAL kalmali; alti tintli ekran gurultudur."
//
// P160 brief'i tint blok dilini ACIKCA TERK ETTI ("renkli dolgu bloklar
// yerine metalik yuzeyler; renk yalnizca durum sinyali olarak kalacak").
// Ikincil bloklar artik METALIK KPI HALKASI.
//
// BU DOSYA SILINMEDI ve bu bilincli: kilidin KORUDUGU SEY dil degil
// OLCUDUR — "bir ekranda en cok dort ikincil gosterge". O kural yeni
// dilde de gecerli ve ayni sekilde sessizce asilabilir. Testler diline
// gore degil, KORUDUKLARI KURALA gore yasar.
//
// NE OLCULMEZ: renklerin GUZEL olup olmadigi. Olculen sey SAYI ve
// erisilebilirlik sozlesmesi.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";

import { ciz } from "./yardimci";

const TUR = {
  patrol_window_id: "w1",
  patrol_plan_id: "p1",
  patrol_plan_ad: "Gece turu",
  pencere_baslangic: "2026-08-04T22:00:00Z",
  pencere_bitis: "2026-08-04T23:00:00Z",
  durum: "bekliyor",
  okutulan_checkpoint_sayisi: 2,
  beklenen_checkpoint_sayisi: 5,
};

function fetchTaklidi(tahsilat: number | null = 78) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    const govde = url.includes("/api/dashboard/live")
      ? {
          generated_at: "2026-08-04T22:30:00Z",
          aktif_turlar: [TUR],
          alarm_gruplari: [],
          aidat_tahsilat_orani: tahsilat,
          nfc_nokta_sayisi: 12,
        }
      : url.includes("/api/cameras")
        ? { meta: { limit: 50, offset: 0, total: 0 }, items: [] }
        : url.includes("/api/tenant/settings")
          ? { konum_lat: 41.01, konum_lon: 28.97, ad: "Acme" }
          : {};
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

// Tint zeminli bloklar: %12 vurgu zemini tasiyan kaplar.
//
// NOT: sinif orneginin JSDoc yorumunda YAZILAMAZ — icindeki yildiz-egik
// ikilisi blok yorumu erken kapatir ve dosya derlenmez (bu tur bir kez
// dusuruldu).
function tintBloklar(kok: HTMLElement): Element[] {
  return [...kok.querySelectorAll("[class]")].filter((el) => {
    const c = el.getAttribute("class") ?? "";
    // Ikon KUTUSU da tint tasir (56px kare) ama BLOK degildir; yaricapiyla
    // ayrilir: bloklar `rounded-kart`/`rounded-blok`, ikon kutusu
    // `rounded-ikon`, cip `rounded-chip`.
    return (
      /bg-accent-\w+\/12/.test(c) &&
      (c.includes("rounded-kart") || c.includes("rounded-blok"))
    );
  });
}

afterEach(() => vi.restoreAllMocks());

describe("(P133.2) SERT SINIR — 1 kahraman + 4 ikincil", () => {
  it("IKINCIL GOSTERGE (KPI halkasi) EN COK 4", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    // KPI halkalari `sr-only` metinlerinden sayilir: "<etiket>: <deger>".
    // Gorsel secici yerine ERISILEBILIR AD kullanmak, hem sayimi hem
    // erisilebilirligi ayni anda olcer.
    const halkalar = screen.getAllByText(/^[^:]+: \d+%?$/);
    expect(halkalar.length).toBeLessThanOrEqual(4);
    expect(halkalar.length).toBeGreaterThanOrEqual(3);
  });

  it("MALI HALKA dususe de sinir korunur (3 ikincil)", async () => {
    // Tahsilat `null` (guvenlik rolu): halka HIC cizilmez.
    fetchTaklidi(null);
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    const halkalar = screen.getAllByText(/^[^:]+: \d+%?$/);
    expect(halkalar.length).toBe(3);
    expect(screen.queryByText(/Tahsilat/)).toBeNull();
  });

  it("HALKA DEKORATIF, gercek deger sr-only metinde", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    // Sayan rakam ekran okuyucuya OKUNMAZ (aria-hidden); okunan tek sey
    // "<etiket>: <deger>".
    expect(container.querySelectorAll('[aria-hidden="true"]').length).toBeGreaterThan(0);
    expect(screen.getByText(/^Geciken okutma: \d+$/)).toBeInTheDocument();
  });

  it("KPI halkasi BAGLANTIDIR (dugme degil) — yeni sekmede acilabilsin", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    // Baglanti: orta tikla yeni sekme, ekran okuyucu "baglanti" der ve
    // router taklidi gerekmez.
    const bag = screen.getByRole("link", { name: /^Geciken okutma: / });
    expect(bag).toHaveAttribute("href", "/notifications");
  });

  it("KAHRAMAN blok bir SAYI degil DURUM anlatir", async () => {
    // Kahraman blok "5" degil bir DURUM anlatmali. (P181 7.3) Artik duz cumle
    // degil GORSEL bilesen: ilerleme halkasi (%40) + "Tamamlanan 2/5" + plan
    // adi. Bilgi renk-yalniz degil, sayi/etiketle de tasinir.
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() =>
      expect(screen.getByText("Gece turu")).toBeInTheDocument(),
    );
    // İlerleme halkasının yüzde METNİ (renk-yalnız değil) + durum rozeti:
    // "sayı değil durum" kanıtı. ("Tamamlanan" panoda sr-only KPI'da da
    // geçtiği için yüzde+rozet üzerinden ölçülür.)
    expect(screen.getByText("%40")).toBeInTheDocument();
    expect(screen.getByText(/Süren devriye/i)).toBeInTheDocument();
  });
});
