// @vitest-environment jsdom
// (P244 §5) OZET SAYFASI — KAHRAMAN BANDI ve OZET SERIDI.
//
// ===========================================================================
// NE OLCULUYOR
// ===========================================================================
// Referansta (`ui5.png`) sayfa bir KARSILAMA BANDIYLA basliyor ve altinda
// dikdortgen OZET KARTLARI var. Bizde sayfa yalniz "Özet" baslıgıyla
// basliyordu ve kartlar 116 px'lik HALKALARDI.
//
// Olculen sey gorsel degil DAVRANISSAL: bandin uc bilgiyi tasidigi,
// verinin YENI BIR UC cagrilmadan turetildigi ve ozellestirme sisteminin
// (P167 §2.5) bozulmadigi.
import { screen, waitFor } from "@testing-library/react";
import { createElement as h } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";
import { durumRenkleri } from "@/components/3d/site-palet";
import { KahramanBandi } from "@/components/pano/kahraman-bandi";

import { ciz } from "./yardimci";

const kanca = (ad: string): HTMLElement | null =>
  document.querySelector<HTMLElement>(`[data-test="${ad}"]`);

/** Cagrilan tum URL'ler — "yeni uc acildi mi" olcumu icin. */
let cagrilanlar: string[] = [];

function taklit(ek: Record<string, unknown> = {}) {
  cagrilanlar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilanlar.push(url);
    const govde =
      url.includes("/api/dashboard/live")
        ? {
            generated_at: "2026-09-20T09:00:00Z",
            aktif_turlar: [],
            alarm_gruplari: [],
            aidat_tahsilat_orani: 87,
          }
        : url.includes("/api/me/pano-tercihi")
          ? {}
          : url.includes("/api/tenant/settings")
            ? { ad: "Beyoğlu Konakları" }
            : url.includes("/api/weather")
              ? { sicaklik_c: 22.4, durum: "acik", konum_ad: "İstanbul" }
              : url.includes("/api/me")
                ? { ad: "Furkan Kaymakçı", role: "yonetici" }
                : url.includes("/api/unit-complaints/gorunur-sayi")
                  ? { acik_sayisi: 7 }
                  : { items: [], meta: { total: 0 } };
    return new Response(JSON.stringify({ ...govde, ...ek }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §5) kahraman bandi", () => {
  it("SELAM + TESIS + TARIH bir arada", async () => {
    taklit();
    ciz(() => h(KahramanBandi, { tarih: new Date("2026-09-20T09:00:00") }));
    // Ad ilk adiyla selamlanir — tam ad bir basliga uzun.
    await waitFor(() => expect(screen.getByText(/Furkan/)).toBeInTheDocument());
    expect(screen.getByText(/Beyoğlu Konakları/)).toBeInTheDocument();
    // Tarih AKTIF DILDE bicimlenir (testler TR kosar).
    expect(screen.getByText(/2026/)).toBeInTheDocument();
  });

  it("SAAT'E GORE selam degisir", async () => {
    taklit();
    const { unmount } = ciz(() =>
      h(KahramanBandi, { tarih: new Date("2026-09-20T08:00:00") }),
    );
    await waitFor(() => expect(screen.getByText(/Günaydın/)).toBeInTheDocument());
    unmount();
    taklit();
    ciz(() => h(KahramanBandi, { tarih: new Date("2026-09-20T20:00:00") }));
    await waitFor(() => expect(screen.getByText(/İyi akşamlar/)).toBeInTheDocument());
  });

  it("HAVA ALINAMAZSA bant CIZILMEYE DEVAM EDER (blok sessizce dusher)", async () => {
    // Konum ayarlanmamissa uc 503 doner. Bu bir KUSUR DEGIL, bir durum:
    // kullanicinin yapabilecegi bir sey yok, karsilama satirini hata
    // mesajiyla bolmek onu bir soruna cevirirdi.
    cagrilanlar = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL) => {
      const url = String(girdi);
      if (url.includes("/api/weather")) {
        return new Response(JSON.stringify({ error: { code: "weather_unavailable" } }), {
          status: 503,
          headers: { "Content-Type": "application/json" },
        });
      }
      const govde = url.includes("/api/tenant/settings")
        ? { ad: "Beyoğlu Konakları" }
        : { ad: "Furkan Kaymakçı" };
      return new Response(JSON.stringify(govde), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }) as typeof fetch;
    ciz(() => h(KahramanBandi, { tarih: new Date("2026-09-20T09:00:00") }));
    await waitFor(() => expect(screen.getByText(/Furkan/)).toBeInTheDocument());
    expect(kanca("pano-hava")).toBeNull();
  });
});

