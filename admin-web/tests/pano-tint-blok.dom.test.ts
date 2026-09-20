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
// OLCUDUR. Testler diline gore degil, KORUDUKLARI KURALA gore yasar.
//
// ===========================================================================
// (P244 §5) DIL BIR KEZ DAHA DEGISTI — VE KURALIN BIR YARISI DUSTU
// ===========================================================================
// Halka (`Kpi`) yerini referansin DIKDORTGEN KARTINA birakti (`OzetKarti`).
//
// "EN COK DORT" SINIRI KALKTI. Gerekcesi P133.2'de RENKTI: renkli
// cemberler besincide birbirini bogup sinyali gurultuye ceviriyordu.
// Kart dili renkle degil TIPOGRAFIYLE calisir — etiket kucuk ve sonuk,
// sayi buyuk ve koyu; ikon kutusu tonlu ama METIN tasimaz. Serit
// `auto-fit` ile dizilir. Yani sinirin dayandigi olcum artik gecerli
// degil ve sayiyi korumak, sebebi kalkmis bir kurali korumak olurdu.
//
// KURALIN OTEKI YARISI AYNEN DURUYOR ve asagida olculuyor:
//   * yetkisi olmayana MALI kart CIZILMEZ (veri sizmaz),
//   * sayan rakam DEKORATIF degil — ekran okuyucu gercek degeri okur,
//   * kart bir BAGLANTIDIR (yeni sekmede acilabilir).
//
// NE OLCULMEZ: renklerin GUZEL olup olmadigi.
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
  it("MALI KART yetki yoksa CIZILMEZ (veri sizmaz)", async () => {
    // Sunucu tahsilat oranini guvenlik rollerine `null` doner. "%0"
    // cizmek, veriyi sizdirmadan YANLIS bilgi vermek olurdu.
    fetchTaklidi(null);
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    expect(screen.queryByText(/^Aidat tahsilatı$/)).toBeNull();
    // Yetki VARSA cizilir — yokluk "hep yok" degil, "bu rolde yok".
  });

  it("MALI KART yetki VARSA cizilir", async () => {
    fetchTaklidi(78);
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    expect(screen.getByText(/^Aidat tahsilatı$/)).toBeInTheDocument();
  });

  it("SAYI DEKORATIF DEGIL — ekran okuyucu gercek degeri okur", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    // Kartta etiket ve deger AYRI ogeler; ikisi de gorunur metin.
    // `aria-hidden` YALNIZ ikon kutusunda — sayi asla gizlenmez.
    const kart = screen.getByText("Geciken okutma").closest("a");
    expect(kart).not.toBeNull();
    expect(kart!.querySelector('[aria-hidden="true"]')).not.toBeNull();
    expect(kart!.textContent).toMatch(/\d/);
  });

  it("OZET KARTI BAGLANTIDIR (dugme degil) — yeni sekmede acilabilsin", async () => {
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() => expect(screen.getByText("Geciken okutma")).toBeInTheDocument());
    const bag = screen.getByText("Geciken okutma").closest("a");
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
