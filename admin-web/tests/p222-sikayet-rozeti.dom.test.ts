// @vitest-environment jsdom
// (P222 §1) PANODAKI "SIKAYET HARITASI" ROZETI — HARITAYLA AYNI SAYI.
//
// =========================================================================
// OLCULEN KUSUR (mobil) VE WEB'DEKI KARSILIGI
// =========================================================================
// Mobilde ana ekran izgarasindaki sikayet karosu
// `GET /unit-complaints?durum=acik`in `meta.total` degerini okuyordu; o
// LISTE ucu `sikayet_harita_saat` penceresini UYGULAMAZ ve karo "5 Acik"
// derken dokununca acilan harita 0 gosterebiliyordu.
//
// Web'de ayni kusur DEGIL, EKSIK bir yuzey vardi: panoda sikayet sayisi
// gosteren HICBIR rozet yoktu. Parite geregi eklendi ve mobille AYNI
// uctan besleniyor: `/api/unit-complaints/gorunur-sayi`.
//
// SAHTE HTTP KATMANINDA (P200 dersi): `useSWR` taklit edilseydi, yanlis
// ucu cagirmak testten kacardi.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import DashboardPage from "@/app/(protected)/dashboard/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/dashboard",
  useSearchParams: () => new URLSearchParams(),
}));

const json = (govde: unknown, status = 200) =>
  new Response(JSON.stringify(govde), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function sahtele(sayiYaniti: () => Response, istekler: string[] = []) {
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    istekler.push(url);
    if (url.includes("/api/unit-complaints/gorunur-sayi")) return sayiYaniti();
    // ROL SUNUCUDAN: `menuGruplari("tesis", rol)` bos donerse hicbir
    // widget adayi olusmaz ve rozet testi sebebini gostermeden duserdi.
    if (url.includes("/api/me") && !url.includes("pano-tercihi")) {
      return json({ role: "yonetici" });
    }
    if (url.includes("/api/building-map")) return json({ bloklar: [], unplaced: [] });
    // `/schematic` VARSAYILAN KISAYOL DEGIL (WIDGET_SINIRI 6; yedinci
    // giris `/olaylar`i sessizce dusururdu). Rozet onu SECEN kullanicida
    // gorunur — test de kullaniciyi oyle kurar.
    if (url.includes("/api/me/pano-tercihi")) {
      return json({ widgetlar: [{ rota: "/schematic" }] });
    }
    return json({ items: [], meta: { total: 0 } });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("P222 pano sikayet rozeti", () => {
  it("SAYI GELIRSE rozet SIKAYET HARITASI kartinda cizilir", async () => {
    sahtele(() => json({ acik_sayisi: 4 }));
    ciz(DashboardPage);
    // SORGU KARTA DARALTILIR: panoda "4" baska yerlerde de geciyor
    // (ilk yazimda genis sorgu "birden fazla oge" diye dustu) ve genis
    // bir sorgu, rozet HIC cizilmese bile baska bir "4"e takilip
    // YANLIS GECEBILIRDI.
    const kart = (await screen.findAllByText("Şikayet Haritası"))[0]
      .closest("a, div[class*='relative']") as HTMLElement;
    expect(within(kart).getByText("4")).toBeInTheDocument();
  });

  it("LISTE UCU DEGIL, gorunur-sayi ucu cagrilir", async () => {
    const istekler: string[] = [];
    sahtele(() => json({ acik_sayisi: 4 }), istekler);
    ciz(DashboardPage);
    await waitFor(() =>
      expect(
        istekler.some((u) => u.includes("/api/unit-complaints/gorunur-sayi")),
      ).toBe(true),
    );
    // Penceresiz liste ucundan sayi OKUNMAMALI.
    expect(
      istekler.some((u) => /\/api\/unit-complaints\?/.test(u)),
    ).toBe(false);
  });

  it("UC 500 donerse rozet UYDURULMAZ (0 da yazilmaz)", async () => {
    sahtele(() => json({ detail: "bozuk" }, 500));
    ciz(DashboardPage);
    const kart = (await screen.findAllByText("Şikayet Haritası"))[0]
      .closest("a, div[class*='relative']") as HTMLElement;
    await waitFor(() => expect(within(kart).queryByText("0")).toBeNull());
    expect(within(kart).queryByText(/^[0-9]+$/)).toBeNull();
  });

  it("SIFIR gelirse rozet cizilmez — bos rozet gurultudur", async () => {
    sahtele(() => json({ acik_sayisi: 0 }));
    ciz(DashboardPage);
    const kart = (await screen.findAllByText("Şikayet Haritası"))[0]
      .closest("a, div[class*='relative']") as HTMLElement;
    await waitFor(() => expect(within(kart).queryByText("0")).toBeNull());
  });

  // =====================================================================
  // KISAYOL VARSAYILAN DEGIL — AMA SECILEBILIR OLMAK ZORUNDA
  // =====================================================================
  // `/schematic` varsayilan kisayol listesine EKLENMEDI: `WIDGET_SINIRI`
  // 6 ve yedinci giris `/olaylar`i sessizce dusururdu. Hangi kisayolun
  // cikacagi YONETICIYE GORE degisir — birinin isine yarayan otekine
  // yaramaz — ve sabit bir secim yapmak yanlis olurdu.
  //
  // Bu ancak yonetici kisayolu KENDI EKLEYEBILIYORSA dogru bir karar.
  // Asagidaki test tam olarak onu olcer: secim listesinde var mi,
  // isaretlenebiliyor mu. Menuden dusurulurse ya da rol kapisi
  // degisirse BU TEST DUSER.
  it("SECIM LISTESINDE var ve yonetici kendisi EKLEYEBILIYOR", async () => {
    const secilen: string[][] = [];
    globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
      const url = String(girdi);
      if (init?.method === "PUT" && url.includes("/api/me/pano-tercihi")) {
        const g = JSON.parse(String(init.body)) as {
          widgetlar?: { rota: string }[];
        };
        secilen.push((g.widgetlar ?? []).map((w) => w.rota));
        return json({});
      }
      if (url.includes("/api/unit-complaints/gorunur-sayi")) {
        return json({ acik_sayisi: 3 });
      }
      if (url.includes("/api/me") && !url.includes("pano-tercihi")) {
        return json({ role: "yonetici" });
      }
      // KAYITLI TERCIH: `/schematic` SECILI DEGIL — varsayilan hâl.
      if (url.includes("/api/me/pano-tercihi")) {
        return json({ widgetlar: [{ rota: "/dues" }] });
      }
      if (url.includes("/api/building-map")) {
        return json({ bloklar: [], unplaced: [] });
      }
      return json({ items: [], meta: { total: 0 } });
    }) as typeof fetch;

    ciz(DashboardPage);
    // Duzenleme kipine gec, secim kutusunu ac.
    await userEvent.click(
      await screen.findByRole("button", { name: "Paneli düzenle" }),
    );
    await userEvent.click(
      await screen.findByRole("button", { name: "Kısayolları seç" }),
    );

    const diyalog = await screen.findByRole("dialog");
    const satir = within(diyalog)
      .getByText("Şikayet Haritası")
      .closest("label") as HTMLElement;
    const kutu = within(satir).getByRole("checkbox") as HTMLInputElement;

    // SECILEBILIR: isaretsiz ve `disabled` DEGIL (sinir dolu degil).
    expect(kutu.checked).toBe(false);
    expect(kutu.disabled).toBe(false);

    await userEvent.click(kutu);
    await waitFor(() =>
      expect(secilen.at(-1)).toContain("/schematic"),
    );
  });
});
