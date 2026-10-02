// @vitest-environment jsdom
// (P251 §2/§10) Teknik gonderim gunlugu PLATFORMDA; yoneticide yalniz
// sade durum. Bildirimler sayfasinda TEK panel.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import GunlukPage from "@/app/(protected)/gonderim-gunlugu/page";
import NotificationsPage from "@/app/(protected)/notifications/page";
import { teslimAciklamasi } from "@/lib/teslim-durumu";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/x",
  useSearchParams: () => new URLSearchParams(),
}));
vi.mock("@/lib/rol-kullan", async (gercek) => ({
  ...(await gercek<typeof import("@/lib/rol-kullan")>()),
  useRol: () => "yonetici",
}));
afterEach(() => vi.restoreAllMocks());

function taklit(harita: Record<string, unknown>): string[] {
  const c: string[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL) => {
    const url = String(g);
    c.push(url);
    const anahtar = Object.keys(harita).filter((k) => url.startsWith(k)).sort((a, b) => b.length - a.length)[0];
    return new Response(JSON.stringify(anahtar ? harita[anahtar] : { items: [], meta: { total: 0 } }), {
      status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const SATIRLAR = {
  meta: { limit: 50, offset: 0, total: 2 },
  items: [
    { id: "m1", kanal: "eposta", tenant_id: "t1", tesis_ad: "Güneş Sitesi", alici_ad: "Ali VELİ",
      hedef: "ali@ornek.com", amac: "odeme_kodu", durum: "basarisiz",
      hata: "535 5.7.8 Authentication failed", saglayici: "smtp", created_at: "2026-10-02T09:00:00Z" },
    { id: "p1", kanal: "push", tenant_id: "t2", tesis_ad: "Ay Sitesi", alici_ad: "Can KAYA",
      hedef: "android …a1b2c3", amac: "kacirilan_tur", durum: "gecersiz_token",
      hata: "UNREGISTERED", saglayici: "fcm", created_at: "2026-10-02T08:00:00Z" },
  ],
};

it("platform gunlugu: tesis, kanal, Turkce amac, durum ve HAM hata; arama sunucuya gider", async () => {
  const c = taklit({ "/api/platform/gonderim-gunlugu": SATIRLAR, "/api/push/teshis": { denemeler: [], ozet_24s: {} } });
  const k = userEvent.setup();
  ciz(GunlukPage);
  await waitFor(() => expect(document.querySelector('[data-test="gunluk-satir-m1"]')).toBeTruthy());
  const m1 = document.querySelector('[data-test="gunluk-satir-m1"]')!.textContent!;
  expect(m1).toContain("Güneş Sitesi");
  expect(m1).toContain(tr.gunlukAmac_odeme_kodu);
  expect(document.querySelector('[data-test="gunluk-hata-m1"]')!.textContent).toBe("535 5.7.8 Authentication failed");
  const p1 = document.querySelector('[data-test="gunluk-satir-p1"]')!.textContent!;
  expect(p1).toContain(tr.gunlukKanalPush);
  expect(p1).toContain(tr.bildirimTipKacirilanTur);
  expect(p1).not.toContain("kacirilan_tur");

  await k.type(screen.getByLabelText(tr.gunlukAra), "ali@ornek");
  await k.click(screen.getByLabelText(tr.gunlukYalnizBasarisiz));
  await k.selectOptions(screen.getByLabelText(tr.gunlukKanal), "eposta");
  await waitFor(() =>
    expect(c.some((u) => u.includes("ara=ali%40ornek") && u.includes("basarisiz=true") && u.includes("kanal=eposta"))).toBe(true),
  );
});

it("bildirimler: TEK panel — push teshis paneli yok, tur adi Turkce", async () => {
  const c = taklit({
    "/api/notifications": { meta: { total: 1 }, items: [
      { id: "n1", tip: "kacirilan_tur", mesaj: "A blok turu kaçırıldı", okundu: false, created_at: "2026-10-02T08:00:00Z" },
    ] },
  });
  ciz(NotificationsPage);
  await waitFor(() => expect(screen.getByText("A blok turu kaçırıldı")).toBeTruthy());
  expect(screen.getByText("Kaçırılan devriye turu")).toBeTruthy();
  expect(c.some((u) => u.includes("/api/push/teshis"))).toBe(false);
});

it("sade teslim aciklamasi: ham kod degil, ne yapilacagi", () => {
  expect(tr[teslimAciklamasi("geri_dondu")!]).toBe("E-posta adresi geçersiz olabilir.");
  expect(teslimAciklamasi("iletildi")).toBeNull();
  expect(tr.odemeKoduDurumgeri_dondu).toBe("Ulaşmadı");
});
