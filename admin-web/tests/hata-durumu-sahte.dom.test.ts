// @vitest-environment jsdom
// (P175) `HataDurumu` HATA YOKKEN HICBIR SEY CIZMEZ.
//
// =========================================================================
// OLCULEN OLAY
// =========================================================================
// Kurulum sihirbazi her acilista "Veriler yuklenemedi." gosteriyordu —
// VERI DOGRU GELDIGI HALDE. Backend `GET /kurulum` 200 donuyor, ekran
// ilerlemeyi (3/8) ve butun adimlari DOGRU ciziyor, ve ayni anda hata
// kartI da duruyordu.
//
// Sebep cagiranda degil BILESENDEYDI: `mesaj` null olsa bile kart
// cizilyor ve `{mesaj || t("ortakVeriYuklenemedi")}` genel metne
// dusuyordu. "Hata yok" demenin bir yolu YOKTU.
//
// Tarandi: 28 dosyada 39 cagri yeri bu kalibi kullaniyordu — hepsi
// KALICI sahte hata tasiyordu (formlar, modallar, finans ekranlari).
//
// =========================================================================
// NEDEN `null` ILE `undefined` AYRI
// =========================================================================
//   * `mesaj={null}`   -> hata YOK, cizme.
//   * `mesaj` verilmez -> "hata var, metni yok", genel metin.
// Ikisini tek davranisa indirmek, ya "hata yok"u anlatmanin yolunu ya da
// genel metni yok ederdi.
import { screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import React from "react";

import { HataDurumu } from "@/components/ui";

import { ciz } from "./yardimci";

const GENEL = /Veriler yüklenemedi/i;

describe("HataDurumu — hata yokken", () => {
  it("`mesaj={null}` HICBIR SEY cizmez", () => {
    const { container } = ciz(() =>
      React.createElement(HataDurumu, { mesaj: null }),
    );
    expect(container.textContent).toBe("");
    expect(screen.queryByText(GENEL)).toBeNull();
    // Uyari rolu de OLMAMALI: ekran okuyucu "hata" duymamali.
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("`mesaj` HIC VERILMEZSE genel metin cizilir (uc cagri yeri buna dayaniyor)", () => {
    ciz(() => React.createElement(HataDurumu, {}));
    expect(screen.getByText(GENEL)).toBeTruthy();
  });

  it("METIN VERILIRSE o gosterilir", () => {
    ciz(() => React.createElement(HataDurumu, { mesaj: "Kota asildi." }));
    expect(screen.getByText("Kota asildi.")).toBeTruthy();
    expect(screen.queryByText(GENEL)).toBeNull();
  });
});

describe("kurulum sihirbazi — sahte hata YOK", () => {
  it("veri gelince hata karti CIZILMEZ", async () => {
    vi.mock("next/navigation", () => ({
      usePathname: () => "/kurulum",
      useRouter: () => ({ replace: vi.fn(), refresh: vi.fn(), push: vi.fn() }),
      useSearchParams: () => new URLSearchParams(),
    }));
    const { default: KurulumPage } = await import(
      "@/app/(protected)/kurulum/page"
    );

    // Bildirilen GERCEK govde.
    vi.stubGlobal("fetch", vi.fn(async (url: string) => ({
      ok: true,
      status: 200,
      json: async () =>
        String(url).includes("/kurulum")
          ? {
              adimlar: [
                { kod: "blok", sayi: 4, tamam: true, atlandi: false },
                { kod: "daire", sayi: 38, tamam: true, atlandi: false },
                { kod: "daire_tipi", sayi: 1, tamam: true, atlandi: false },
                { kod: "sakin", sayi: 0, tamam: false, atlandi: false },
                { kod: "personel", sayi: 0, tamam: false, atlandi: false },
                { kod: "gorev_alani", sayi: 0, tamam: false, atlandi: false },
                { kod: "nfc_noktasi", sayi: 0, tamam: false, atlandi: false },
                { kod: "aidat", sayi: 0, tamam: false, atlandi: false },
              ],
              toplam: 8,
              gecilen: 3,
            }
          : { role: "yonetici" },
    } as unknown as Response)));

    ciz(KurulumPage);

    // Veri cizilmis olmali...
    expect(await screen.findByText(/3\s*\/\s*8/)).toBeTruthy();
    // ...ve hata karti OLMAMALI. Kusurda ikisi BIRLIKTE gorunuyordu.
    expect(screen.queryByText(GENEL)).toBeNull();
    expect(screen.queryByText(/Kurulum durumu alınamadı/i)).toBeNull();
    vi.unstubAllGlobals();
  });
});

describe("(P175 §3) yeniden deneme SINIRLI ve SECICI", () => {
  it("KALICI durumlar (404/405/403/422) HIC yeniden denenmez", async () => {
    // Kurulum sihirbazinda olculdu: ayni istek onlarca kez
    // tekrarlaniyordu. 404 ya da 405 ayni girdiyle ayni sonucu verir;
    // denemek yalnizca sunucuya yuk bindirir.
    const { readFileSync } = await import("node:fs");
    const kaynak = readFileSync("components/SunucuDurumu.tsx", "utf8");
    expect(kaynak).toContain("KALICI_DURUMLAR");
    for (const d of ["404", "405", "403", "422"]) {
      expect(kaynak).toContain(d);
    }
    // UST SINIR VAR: SWR varsayilani SINIRSIZDIR.
    expect(kaynak).toContain("errorRetryCount: 4");
    // SEGIRME (jitter): sabit aralik, es zamanli hata alan bilesenleri
    // sunucuya SENKRON dalgalar halinde vurdururdu.
    expect(kaynak).toContain("Math.random()");
  });

  it("(§4) okuma hatasi HANGI CAGRI oldugunu soyler", async () => {
    const { jsonFetcher } = await import("@/lib/fetcher");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        json: async () => null, // GOVDESIZ: sunucunun metni yok
      } as unknown as Response),
    );

    await expect(jsonFetcher("/api/panel/kurulum?x=1")).rejects.toThrow(
      // Referans YOLU tasimali; sorgu ATILIR (kimlik sizdirmasin).
      /\/api\/panel\/kurulum/,
    );
    vi.unstubAllGlobals();
  });

  it("(§4) hata HTTP DURUMUNU tasir — yeniden deneme karari buna bakiyor", async () => {
    const { jsonFetcher } = await import("@/lib/fetcher");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
        json: async () => null,
      } as unknown as Response),
    );

    const hata = await jsonFetcher("/api/panel/yok").catch((e) => e);
    expect((hata as { durum?: number }).durum).toBe(404);
    vi.unstubAllGlobals();
  });
});
