// @vitest-environment jsdom
// (P73) Entegrasyonlar — SIR yalnizca YAZILIR, hic okunmaz.
//
// `auth_secret` write-only'dir: sunucu onu ASLA dondurmez, yalnizca
// `auth_secret_set` bayragini verir. Panelin sozlesmesi de buna bagli:
// alan BOS birakilirsa istek govdesine HIC KONMAZ ve sir DEGISMEZ.
// Bos dizge gondermek, kayitli siri SILMEK olurdu — ve bunu kullanici
// hicbir yerde gormezdi; entegrasyon bir sonraki tetiklemede sessizce
// 401 alirdi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import IntegrationsPage from "@/app/(protected)/integrations/page";

import { ciz, fetchSahtele } from "./yardimci";

const KAYIT = {
  id: "e1", ad: "Gürültü rölesi", channel_type: "webhook",
  endpoint_url: "https://ornek.test/uyari", http_method: "POST",
  headers_json: {}, auth_type: "bearer", auth_secret_set: true,
  payload_template: "{}", aktif: true, created_at: "2026-01-01T00:00:00Z",
};
const LISTE = { meta: { limit: 20, offset: 0, total: 1 }, items: [KAYIT] };

function govdeYakala(harita: Record<string, unknown>): unknown[] {
  const govdeler: unknown[] = [];
  fetchSahtele(harita);
  const onceki = globalThis.fetch;
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    if (init?.method && init.method !== "GET") {
      govdeler.push(JSON.parse(String(init.body)));
    }
    return onceki(g, init);
  }) as typeof fetch;
  return govdeler;
}

afterEach(() => vi.restoreAllMocks());

describe("Entegrasyonlar", () => {
  it("SIR listede GORUNMEZ, yalnizca 'var' isareti cikar", async () => {
    fetchSahtele({ "/api/integrations": LISTE });
    ciz(IntegrationsPage);
    await waitFor(() =>
      expect(screen.getByText("Gürültü rölesi")).toBeInTheDocument(),
    );
    expect(screen.getByText(/🔒/)).toBeInTheDocument();
  });

  it("DUZENLEMEDE sir alani BOS acilir ve gonderilmez (sir SILINMEZ)", async () => {
    const govdeler = govdeYakala({
      "/api/integrations": LISTE,
      "/api/integrations/e1": { ...KAYIT },
    });
    ciz(IntegrationsPage);
    await waitFor(() =>
      expect(screen.getByText("Gürültü rölesi")).toBeInTheDocument(),
    );
    await userEvent.click(screen.getAllByRole("button", { name: "Düzenle" })[0]);

    // Sir GET'te gelmez: alan bos acilmali (aksi halde ekranda sir olurdu).
    const sir = screen.getByLabelText(/^Sır/);
    expect(sir).toHaveValue("");

    await userEvent.click(screen.getByRole("button", { name: "Kaydet" }));
    await waitFor(() => expect(govdeler.length).toBe(1));
    // ASIL SEY: dokunulmayan sir govdeye HIC KONMAZ.
    expect(Object.keys(govdeler[0] as object)).not.toContain("auth_secret");
  });

  it("UC DUSTUGUNDE hata gorunur, liste cizilmez", async () => {
    fetchSahtele({});
    ciz(IntegrationsPage);
    await waitFor(() => expect(screen.getByText("yok")).toBeInTheDocument());
    expect(screen.queryByText("Gürültü rölesi")).not.toBeInTheDocument();
  });
});
