// @vitest-environment jsdom
// (P225) TESISLER EKRANI: KORUMA + NUMARALANDIRMA + ARAMA.
//
// =========================================================================
// OLCULEN KUSUR (kullanicinin ekran goruntusu)
// =========================================================================
// Tesisler listesinde platform tesisinin satirinda Sil dugmesi
// OTEKILERLE AYNIYDI — kirmizi, tiklanabilir, hicbir uyari yok. Prod'da
// o tesis silindi ve platform admin hesabi CASCADE ile gitti.
//
// P224 sunucu + trigger katmanlarini kapatti; EKSIK OLAN ARAYUZ KATMANIYDI.
//
// SAHTE HTTP KATMANINDA (P200 dersi): arama sorgusunu kuran katman da
// testten geciyor.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";

import TenantlarPage from "@/app/(protected)/tenants/page";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/tenants",
  useSearchParams: () => new URLSearchParams(),
}));

const json = (govde: unknown) =>
  new Response(JSON.stringify(govde), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });

function tesis(n: number, ek: Record<string, unknown> = {}) {
  return {
    id: `t-${n}`,
    ad: `Tesis ${n}`,
    kayit_kodu: `1234-5678-00000${n}`,
    kurulum_tamamlandi: true,
    created_at: "2026-01-01T00:00:00Z",
    platform_admini_var: false,
    ...ek,
  };
}

const PLATFORM = tesis(1, { ad: "Yönetio Platform", platform_admini_var: true });

interface Cagri {
  url: string;
  metot: string;
}

function sahtele(items: unknown[], cagrilar: Cagri[] = []) {
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({ url, metot: init?.method ?? "GET" });
    if (url.includes("/api/tenants")) return json({ items });
    return json({ items: [] });
  }) as typeof fetch;
}

afterEach(() => vi.restoreAllMocks());

describe("P225 tesisler ekrani", () => {
  it("PLATFORM TESISINDE Sil dugmesi CIZILMEZ", async () => {
    sahtele([PLATFORM, tesis(2)]);
    ciz(TenantlarPage);
    await screen.findByText("Yönetio Platform");

    expect(
      document.querySelectorAll('[data-test="tesis-sil-korumali"]').length,
    ).toBe(1);
    // Sil dugmesi SADECE oteki tesiste — koruma FAZLA GENIS DEGIL.
    expect(screen.getAllByRole("button", { name: "Sil" }).length).toBe(1);
  });

  it("KORUMASIZ tesiste Sil dugmesi DURUYOR (mesru silme calisir)", async () => {
    sahtele([tesis(2), tesis(3)]);
    ciz(TenantlarPage);
    await screen.findByText("Tesis 2");
    expect(screen.getAllByRole("button", { name: "Sil" }).length).toBe(2);
    expect(
      document.querySelectorAll('[data-test="tesis-sil-korumali"]').length,
    ).toBe(0);
  });

  it("SATIRLAR 1'DEN numaralanir", async () => {
    sahtele([tesis(1), tesis(2), tesis(3)]);
    ciz(TenantlarPage);
    await screen.findByText("Tesis 1");
    const sira = [...document.querySelectorAll('[data-test="tablo-sira"]')].map(
      (x) => x.textContent,
    );
    expect(sira).toEqual(["1", "2", "3"]);
  });

  it("ARAMA SUNUCUYA `q` olarak gider (istemcide suzulmez)", async () => {
    const cagrilar: Cagri[] = [];
    sahtele([tesis(1)], cagrilar);
    ciz(TenantlarPage);
    await screen.findByText("Tesis 1");

    const kutu = document.querySelector('[data-test="tesis-ara"]') as HTMLElement;
    await userEvent.type(kutu, "arikoy");

    await waitFor(
      () => {
        const aramali = cagrilar.filter((c) => c.url.includes("q="));
        expect(aramali.length).toBeGreaterThan(0);
        expect(decodeURIComponent(aramali.at(-1)!.url)).toContain("q=arikoy");
      },
      { timeout: 2000 },
    );
    // GECIKME: ara degerler icin ISTEK ATILMAZ ("a", "ar", "ari"...).
    const araDegerler = cagrilar.filter((c) =>
      /q=(a|ar|ari|arik|ariko)(&|$)/.test(c.url),
    );
    expect(araDegerler.length).toBe(0);
  });

  it("KURULUM SUZGECI sunucuya `kurulum` olarak gider", async () => {
    const cagrilar: Cagri[] = [];
    sahtele([tesis(1)], cagrilar);
    ciz(TenantlarPage);
    await screen.findByText("Tesis 1");

    const suzgec = document.querySelector(
      '[data-test="tesis-kurulum-suzgec"]',
    ) as HTMLSelectElement;
    await userEvent.selectOptions(suzgec, "bekliyor");
    await waitFor(() =>
      expect(cagrilar.some((c) => c.url.includes("kurulum=false"))).toBe(true),
    );
  });

  it("SONUC YOKSA bos tablo degil SEBEP gosterilir", async () => {
    sahtele([]);
    ciz(TenantlarPage);
    const kutu = (await waitFor(() => {
      const el = document.querySelector('[data-test="tesis-ara"]');
      if (!el) throw new Error("arama kutusu yok");
      return el;
    })) as HTMLElement;
    await userEvent.type(kutu, "yokboyle");
    // Arama aktifken mesaj "hic tesis yok"tan FARKLI: suzgeci acik
    // biraktigini fark etmeyen kullanici "tesisler silinmis" sanirdi.
    expect(await screen.findByText("Eşleşen tesis yok")).toBeInTheDocument();
  });
});
