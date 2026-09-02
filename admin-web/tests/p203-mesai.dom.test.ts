// @vitest-environment jsdom
// (P203 §5) FAZLA MESAI EKRANI.
//
// Olculen sey EKRANIN DAVRANISI + GIDEN GOVDE. Hesabin kendisi
// sunucuda kilitli (backend test_p203_mesai_*); burada olculen,
// arayuzun PARAYA DONUSEN bir sayiyi dogru sunup sunmadigi:
// ucreti tanimsiz kisiye 0 TL YAZMAMASI ve ONAY ADIMINI soylemesi.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/finans/mesai/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const OZET = {
  yil: 2026,
  ay: 9,
  katsayi: 1.5,
  kaynak: "plan",
  kisiler: [
    {
      user_id: "u-1",
      ad: "Ali Guvenlik",
      toplam_saat: 84,
      fazla_saat: 15,
      saatlik_ucret_kurus: 10000,
      fazla_mesai_kurus: 225000,
      ucret_tanimsiz: false,
      gidere_yazildi: false,
    },
    {
      user_id: "u-2",
      ad: "Ucretsiz Kisi",
      toplam_saat: 50,
      fazla_saat: 5,
      saatlik_ucret_kurus: null,
      fazla_mesai_kurus: null,
      ucret_tanimsiz: true,
      gidere_yazildi: false,
    },
    {
      user_id: "u-3",
      ad: "Yazilmis Kisi",
      toplam_saat: 60,
      fazla_saat: 15,
      saatlik_ucret_kurus: 10000,
      fazla_mesai_kurus: 225000,
      ucret_tanimsiz: false,
      gidere_yazildi: true,
    },
  ],
};

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    const govde = url.startsWith("/api/mesai/ozet") ? OZET : { ok: true };
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

afterEach(() => vi.restoreAllMocks());

it("HESABIN KAYNAGI acikca soylenir", async () => {
  // Sistemde giris-cikis kaydi YOK; hesap PLAN uzerinden. Bunu
  // gizlemek, PARAYA donusen bir sayiyi olculmus gibi gostermek olurdu.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-kaynak-notu")).toBeTruthy());
  expect(kanca("mesai-kaynak-notu")!.textContent).toBe(tr.mesaiKaynakPlan);
});

it("UCRETI TANIMSIZ kisiye 0 TL YAZILMAZ, UYARI cizilir", async () => {
  // "0,00 TL" yazmak, yoneticiye "mesai yok" demenin sessiz ve yanlis
  // yoluydu — ustelik o kisinin 5 saat fazla mesaisi VAR.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-satir-u-2")).toBeTruthy());
  const satir = kanca("mesai-satir-u-2")!;
  expect(satir.textContent).toContain(tr.mesaiUcretTanimsiz);
  expect(satir.textContent).not.toContain("0,00");
});

it("ZATEN YAZILMIS kisi isaretli ve TOPLAMA KATILMAZ", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-satir-u-3")).toBeTruthy());
  expect(kanca("mesai-satir-u-3")!.textContent).toContain(tr.mesaiYazilmis);
  // Yazilabilir yalniz u-1: toplam 225.000 kurus = 2.250,00 TL.
  expect(kanca("mesai-toplam")!.textContent).toContain("1");
  expect(kanca("mesai-toplam")!.textContent).toContain("2.250,00");
});

it("ONAY ADIMI acikca yazilir", async () => {
  // Yonetici "yazdim, bitti" sanip onayi atlarsa gider HIC
  // GERCEKLESMEZ — bakiye dusmez.
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-gidere-yaz")).toBeTruthy());
  expect(screen.getByText(tr.mesaiOnayNotu)).toBeTruthy();
});

it("GIDERE YAZ dogru uca, YALNIZ YAZILABILIR kisilerle gider", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-gidere-yaz")).toBeTruthy());
  await k.click(kanca("mesai-gidere-yaz")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/mesai/gidere-yaz")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/mesai/gidere-yaz")!;
  expect(post.govde).toEqual({
    yil: 2026,
    ay: 9,
    // Ucreti tanimsiz (u-2) ve zaten yazilmis (u-3) DISARIDA.
    satirlar: [{ user_id: "u-1" }],
  });
});

it("DONEM DEGISINCE sunucudan YENI ay istenir", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-ay")).toBeTruthy());
  await k.selectOptions(kanca("mesai-ay")!, "3");
  await waitFor(() =>
    expect(cagrilar.some((c) => c.url.includes("ay=3"))).toBe(true),
  );
});
