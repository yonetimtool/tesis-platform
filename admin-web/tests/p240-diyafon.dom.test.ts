// @vitest-environment jsdom
// (P240 §2) DIYAFON — panel yuzeyi.
//
// OLCULEN: yetenek listesi SUNUCUDAN gelir ve eylem dugmeleri ona gore
// cizilir; basinca 422 alacak bir dugme gostermek, olmayan bir yetenegi
// vaat etmek olurdu. Ayrica "sesli anons yok" satiri SECIM ANINDA
// gorunur — sahada "neden ses gelmiyor" sorusunu dogurmasin.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import IntegrationsPage from "@/app/(protected)/integrations/page";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);
let cagrilar: { url: string; metot: string; govde?: unknown }[] = [];

function kayit(over: Record<string, unknown> = {}) {
  return {
    id: "d1",
    ad: "Kapı paneli",
    yontem: "sip",
    host: "192.168.1.50",
    port: null,
    kullanici: null,
    sifre_set: false,
    hedef: "100",
    zil_yolu: null,
    kapi_yolu: null,
    aktif: true,
    saglik: "bilinmiyor",
    son_basarili_at: null,
    son_hata_kod: null,
    yetenekler: {
      metin_anons: true,
      sesli_anons: false,
      kapi_ac: false,
      zil_cal: false,
    },
    ...over,
  };
}

function taklit(diyafonlar: unknown[]) {
  cagrilar = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/diyafon")) {
      govde = metot === "GET"
        ? { meta: { limit: 50, offset: 0, total: diyafonlar.length }, items: diyafonlar }
        : { ok: true, kod: null };
    } else if (url.startsWith("/api/integrations/presets")) govde = [];
    else if (url.startsWith("/api/integrations")) {
      govde = { meta: { limit: 200, offset: 0, total: 0 }, items: [] };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P240 §2) diyafon bolumu", () => {
  it("ENTEGRASYONLAR EKRANININ ICINDE — ayri sayfa YOK", async () => {
    taklit([kayit()]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-bolumu")).toBeTruthy());
  });

  it("YETENEKLER SUNUCUDAN cizilir; SESLI ANONS YOK satiri HER SATIRDA", async () => {
    taklit([kayit()]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-yetenek-d1")).toBeTruthy());
    expect(el("diyafon-yetenek-d1")?.textContent).toContain("Metin anonsu");
    expect(el("diyafon-sesli-yok-d1")?.textContent).toMatch(/Sesli anons yok/i);
  });

  it("SIP'te ZIL/KAPI dugmesi CIZILMEZ — 422 alacak dugme gosterilmez", async () => {
    taklit([kayit()]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-test-d1")).toBeTruthy());
    expect(el("diyafon-zil-d1")).toBeNull();
    expect(el("diyafon-kapi-d1")).toBeNull();
  });

  it("KURU KONTAKTA zil+kapi VAR, metin anonsu YOK", async () => {
    taklit([
      kayit({
        yontem: "kuru_kontak",
        hedef: null,
        zil_yolu: "/rele1",
        kapi_yolu: "/rele2",
        yetenekler: {
          metin_anons: false,
          sesli_anons: false,
          kapi_ac: true,
          zil_cal: true,
        },
      }),
    ]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-zil-d1")).toBeTruthy());
    expect(el("diyafon-kapi-d1")).toBeTruthy();
    expect(el("diyafon-yetenek-d1")?.textContent).not.toContain("Metin anonsu");
  });

  it("TEST ET saglik ucuna gider — zil/kapi ucuna DEGIL", async () => {
    // Bir "test" dugmesinin zil calmasi, izlemenin izledigi seyi
    // calistirmasi olurdu (P240 §4 kurali).
    taklit([kayit()]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-test-d1")).toBeTruthy());
    await userEvent.click(el("diyafon-test-d1") as HTMLElement);
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url === "/api/diyafon/d1/saglik")).toBe(true),
    );
    expect(cagrilar.some((c) => c.url.includes("/zil"))).toBe(false);
    expect(cagrilar.some((c) => c.url.includes("/kapi-ac"))).toBe(false);
  });

  it("BOS SIFRE GOVDEYE GIRMEZ — 'degistirme' demektir, 'sil' degil", async () => {
    taklit([]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-yeni")).toBeTruthy());
    await userEvent.click(el("diyafon-yeni") as HTMLElement);
    await waitFor(() => expect(el("diyafon-ad")).toBeTruthy());
    await userEvent.type(el("diyafon-ad") as HTMLElement, "Panel");
    await userEvent.type(el("diyafon-host") as HTMLElement, "192.168.1.50");
    await userEvent.click(el("diyafon-kaydet") as HTMLElement);

    await waitFor(() => {
      const post = cagrilar.find((c) => c.metot === "POST");
      expect(post).toBeTruthy();
      expect(Object.keys(post!.govde as object)).not.toContain("sifre");
    });
  });

  it("KURU KONTAK secilince ZIL/KAPI alanlari, SIP'te HEDEF cizilir", async () => {
    // Hepsini birden gostermek, kullaniciya doldurmamasi gereken
    // alanlar sunmak olurdu.
    taklit([]);
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("diyafon-yeni")).toBeTruthy());
    await userEvent.click(el("diyafon-yeni") as HTMLElement);
    await waitFor(() => expect(el("diyafon-hedef")).toBeTruthy());
    expect(el("diyafon-zil-yolu")).toBeNull();

    await userEvent.selectOptions(
      el("diyafon-yontem") as HTMLSelectElement,
      "kuru_kontak",
    );
    await waitFor(() => expect(el("diyafon-zil-yolu")).toBeTruthy());
    expect(el("diyafon-kapi-yolu")).toBeTruthy();
    expect(el("diyafon-hedef")).toBeNull();
  });
});
