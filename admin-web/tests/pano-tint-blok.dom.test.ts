// @vitest-environment jsdom
// (P133.2) TINT BLOK DILININ SERT SINIRI.
//
// Onaydan birebir: "ekran basina en cok 1 kahraman + 4 ikincil tint blok.
// Fazlasi notr yuzey kullanir. Renk SINYAL kalmali; alti tintli ekran
// gurultudur ve bu sinir yonun calismasinin TEK sebebidir."
//
// NEDEN TEST: bu tur sinirlar yorumda yasar ve alti ay sonra "bir blok
// daha ekleyelim" ile sessizce asilir. O an hicbir sey dusmez, yalnizca
// tasarim geri gider. Burasi sayimi yapar.
//
// NE OLCULMEZ: renklerin GUZEL olup olmadigi. Olculen sey SAYI ve
// yapisal kurallar (kenarlik yok, dogru yaricap, ikon dekoratif).
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
  it("tint blok sayisi 5'i ASMAZ", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    const bloklar = tintBloklar(container);
    expect(bloklar.length, "tint blok sayisi").toBeLessThanOrEqual(5);
    // Ve gercekten bloklar VAR (secici bosa dusup testi anlamsiz
    // kilmasin — bu dosyanin en olasi sessiz bozulma bicimi budur).
    expect(bloklar.length).toBeGreaterThanOrEqual(4);
  });

  it("TAM OLARAK BIR kahraman blok (20px yaricap)", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    const kahraman = tintBloklar(container).filter((el) =>
      (el.getAttribute("class") ?? "").includes("rounded-blok"),
    );
    expect(kahraman).toHaveLength(1);
  });

  it("IKINCIL bloklar 16px yaricapli ve EN COK 4", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    const ikincil = tintBloklar(container).filter((el) =>
      (el.getAttribute("class") ?? "").includes("rounded-kart"),
    );
    expect(ikincil.length).toBeLessThanOrEqual(4);
    expect(ikincil.length).toBeGreaterThanOrEqual(3);
  });

  it("MALI blok dususe de sinir korunur (3 ikincil)", async () => {
    fetchTaklidi(null);
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    const ikincil = tintBloklar(container).filter((el) =>
      (el.getAttribute("class") ?? "").includes("rounded-kart"),
    );
    expect(ikincil).toHaveLength(3);
  });
});

describe("(P133.2) blok YAPISI", () => {
  it("bloklarda KENARLIK YOK (kart degil, dolu tint)", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    for (const el of tintBloklar(container)) {
      const c = el.getAttribute("class") ?? "";
      expect(c, "tint blok kenarlik tasiyor").not.toMatch(/\bborder\b|kart-kenar/);
    }
  });

  it("blok ikonu DEKORATIF (ekran okuyucuya okunmaz)", async () => {
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    for (const el of tintBloklar(container)) {
      const svg = el.querySelector("svg");
      if (!svg) continue;
      // Ikonun anlami yanindaki etikettedir; iki kez okunmasi gurultudur.
      const gizli =
        svg.getAttribute("aria-hidden") === "true" ||
        svg.closest("[aria-hidden='true']") !== null;
      expect(gizli, `ikon aria-hidden degil: ${el.className}`).toBe(true);
    }
  });

  it("tint uzerindeki metin ROL TOKEN'i (notr gri DEGIL)", async () => {
    // Kural: "tint uzerinde notr gri asla". Notr metin token'lari
    // (`text-metin-*`) blogun KENDI sinifinda gecmemeli.
    fetchTaklidi();
    const { container } = ciz(DashboardPage);
    await screen.findAllByText("Gece turu");
    for (const el of tintBloklar(container)) {
      const c = el.getAttribute("class") ?? "";
      expect(c, "tint uzerinde notr metin").not.toMatch(/text-metin-/);
      expect(c, "vurgu metin token'i yok").toMatch(/text-vurguInk-/);
    }
  });

  it("KAHRAMAN blok bir SAYI degil DURUM anlatir", async () => {
    // Kahraman blok "5" degil "Gece turu / 2 noktadan 5 tanesi okutuldu"
    // demeli — yon burada bilgi hiyerarsisini degistiriyor.
    fetchTaklidi();
    ciz(DashboardPage);
    await waitFor(() =>
      expect(screen.getByText(/noktadan .* okutuldu/i)).toBeInTheDocument(),
    );
    expect(screen.getByText(/Süren devriye/i)).toBeInTheDocument();
  });
});
