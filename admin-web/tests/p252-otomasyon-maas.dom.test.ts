// @vitest-environment jsdom
// (P252 §2) MAAS OTOMASYONU — otomasyon kurallari ekraninda:
//   * odeme gunu basina duz cumle ("Her ayin 5. gunu 3 personelin maasi");
//   * ac/kapat + otomatik onay ayari ayni `maas-ayari` kaydini yazar;
//   * "Simdi calistir" gunluk gorevle ayni ucu cagirir, sonucu soyler;
//   * onay bekleyen maaslar: tutar duzeltilerek tek onay, ya da toplu onay;
//   * son calisma cumlesi.
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { KurallarKarti } from "@/components/otomasyon/kurallar";
import { maasCumlesi, type MaasKurali } from "@/lib/otomasyon-cumle";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/finans/otomasyon",
  useSearchParams: () => new URLSearchParams(),
}));

afterEach(() => vi.restoreAllMocks());

const MAAS: MaasKurali = {
  aktif: true,
  otomatik_onay: true,
  gruplar: [
    { odeme_gunu: 5, personel_sayisi: 3, aylik_toplam_kurus: 7_500_000 },
    { odeme_gunu: 15, personel_sayisi: 1, aylik_toplam_kurus: 1_700_000 },
  ],
  personel_sayisi: 4,
  aylik_toplam_kurus: 9_200_000,
  onay_bekleyenler: [
    { id: "11111111-1111-4111-8111-111111111111", tarih: "2026-10-05",
      aciklama: "Ahmet YILMAZ — Ekim 2026 maaşı (kısmi: 12/31 gün)", tutar_kurus: 967_742 },
    { id: "22222222-2222-4222-8222-222222222222", tarih: "2026-10-05",
      aciklama: "Ayşe KAYA — Ekim 2026 maaşı", tutar_kurus: 2_500_000 },
  ],
};

function taklit(maas: MaasKurali = MAAS, calistir = { yazilan: 4, toplam_kurus: 9_200_000 }) {
  const c: { url: string; metot: string; govde: Record<string, unknown> }[] = [];
  const harita: Record<string, unknown> = {
    "/api/panel/maas-ayari": maas,
    "/api/panel/otomasyon-son-calismalar": { items: [
      { kural: "maas", tur: "maas", zaman: "2026-10-05T03:00:00Z", adet: 4, tutar_kurus: 9_200_000, durum: null },
    ] },
  };
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url, metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    let yanit: unknown = { items: [] };
    if (metot === "GET") {
      const k = Object.keys(harita).find((a) => url.startsWith(a));
      if (k) yanit = harita[k];
    } else if (url.includes("maaslar-calistir")) {
      yanit = calistir;
    } else if (url.includes("maaslar-onayla")) {
      yanit = { onaylanan: 2, toplam_kurus: 3_467_742 };
    } else {
      yanit = maas;
    }
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

const satir = () => document.querySelector('[data-test="kural-maas"]') as HTMLElement;

it("odeme gunu basina DUZ CUMLE + son calisma", async () => {
  taklit();
  ciz(KurallarKarti);
  await waitFor(() => expect(satir()).toBeTruthy());
  expect(satir().textContent).toContain("Her ayın 5. günü 3 personelin maaşı (toplam 75.000,00 ₺) gidere yazılır.");
  expect(satir().textContent).toContain("Her ayın 15. günü 1 personelin maaşı");
  expect(satir().textContent).toContain("4 personelin maaşı gidere yazıldı (toplam 92.000,00 ₺)");
});

it("personel yoksa ne yapilacagini soyler; calistir dugmesi kapali", () => {
  expect(maasCumlesi({ ...MAAS, gruplar: [] }, (k) => tr[k as keyof typeof tr] as string))
    .toBe(tr.otoKuralMaasYok);
});

it("ac/kapat ve otomatik onay AYNI kaydi yazar", async () => {
  const c = taklit();
  ciz(KurallarKarti);
  await waitFor(() => expect(satir()).toBeTruthy());
  await userEvent.click(within(satir()).getByRole("switch"));
  await waitFor(() => expect(c.some((x) => x.metot === "PATCH" && x.govde.aktif === false)).toBe(true));
  await userEvent.click(within(satir()).getByLabelText(tr.otoKuralMaasOtomatik));
  await waitFor(() =>
    expect(c.some((x) => x.metot === "PATCH" && x.url === "/api/panel/maas-ayari" && x.govde.otomatik_onay === false)).toBe(true),
  );
});

it("Simdi calistir: sonuc cumlesi", async () => {
  const c = taklit();
  ciz(KurallarKarti);
  await waitFor(() => expect(satir()).toBeTruthy());
  await userEvent.click(within(satir()).getByRole("button", { name: tr.otoKuralMaasCalistir }));
  expect(await screen.findByText("4 maaş gideri yazıldı (toplam 92.000,00 ₺).")).toBeTruthy();
  expect(c.some((x) => x.metot === "POST" && x.url === "/api/panel/maaslar-calistir")).toBe(true);
});

it("ikinci tetik: yazilacak yok denir (hata degil)", async () => {
  taklit(MAAS, { yazilan: 0, toplam_kurus: 0 });
  ciz(KurallarKarti);
  await waitFor(() => expect(satir()).toBeTruthy());
  await userEvent.click(within(satir()).getByRole("button", { name: tr.otoKuralMaasCalistir }));
  expect(await screen.findByText(tr.otoKuralMaasYazilacakYok)).toBeTruthy();
});

it("onay bekleyen: TUTAR DUZELTILEREK tek onay; toplu onay hepsini gonderir", async () => {
  const c = taklit();
  ciz(KurallarKarti);
  const blok = await screen.findByText(tr.otoMaasOnayBaslik);
  expect(blok).toBeTruthy();
  const ilk = document.querySelector(`[data-test="maas-bekleyen-${MAAS.onay_bekleyenler[0].id}"]`) as HTMLElement;
  const tutar = within(ilk).getByLabelText(tr.finansSutunTutar);
  expect(tutar).toHaveValue("9.677,42");
  await userEvent.clear(tutar);
  await userEvent.type(tutar, "10000");
  await userEvent.click(within(ilk).getByRole("button", { name: tr.otoMaasOnayla }));
  await waitFor(() => expect(c.some((x) => x.url.endsWith("/onayla") && x.metot === "POST")).toBe(true));
  const tek = c.find((x) => x.url === `/api/panel/finans-hareketler/${MAAS.onay_bekleyenler[0].id}/onayla`);
  expect(tek?.govde).toEqual({ tutar_kurus: 1_000_000 });

  await userEvent.click(screen.getByRole("button", { name: "Tümünü onayla (2)" }));
  await waitFor(() => expect(c.some((x) => x.url === "/api/panel/maaslar-onayla")).toBe(true));
  expect(c.find((x) => x.url === "/api/panel/maaslar-onayla")?.govde).toEqual({
    ids: MAAS.onay_bekleyenler.map((s) => s.id),
  });
});
