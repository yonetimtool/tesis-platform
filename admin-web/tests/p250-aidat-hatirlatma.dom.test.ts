// @vitest-environment jsdom
// (P250 §7) OTOMATIK AIDAT HATIRLATMASI — duz ayar, e-posta, cumle, gecmis.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/finans/otomasyon/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/finans/otomasyon",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

const AYAR = {
  aktif: true, vade_oncesi_gun: 0, kademeler: [3, 10, 30], metin: null,
  son_calisma: null, eposta: true, ilk_gun: 3, tekrar_sayisi: 3, aralik_gun: 7,
};

function taklit() {
  const c: { url: string; metot: string; govde: unknown }[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    const govde = init?.body ? JSON.parse(String(init.body)) : null;
    c.push({ url, metot, govde });
    let yanit: unknown = { items: [], meta: { total: 0 } };
    if (url.includes("hatirlatma-ayari")) yanit = AYAR;
    // (P252 §2) Maas kurali — personelsiz tesis.
    if (url.includes("maas-ayari")) {
      yanit = { aktif: true, otomatik_onay: true, gruplar: [], personel_sayisi: 0,
        aylik_toplam_kurus: 0, onay_bekleyenler: [] };
    }
    if (url.includes("hatirlatma-epostalari")) {
      yanit = { meta: { total: 1 }, items: [
        { id: "m1", ad: "Ali VELİ", gonderim_zamani: "2026-10-01T10:00:00Z", durum: "geri_dondu" },
      ] };
    }
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const kanca = (ad: string) => document.querySelector(`[data-test="${ad}"]`) as HTMLInputElement | null;

it("ayar DUZ CUMLEYLE gorunur (gercek kademeler + kanal)", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("hatirlatma-cumlesi")).toBeTruthy());
  const cumle = kanca("hatirlatma-cumlesi")!.textContent!;
  expect(cumle).toContain("3, 10 ve 30");
  expect(cumle).toContain(tr.otoKanalBildirimEposta);
});

it("duz ayar UCU BIRLIKTE gider; e-posta anahtari ayri", async () => {
  const k = userEvent.setup();
  const c = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("hatirlatma-ilk")?.value).toBe("3"));
  await k.clear(kanca("hatirlatma-ilk")!);
  await k.type(kanca("hatirlatma-ilk")!, "5");
  await k.tab();
  await waitFor(() => expect(c.some((x) => x.metot === "PATCH")).toBe(true));
  expect(c.find((x) => x.metot === "PATCH")!.govde).toEqual({ ilk_gun: 5, tekrar_sayisi: 3, aralik_gun: 7 });
  await k.click(kanca("hatirlatma-eposta")!);
  // Plan DEGISMEDEN odak gecisi yeni kayit uretmez; e-posta AYRI gider.
  await waitFor(() =>
    expect(c.some((x) => x.metot === "PATCH" && JSON.stringify(x.govde) === '{"eposta":false}')).toBe(true),
  );
});

it("e-posta gecmisi teslim durumuyla", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(screen.getByText("Ali VELİ")).toBeTruthy());
  expect(screen.getByText(tr.odemeKoduDurumgeri_dondu)).toBeTruthy();
});
