// @vitest-environment jsdom
// (P251 §5) ORTAK GORSEL — gosterim + secici; etkinlik yonetimi gorseli
// gosterir ve kaydeder (mobilden eklenen gorsel webde gorunmuyordu);
// rezervasyon alani gorsel alir.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { createElement } from "react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import EtkinlikYonetimPage from "@/app/(protected)/etkinlik-yonetimi/page";
import RezervasyonYonetimiPage from "@/app/(protected)/rezervasyon-yonetimi/page";
import { IcerikGorseli } from "@/components/gorsel/icerik-gorseli";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), refresh: vi.fn() }),
  usePathname: () => "/x",
  useSearchParams: () => new URLSearchParams(),
}));
afterEach(() => vi.restoreAllMocks());

type Cagri = { url: string; metot: string; govde: unknown };
function taklit(harita: Record<string, unknown>): Cagri[] {
  const c: Cagri[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL, init?: RequestInit) => {
    const url = String(g);
    const metot = (init?.method ?? "GET").toUpperCase();
    let govde: unknown = null;
    try { govde = init?.body && typeof init.body === "string" ? JSON.parse(init.body) : null; } catch { govde = null; }
    c.push({ url, metot, govde });
    if (url.startsWith("http://depo")) return new Response(null, { status: 200 });
    if (url === "/api/uploads/presign") {
      return new Response(JSON.stringify({ foto_key: "t1/tasks/a.png", upload_url: "http://depo/put" }), {
        status: 200, headers: { "Content-Type": "application/json" } });
    }
    const anahtar = Object.keys(harita).filter((k) => url.startsWith(k)).sort((a, b) => b.length - a.length)[0];
    const yanit = metot === "GET" ? (anahtar ? harita[anahtar] : { items: [] }) : { id: "yeni" };
    return new Response(JSON.stringify(yanit), { status: 200, headers: { "Content-Type": "application/json" } });
  }) as typeof fetch;
  return c;
}

it("gosterim: gorsel yoksa kucuk ikon kutusu, buyuk hic; hata olunca ayni", () => {
  ciz(() =>
    createElement("div", null,
      createElement(IcerikGorseli, { url: null, alt: "a", boy: "kucuk", tur: "alan" }),
      createElement(IcerikGorseli, { url: null, alt: "b", boy: "buyuk", tur: "alan" }),
      createElement(IcerikGorseli, { url: "http://x/k.png", alt: "c", boy: "kucuk", tur: "etkinlik" }),
      createElement(IcerikGorseli, { url: "http://x/b.png", alt: "d", boy: "buyuk", tur: "etkinlik" }),
    ));
  expect(document.querySelectorAll('[data-test="icerik-gorseli-yok"]')).toHaveLength(1);
  const kucuk = document.querySelector('[data-test="icerik-gorseli-kucuk"]')!;
  const buyuk = document.querySelector('[data-test="icerik-gorseli-buyuk"]')!;
  fireEvent.error(kucuk);
  fireEvent.error(buyuk);
  expect(document.querySelectorAll('[data-test="icerik-gorseli-yok"]')).toHaveLength(2);
  expect(document.querySelector('[data-test="icerik-gorseli-buyuk"]')).toBeNull();
  // Eski "Gorsel goruntulenemedi" kirik kutusu yok.
  expect(screen.queryByText(tr.gorselGosterilemedi)).toBeNull();
});

const ETKINLIK = {
  id: "e1", baslik: "Mobil etkinlik", aciklama: "x", tarih: "2026-10-05T09:00:00Z",
  konum: null, foto_key: "t1/tasks/m.png", foto_url: "http://minio/m.png",
};

it("etkinlik yonetimi: mobilden gelen gorsel listede kucuk gorunur", async () => {
  taklit({ "/api/events": { items: [ETKINLIK] } });
  ciz(EtkinlikYonetimPage);
  await waitFor(() => expect(document.querySelector('[data-test="icerik-gorseli-kucuk"]')).toBeTruthy());
  expect((document.querySelector('[data-test="icerik-gorseli-kucuk"]') as HTMLImageElement).src).toBe("http://minio/m.png");
});

it("etkinlik yonetimi: gorsel secilir, yuklenir ve foto_key kaydedilir", async () => {
  const c = taklit({ "/api/events": { items: [] } });
  const k = userEvent.setup();
  globalThis.URL.createObjectURL = vi.fn(() => "blob:onizleme");
  globalThis.URL.revokeObjectURL = vi.fn();
  ciz(EtkinlikYonetimPage);
  await k.click(await screen.findByRole("button", { name: tr.etkinlikYeni }));
  await k.type(screen.getByLabelText(new RegExp(tr.ortakBaslik)), "Bayram");
  await k.type(screen.getByLabelText(new RegExp(tr.ortakAciklama)), "Kutlama");
  fireEvent.change(screen.getByLabelText(new RegExp(tr.etkinlikBaslangic)), { target: { value: "2026-11-01T10:00" } });
  const dosya = new File([new Uint8Array([1, 2])], "a.png", { type: "image/png" });
  await k.upload(screen.getByLabelText(tr.duyuruGorselOpsiyonel), dosya);
  await waitFor(() => expect(c.some((x) => x.url === "http://depo/put" && x.metot === "PUT")).toBe(true));
  await k.click(screen.getByRole("button", { name: tr.ortakKaydet }));
  await waitFor(() => expect(c.some((x) => x.url === "/api/events" && x.metot === "POST")).toBe(true));
  expect(c.find((x) => x.url === "/api/events" && x.metot === "POST")!.govde).toMatchObject({ foto_key: "t1/tasks/a.png" });
});

it("rezervasyon alani: listede gorsel, duzenlemede kaldir -> foto_key null", async () => {
  const c = taklit({
    "/api/common-areas": { items: [{ id: "a1", ad: "Havuz", aciklama: null, aktif: true, acilis: "09:00",
      kapanis: "22:00", slot_dakika: 60, foto_key: "t1/x.png", foto_url: "http://minio/havuz.png" }] },
    "/api/reservations": { items: [] },
  });
  const k = userEvent.setup();
  ciz(RezervasyonYonetimiPage);
  await waitFor(() => expect(document.querySelector('[data-test="icerik-gorseli-kucuk"]')).toBeTruthy());
  await k.click(screen.getByRole("button", { name: tr.rezYonDuzenle }));
  await k.click(await screen.findByRole("button", { name: tr.duyuruGorseliKaldir }));
  await k.click(screen.getByRole("button", { name: tr.ortakKaydet }));
  await waitFor(() => expect(c.some((x) => x.metot === "PATCH")).toBe(true));
  const p = c.find((x) => x.metot === "PATCH")!;
  expect(p.url).toBe("/api/common-areas/a1");
  expect(p.govde).toMatchObject({ foto_key: null });
});
