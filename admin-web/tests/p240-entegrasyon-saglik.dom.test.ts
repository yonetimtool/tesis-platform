// @vitest-environment jsdom
// (P240 §4) ENTEGRASYON SAGLIGI — panel yuzeyi.
//
// EN ONEMLI OLCUM: "Kontrol et" ile "Test" AYRI dugmeler ve AYRI uclar.
// Tek dugmeye indirmek, megafon kanalinda "kontrol edeyim" diyen
// yoneticiye siteye ANONS YAPTIRIRDI.
import { waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import IntegrationsPage from "@/app/(protected)/integrations/page";

import { ciz } from "./yardimci";

const el = (ad: string) => document.querySelector(`[data-test="${ad}"]`);

let cagrilar: { url: string; metot: string }[] = [];

function taklit(over: Record<string, unknown> = {}) {
  cagrilar = [];
  const kayit = {
    id: "i1",
    ad: "Diyafon",
    channel_type: "smarthome",
    endpoint_url: "https://cihaz.ornek.com/hook",
    http_method: "POST",
    headers_json: {},
    auth_type: "none",
    auth_secret_set: false,
    payload_template: "",
    aktif: true,
    created_at: "2026-09-01T00:00:00Z",
    saglik: "bilinmiyor",
    son_kontrol_at: null,
    son_basarili_at: null,
    son_hata_kod: null,
    ...over,
  };
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({ url, metot });
    let govde: unknown = { ok: true };
    if (url.startsWith("/api/integrations/presets")) govde = [];
    else if (url.startsWith("/api/integrations?") || url === "/api/integrations") {
      govde = { meta: { limit: 50, offset: 0, total: 1 }, items: [kayit] };
    }
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("(P240 §4) entegrasyon sagligi", () => {
  it("YENI entegrasyon 'bilinmiyor' — HATA DEGIL", async () => {
    // "Henuz olculmedi" ile "kopuk" ayni sey degil; yeni tanimi kirmizi
    // gostermek, olmayan bir sorun bildirmek olurdu.
    taklit();
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("enteg-saglik-i1")).toBeTruthy());
    expect(el("enteg-saglik-i1")?.textContent).toContain("Bilinmiyor");
    expect(el("enteg-hata-i1")).toBeNull();
  });

  it("HATA SEBEBI ANLASILIR DILDE — kimlik degil CUMLE gosterilir", async () => {
    taklit({ saglik: "hata", son_hata_kod: "entegrasyon_baglanti_yok" });
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("enteg-hata-i1")).toBeTruthy());
    const metin = el("enteg-hata-i1")?.textContent ?? "";
    // Ham kimlik EKRANDA YAZMAZ.
    expect(metin).not.toContain("entegrasyon_baglanti_yok");
    expect(metin).toMatch(/ulaşılamıyor/i);
  });

  it("SON ILETISIM YOKSA 'henüz iletişim yok' YAZAR", async () => {
    // Bos birakmak, "hic iletisim olmadi" ile "uzun zaman once oldu"yu
    // birbirine karistirirdi.
    taklit();
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("enteg-son-iletisim-i1")).toBeTruthy());
    expect(el("enteg-son-iletisim-i1")?.textContent).toMatch(/henüz/i);
  });

  it("KONTROL ET ve TEST AYRI UCLARA gider", async () => {
    taklit();
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("enteg-saglik-kontrol-i1")).toBeTruthy());

    await userEvent.click(el("enteg-saglik-kontrol-i1") as HTMLElement);
    await waitFor(() =>
      expect(
        cagrilar.some((c) => c.url === "/api/integrations/i1/saglik"),
      ).toBe(true),
    );
    // KONTROL, TETIK UCUNU CAGIRMAZ — megafon susmali.
    expect(cagrilar.some((c) => c.url.includes("/trigger"))).toBe(false);
  });

  it("BAGLI durumu OLUMLU rozetle gosterilir", async () => {
    taklit({
      saglik: "bagli",
      son_basarili_at: "2026-09-17T10:00:00Z",
      son_kontrol_at: "2026-09-17T10:00:00Z",
    });
    ciz(IntegrationsPage);
    await waitFor(() => expect(el("enteg-saglik-i1")).toBeTruthy());
    expect(el("enteg-saglik-i1")?.textContent).toContain("Bağlı");
    expect(el("enteg-son-iletisim-i1")?.textContent).not.toMatch(/henüz/i);
  });
});
