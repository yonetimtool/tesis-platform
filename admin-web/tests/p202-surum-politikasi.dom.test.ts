// @vitest-environment jsdom
// (P202) SURUM POLITIKASI EKRANI — PLATFORM YONETIMI.
//
// Olculen sey: operatorun girdigi degerin DOGRU UCA, DOGRU GOVDEYLE
// gitmesi ve gecersiz bir esigin GONDERILMEMESI.
//
// Neden govde olculuyor: yanlis bir esik TUM KULLANICILARI kilitler.
// "Ekran calisiyor gorunuyor" bu ozellik icin yeterli bir olcum degil.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/surum-politikasi/page";
import { OKUMA, YAZMA } from "@/lib/panel-vekil";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

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
    if (metot === "GET") {
      return new Response(
        JSON.stringify({
          ogeler: [
            {
              platform: "android",
              asgari_surum: "1.1.0",
              onerilen_surum: null,
              mesaj: { tr: "Guvenlik" },
            },
            {
              platform: "ios",
              asgari_surum: null,
              onerilen_surum: null,
              mesaj: {},
            },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }
    return new Response(JSON.stringify({ platform: "android" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

function kanca(ad: string): HTMLElement {
  const el = document.querySelector(`[data-test="${ad}"]`);
  if (!el) throw new Error(`bulunamadi: ${ad}`);
  return el as HTMLElement;
}

afterEach(() => vi.restoreAllMocks());

it("BFF beyaz listesi iki platformu da tasiyor", () => {
  // Genel `[kaynak]/[id]` vekili `id`yi UUID sanip "android"i reddeder
  // (P189'da olculen 405/404 sinifi). Kayitlar acikca olmali.
  expect(OKUMA["surum-politikasi"]).toBe("/surum-politikasi");
  expect(YAZMA["surum-politikasi-ios"]).toBe("/surum-politikasi/ios");
  expect(YAZMA["surum-politikasi-android"]).toBe("/surum-politikasi/android");
});

it("IKI PLATFORM ayri ayri cizilir ve mevcut degerler DOLU gelir", async () => {
  taklit();
  ciz(Sayfa);
  await waitFor(() =>
    expect((kanca("surum-asgari-android") as HTMLInputElement).value).toBe("1.1.0"),
  );
  expect((kanca("surum-asgari-ios") as HTMLInputElement).value).toBe("");
  expect((kanca("surum-mesaj-android-tr") as HTMLInputElement).value).toBe("Guvenlik");
});

it("KAYDET dogru uca, DOGRU GOVDEYLE gider", async () => {
  const cagrilar = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await waitFor(() => kanca("surum-asgari-android"));

  await k.clear(kanca("surum-asgari-android"));
  await k.type(kanca("surum-asgari-android"), "1.2.0");
  await k.type(kanca("surum-onerilen-android"), "1.3.0");
  await k.type(kanca("surum-mesaj-android-en"), "Update");
  await k.click(kanca("surum-kaydet-android"));

  await waitFor(() => expect(cagrilar.some((c) => c.metot === "PUT")).toBe(true));
  const put = cagrilar.find((c) => c.metot === "PUT")!;
  expect(put.url).toBe("/api/panel/surum-politikasi-android");
  expect(put.govde).toEqual({
    asgari_surum: "1.2.0",
    onerilen_surum: "1.3.0",
    mesaj: { tr: "Guvenlik", en: "Update" },
  });
});

it("GECERSIZ BICIM sunucuya GONDERILMEZ", async () => {
  // Sunucu da reddediyor (422) ama istek hic cikmamali: operator
  // "kaydedildi" sanip politikayi HIC calistirmamis olmamali.
  const cagrilar = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await waitFor(() => kanca("surum-asgari-ios"));

  await k.type(kanca("surum-asgari-ios"), "surum-3");
  expect(await screen.findByText("Sürüm 1.2.0 biçiminde olmalı.")).toBeTruthy();
  await k.click(kanca("surum-kaydet-ios"));
  expect(cagrilar.filter((c) => c.metot === "PUT")).toHaveLength(0);
});

it("BOSALTMA serbest — politikayi GERI ALMANIN yolu", async () => {
  // Yanlis bir esik girildiginde politikayi kaldirmak, sunucuya
  // gitmeden burada mumkun olmali. Bos = o seviye KAPALI.
  const cagrilar = taklit();
  const k = userEvent.setup();
  ciz(Sayfa);
  await waitFor(() => kanca("surum-asgari-android"));

  await k.clear(kanca("surum-asgari-android"));
  await k.click(kanca("surum-kaydet-android"));

  await waitFor(() => expect(cagrilar.some((c) => c.metot === "PUT")).toBe(true));
  expect(cagrilar.find((c) => c.metot === "PUT")!.govde.asgari_surum).toBeNull();
});
