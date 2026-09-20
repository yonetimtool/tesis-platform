// @vitest-environment jsdom
// (P244 §6) GUVENLIK EKRANLARI — ARAC GECISLERI ve KAMERALAR.
//
// ===========================================================================
// OLCULEN DURUM
// ===========================================================================
// `arac-gecisleri` 69 satirdi ve her kaydi AYRI BIR KART olarak diziyordu:
// 50 gecis = 50 kart. Referansta ayni ekran ozet kartlari + YOGUN bir
// operasyon tablosu.
//
// Ayrica BFF rotasi sunucunun suzgeclerini DUSURUYORDU: `acik`, `plaka`,
// `baslangic`, `bitis` P16'dan beri destekleniyor ve sozlesme bunlari
// sayac tarifi olarak belgeliyor, ama web yalniz `limit`/`offset`
// gonderebiliyordu (P213'un "BFF sorgu suzgecini tasir" sinifi).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import AracPage from "@/app/(protected)/arac-gecisleri/page";

import { ciz } from "./yardimci";

const kanca = (ad: string): HTMLElement | null =>
  document.querySelector<HTMLElement>(`[data-test="${ad}"]`);

let cagrilanlar: string[] = [];

const GECIS = {
  id: "g1",
  plaka: "34ABC123",
  arac_tanim: "Beyaz Ford",
  giris_zamani: "2026-09-20T08:15:00Z",
  cikis_zamani: null,
  unit_no: "A-12",
  ziyaretci_mi: false,
};

function taklit(toplam = 3) {
  cagrilanlar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilanlar.push(url);
    // `limit=1` sayac sorgusudur: yalniz `meta.total` okunur.
    const sayac = url.includes("limit=1&");
    return new Response(
      JSON.stringify({
        items: sayac ? [] : [GECIS, { ...GECIS, id: "g2", plaka: "06XYZ99", cikis_zamani: "2026-09-20T09:00:00Z" }],
        meta: { total: toplam },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P244 §6) arac gecisleri", () => {
  it("KART YIGINI DEGIL TABLO cizilir", async () => {
    taklit();
    const { container } = ciz(AracPage);
    await waitFor(() => expect(container.querySelector("table")).not.toBeNull());
    // Iki kayit, iki satir — her kayit icin bir BASLIK SEVIYESI degil.
    expect(container.querySelectorAll("tbody tr").length).toBe(2);
    expect(container.querySelectorAll("h2").length).toBe(0);
  });

  it("OZET SAYILARI `meta.total`DAN gelir, gorunen sayfadan DEGIL", async () => {
    // Gorunen 2 kayit var ama toplam 137. Gorunen listeyi saymak
    // "bugun 2 giris oldu" gibi YANLIS bir sayi uretirdi.
    //
    // IDDIA KART BASINA: ilk yazimda `getAllByText("137")` diyordum ve
    // uc kartin hepsi ayni sayiyi gosterdigi icin, BIR kart gorunen
    // listeden saymaya baslasa bile test GECIYORDU (kirarak olculdu).
    taklit(137);
    ciz(AracPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    for (const etiket of ["Bugünkü giriş", "Şu an içeride", "Listelenen kayıt"]) {
      const kart = screen.getByText(etiket).closest("div")!.parentElement!;
      expect(kart.textContent, etiket).toContain("137");
      // Gorunen liste 2 kayitli; kart onu YAZMAMALI.
      expect(kart.textContent, etiket).not.toMatch(/(^|[^\d])2([^\d]|$)/);
    }
  });

  it("SAYAC SORGULARI sozlesmenin tarif ettigi bicimde atilir", async () => {
    // Sozlesme: "Ana ekran sayaci: `?acik=true&limit=1` -> `meta.total`"
    // ve "Bugun N giris: `?baslangic=<gun basi>&limit=1`".
    taklit();
    ciz(AracPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    expect(cagrilanlar.some((u) => u.includes("acik=true") && u.includes("limit=1"))).toBe(true);
    expect(cagrilanlar.some((u) => u.includes("baslangic=") && u.includes("limit=1"))).toBe(true);
  });

  it("PLAKA ARAMASI SUNUCUYA gider (istemcide suzulmez)", async () => {
    // Istemcide suzmek YALNIZ gorunen 50 kaydi arardi; kullanici
    // "plakam yok" der, oysa kayit ikinci sayfadadir.
    taklit();
    ciz(AracPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    const alan = screen.getByLabelText(/Plakaya göre ara/i);
    await userEvent.type(alan, "34ABC");
    await waitFor(() =>
      expect(cagrilanlar.some((u) => u.includes("plaka=34ABC"))).toBe(true),
    );
  });

  it("FILTRE SAYACI aktif suzgecleri SAYIYLA soyler", async () => {
    taklit();
    ciz(AracPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    // Baslangicta suzgec yok -> temizle dugmesi CIZILMEZ.
    expect(kanca("filtre-temizle")).toBeNull();
    await userEvent.type(screen.getByLabelText(/Plakaya göre ara/i), "34");
    await waitFor(() => expect(kanca("filtre-temizle")).not.toBeNull());
    expect(kanca("filtre-temizle")!.textContent).toMatch(/1/);
  });

  it("DURUM ROZETI RENKTEN BASKA bir ipucu tasir", async () => {
    // Renk korlugu olan kullanici "İçeride" ile "Çıktı"yi ayirt
    // edebilmeli; ikisi de KELIME tasiyor.
    taklit();
    ciz(AracPage);
    await waitFor(() => expect(kanca("ozet-seridi")).not.toBeNull());
    expect(screen.getAllByText(/İçeride/).length).toBeGreaterThan(0);
    expect(screen.getAllByText(/Çıktı/).length).toBeGreaterThan(0);
  });
});
