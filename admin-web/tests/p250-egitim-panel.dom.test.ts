// @vitest-environment jsdom
// (P250 §4) PANEL: baglanti dogrulama, kaydetmeden ONCE onizleme, govde.
import { act, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/egitim-videolari/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Olaylar = { onError?: (e: { data: number }) => void };
let olay: Olaylar = {};

beforeEach(() => {
  olay = {};
  window.YT = {
    PlayerState: { ENDED: 0 },
    Player: class {
      constructor(_el: HTMLElement, ayar: { events?: Olaylar }) {
        olay = ayar.events ?? {};
      }
      loadVideoById() {}
      cueVideoById() {}
      destroy() {}
    },
  } as unknown as Window["YT"];
});
afterEach(() => vi.restoreAllMocks());

function taklit() {
  const c: { url: string; metot: string; govde: Record<string, unknown> }[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const metot = (init?.method ?? "GET").toUpperCase();
    c.push({ url: String(girdi), metot, govde: init?.body ? JSON.parse(String(init.body)) : {} });
    const govde = metot === "GET"
      ? { set_kodu: "yonetici", adimlar: ["blok", "daire"], videolar: [] }
      : { adim_kodu: "blok", youtube_id: "dQw4w9WgXcQ", baslik: "Bloklar", sira: 10, aktif: true, surum: 1 };
    return new Response(JSON.stringify(govde), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

async function blokKarti() {
  ciz(Sayfa);
  await waitFor(() => expect(document.querySelector('[data-test="egitim-panel-blok"]')).toBeTruthy());
  return within(document.querySelector('[data-test="egitim-panel-blok"]') as HTMLElement);
}

it("gecersiz baglanti: anlasilir hata, istek gitmez", async () => {
  const c = taklit();
  const k = userEvent.setup();
  const kart = await blokKarti();
  await k.type(kart.getByLabelText(tr.egitimPanelBaglanti), "https://vimeo.com/1");
  await k.click(kart.getByRole("button", { name: tr.egitimPanelOnizle }));
  expect(kart.getByText(tr.egitimPanelGecersiz)).toBeTruthy();
  expect(c.some((x) => x.metot === "PUT")).toBe(false);
});

it("onizleme: gizli video uyarisi KAYDETMEDEN once gorunur", async () => {
  taklit();
  const k = userEvent.setup();
  const kart = await blokKarti();
  await k.type(kart.getByLabelText(tr.egitimPanelBaglanti), "https://youtu.be/dQw4w9WgXcQ");
  await k.click(kart.getByRole("button", { name: tr.egitimPanelOnizle }));
  await waitFor(() => expect(olay.onError).toBeTruthy());
  await act(async () => olay.onError?.({ data: 101 }));
  expect(screen.getByText(tr.egitimVideoKapali)).toBeTruthy();
});

it("kaydet: baglanti + baslik + varsayilan sira gider", async () => {
  const c = taklit();
  const k = userEvent.setup();
  const kart = await blokKarti();
  await k.type(kart.getByLabelText(tr.egitimPanelBaglanti), "https://www.youtube.com/watch?v=dQw4w9WgXcQ");
  await k.type(kart.getByLabelText(tr.egitimPanelBaslikAlan), "Bloklar");
  await k.click(kart.getByRole("button", { name: tr.ortakKaydet }));
  await waitFor(() => expect(c.some((x) => x.metot === "PUT")).toBe(true));
  const put = c.find((x) => x.metot === "PUT")!;
  expect(put.url).toBe("/api/egitim-videolari/yonetim/blok");
  expect(put.govde).toMatchObject({
    baglanti: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    baslik: "Bloklar",
    sira: 10,
    aktif: true,
  });
});
