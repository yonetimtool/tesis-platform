// @vitest-environment jsdom
// (P211 §5) MESAI KATSAYISI EKRANDAN DEGISTIRILEBILIR.
//
// ===========================================================================
// OLCULEN BOSLUK
// ===========================================================================
// P203 `tenant.mesai_katsayisi` sutununu acti ve "degistirilebilir" dedi;
// ama ne uc ne ekran onu yaziyordu — soz ancak veritabanina SQL yazarak
// tutuluyordu. Ekranda katsayi yalnizca bir ROZET olarak GORUNUYORDU.
//
// Kilitlenen davranis: alan gorunur, PATCH gider, ozet YENIDEN CEKILIR
// (yoksa yoneticinin gordugu tutarla yazacagi gider ayrisirdi) ve
// degisiklikn kapsamini soyleyen not cizilir.
//
// Taklit HTTP katmaninda (P200 dersi).
import { waitFor } from "@testing-library/react";
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
  ],
};

function taklit(): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    cagrilar.push({
      url,
      metot: (init?.method ?? "GET").toUpperCase(),
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    const govde = url.startsWith("/api/mesai/ozet") ? OZET : { katsayi: 2 };
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

it("KATSAYI DUZENLENIR: PATCH gider ve OZET yeniden cekilir", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-katsayi-duzenle")).toBeTruthy());
  await k.click(kanca("mesai-katsayi-duzenle")!);

  const alan = kanca("mesai-katsayi-alan") as HTMLInputElement;
  expect(alan.value).toBe("1.5"); // MEVCUT deger on-dolar
  await k.clear(alan);
  await k.type(alan, "2");
  await k.click(kanca("mesai-katsayi-kaydet")!);

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/mesai/ayar" && c.metot === "PATCH")).toBe(true),
  );
  const patch = cagrilar.find((c) => c.metot === "PATCH")!;
  expect(patch.govde).toEqual({ katsayi: 2 });
  // OZET YENIDEN CEKILDI: eski tutarla yeni katsayi ekranda ayrismasin.
  expect(cagrilar.filter((c) => c.url.startsWith("/api/mesai/ozet")).length).toBeGreaterThan(1);
});

it("VIRGULLU giris de kabul edilir (2,5 -> 2.5)", async () => {
  // Turkce klavyede ondalik ayirici VIRGULdur; `Number("2,5")` NaN'dir
  // ve sessizce hicbir sey gondermemek "kaydettim" sanmaya davettir.
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-katsayi-duzenle")).toBeTruthy());
  await k.click(kanca("mesai-katsayi-duzenle")!);
  const alan = kanca("mesai-katsayi-alan") as HTMLInputElement;
  await k.clear(alan);
  await k.type(alan, "2,5");
  await k.click(kanca("mesai-katsayi-kaydet")!);
  await waitFor(() =>
    expect(cagrilar.some((c) => c.metot === "PATCH")).toBe(true),
  );
  expect(cagrilar.find((c) => c.metot === "PATCH")!.govde).toEqual({ katsayi: 2.5 });
});

it("DEGISIKLIGIN KAPSAMI yazilir (gecmise dokunmaz)", async () => {
  const k = userEvent.setup();
  taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-katsayi-duzenle")).toBeTruthy());
  await k.click(kanca("mesai-katsayi-duzenle")!);
  expect(kanca("mesai-katsayi-notu")!.textContent).toBe(tr.mesaiKatsayiNotu);
});

it("IPTAL: istek GITMEZ", async () => {
  const k = userEvent.setup();
  const cagrilar = taklit();
  ciz(Sayfa);
  await waitFor(() => expect(kanca("mesai-katsayi-duzenle")).toBeTruthy());
  await k.click(kanca("mesai-katsayi-duzenle")!);
  await k.click(kanca("mesai-katsayi-alan")!);
  const iptal = Array.from(document.querySelectorAll("button")).find(
    (b) => b.textContent === tr.ortakIptal,
  )!;
  await k.click(iptal);
  expect(cagrilar.some((c) => c.metot === "PATCH")).toBe(false);
  expect(kanca("mesai-katsayi-alan")).toBeNull();
});