describe("(P244 §5) ozet seridi", () => {
  it("KARTLAR VAR ve kahraman bandi sayfanin USTUNDE", async () => {
    taklit();
    ciz(DashboardPage);
    await waitFor(() => expect(kanca("pano-kahraman")).not.toBeNull());
    expect(kanca("ozet-seridi")).not.toBeNull();
  });

  it("MAKET EFSANESI RENKLERINI SAHNEDEN ALIR (kopya hex yok)", async () => {
    // Efsane, sahnenin cizdigi renklerin ADINI soyluyor. Renkleri ikinci
    // kez tanimlarsa tema degisince sahne ile efsane AYRI renk gosterir
    // ve efsane maketi YANLIS anlatir. Bu kilit, birinin efsaneye sabit
    // bir hex yazmasini engeller — kirilarak dogrulandi: sabit hex
    // yazildiginda hicbir kilit yakalamiyordu.
    taklit();
    const { container } = ciz(DashboardPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    const beklenen = durumRenkleri(false);
    const noktalar = [...container.querySelectorAll<HTMLElement>("span.rounded-full")]
      .map((o) => o.style.background)
      .filter(Boolean);
    // jsdom hex'i `rgb(r, g, b)`ye cevirir; karsilastirma ayni bicimde
    // yapilmali (ilk yazimda hex'le karsilastirdim ve test HAKLI olarak
    // dustu — kilit kendi olcum hatasini yakaladi).
    const rgb = (hex: string) => {
      const h = hex.replace("#", "");
      const n = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
      return `rgb(${n[0]}, ${n[1]}, ${n[2]})`;
    };
    // Sahne sunucu cizimde `koyu=false` ile baslar; efsane de oyle.
    for (const d of ["normal", "alarm"] as const) {
      expect(
        noktalar.includes(rgb(beklenen[d])),
        `efsanede ${d} rengi sahneden gelmiyor (beklenen ${beklenen[d]})`,
      ).toBe(true);
    }
  });

  it("YENI UC ACILMADI — kartlar SAYFADA ZATEN cekilen veriden turedi", async () => {
    // P244'un kurali: bu tur YENI EKRAN ve YENI UC getirmez. Ozet
    // kartlari `dashboard/live`, `building-map` ve `gorunur-sayi`dan
    // turer; hicbiri bu tur icin acilmis degil.
    taklit();
    ciz(DashboardPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    const yeni = cagrilanlar.filter(
      (u) =>
        u.includes("/api/") &&
        !u.includes("dashboard/live") &&
        !u.includes("pano-tercihi") &&
        !u.includes("building-map") &&
        !u.includes("/api/blocks") &&
        !u.includes("gorunur-sayi") &&
        !u.includes("/api/cameras") &&
        !u.includes("/api/me") &&
        !u.includes("tenant/settings") &&
        // ASAMA 5 ONCESINDEN VAR OLAN BOLUMLERIN UCLARI: finans ozeti ve
        // takvim bolumleri P167'den beri bu sayfada duruyor.
        !u.includes("/api/panel/finans-ozet") &&
        !u.includes("/api/panel/kasa-bakiyeleri") &&
        !u.includes("/api/takvim") &&
        // `/api/weather` P244'te EKLENDI ama yeni bir SUNUCU ucu degil:
        // sunucuda P233'ten beri var, eksik olan BFF rotasiydi.
        !u.includes("/api/weather"),
    );
    expect(yeni, `beklenmeyen uc: ${yeni.join(", ")}`).toEqual([]);
  });
});
