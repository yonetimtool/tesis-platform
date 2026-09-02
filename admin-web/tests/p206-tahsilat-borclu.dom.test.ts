// @vitest-environment jsdom
// (P206 §2) TAHSILAT PENCERESI — BORCLU LISTESI.
//
// ===========================================================================
// OLCULEN KOK NEDEN (yetki DEGIL)
// ===========================================================================
// "Borclu kisi listesi bos geliyor" sikayetinin sebebi YETKI DEGILDI:
// istemci `/api/users?limit=500` istiyordu, uc 200 tavaninda 422
// `validation_error` donuyordu ve SWR hatasi sessizce yutulup liste BOS
// ciziliyordu (dev API'de olculdu: `/users?limit=500` -> 422).
//
// Bu dosya UC seyi kilitler:
//   1. Liste BORCLULARDAN gelir (tutar ve daireyle birlikte),
//   2. Borclu YOKSA kullaniciya SOYLENIR — bos secim birakilmaz,
//   3. Kisi ucu HATA verirse ekran bunu GOSTERIR (sessiz bos liste yok).
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import Sayfa from "@/app/(protected)/finans/tahsilatlar/page";
import { tr } from "@/lib/i18n/sozluk/tr";

import { ciz } from "./yardimci";

type Cagri = { url: string; metot: string; govde: Record<string, unknown> };

const BORCLULAR = {
  kovalar: [
    {
      kova: "0-30",
      daireler: [
        {
          unit_id: "u-1",
          unit_no: "A-3",
          kalan_kurus: 125000,
          borclu_ad: "Ahmet Borclu",
          borclu_user_id: "k-1",
        },
        {
          // KISISIZ DAIRE: tahsilat bir KISIYE yazilir; sahipsiz daire
          // secilirse kaydin kime ait oldugu belirsiz olurdu.
          unit_id: "u-2",
          unit_no: "A-4",
          kalan_kurus: 5000,
          borclu_ad: null,
          borclu_user_id: null,
        },
      ],
    },
  ],
};

function taklit(opts: { borclular?: unknown; kisiDurumu?: number } = {}): Cagri[] {
  const cagrilar: Cagri[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL, init?: RequestInit) => {
    const url = String(girdi);
    const metot = (init?.method ?? "GET").toUpperCase();
    cagrilar.push({
      url,
      metot,
      govde: init?.body ? JSON.parse(String(init.body)) : {},
    });
    let govde: unknown = { items: [], meta: { total: 0 } };
    let durum = 200;
    if (url.includes("/api/panel/yaslandirma")) {
      govde = opts.borclular ?? BORCLULAR;
    } else if (url.startsWith("/api/users")) {
      durum = opts.kisiDurumu ?? 200;
      govde =
        durum === 200
          ? { items: [{ id: "k-9", ad: "Pesin Odeyen" }], meta: { total: 1 } }
          : { error: { code: "validation_error", message: "limit" } };
    } else if (url.includes("/api/panel/kasalar")) {
      govde = { items: [{ id: "kasa-1", ad: "Merkez Kasa", kod: "K1" }] };
    } else if (url.includes("/api/units")) {
      govde = { items: [{ id: "u-1", no: "A-3" }], meta: { total: 1 } };
    }
    return new Response(JSON.stringify(govde), {
      status: durum,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return cagrilar;
}

const kanca = (ad: string) =>
  document.querySelector(`[data-test="${ad}"]`) as HTMLElement | null;

async function pencereyiAc(k: ReturnType<typeof userEvent.setup>) {
  ciz(Sayfa);
  await waitFor(() => expect(screen.getAllByText(tr.finansYeni).length).toBeGreaterThan(0));
  await k.click(screen.getAllByText(tr.finansYeni)[0]);
  await waitFor(() => expect(kanca("tahsilat-kisi")).toBeTruthy());
}

afterEach(() => vi.restoreAllMocks());

it("BORCLULAR listelenir: ad + daire + KALAN TUTAR", async () => {
  // Yonetici "hangi Ahmet" ve "ne kadar" sorularini SECMEDEN ONCE
  // yanitlayabilmeli; yalniz ad yazan bir liste onu tahmine zorlardi.
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  const secim = kanca("tahsilat-kisi") as HTMLSelectElement;
  const metinler = Array.from(secim.options).map((o) => o.textContent ?? "");
  expect(metinler.some((m) => m.includes("Ahmet Borclu") && m.includes("A-3"))).toBe(true);
  expect(metinler.some((m) => m.includes("1.250,00"))).toBe(true);
  // KISISIZ daire listede YOK.
  expect(metinler.some((m) => m.includes("A-4"))).toBe(false);
});

it("BORCLU YOKSA kullaniciya SOYLENIR — bos secim birakilmaz", async () => {
  // Kabul kriteri 6.
  const k = userEvent.setup();
  taklit({ borclular: { kovalar: [] } });
  await pencereyiAc(k);
  await waitFor(() => expect(kanca("tahsilat-borclu-yok")).toBeTruthy());
  expect(kanca("tahsilat-borclu-yok")!.textContent).toBe(tr.finansBorcluYok);
});

it("KISI UCU HATA VERIRSE ekran SOYLER (sessiz bos liste yok)", async () => {
  // KOK NEDENIN kilidi: 422 sessizce yutulup liste bos cizilmisti.
  const k = userEvent.setup();
  taklit({ kisiDurumu: 422 });
  await pencereyiAc(k);
  await k.click(kanca("tahsilat-pesin")!);
  await waitFor(() =>
    expect(screen.getByText(tr.finansKisiListesiAlinamadi)).toBeTruthy(),
  );
});

it("ARAMA listeyi daraltir ve sonuc yoksa SOYLER", async () => {
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.type(kanca("tahsilat-kisi-ara")!, "A-3");
  await waitFor(() =>
    expect((kanca("tahsilat-kisi") as HTMLSelectElement).options.length).toBe(2),
  );
  await k.clear(kanca("tahsilat-kisi-ara")!);
  await k.type(kanca("tahsilat-kisi-ara")!, "bulunmayan");
  await waitFor(() => expect(kanca("tahsilat-arama-bos")).toBeTruthy());
});

it("PESIN ODEME acilinca TUM kisiler listelenir (P192 alacakta bekler)", async () => {
  const k = userEvent.setup();
  taklit();
  await pencereyiAc(k);
  await k.click(kanca("tahsilat-pesin")!);
  await waitFor(() => {
    const s = kanca("tahsilat-kisi") as HTMLSelectElement;
    expect(Array.from(s.options).some((o) => o.textContent === "Pesin Odeyen")).toBe(true);
  });
});

it("BORCLU SECILINCE DAIRE de dolar ve govdede GIDER", async () => {
  // Borc daireye baglidir; daireyi elle sectirmek yanlis daireye makbuz
  // kesme riskini bedavaya ekliyordu.
  const k = userEvent.setup();
  const cagrilar = taklit();
  await pencereyiAc(k);
  await k.selectOptions(kanca("tahsilat-kisi")!, "k-1");
  await k.type(screen.getByLabelText(new RegExp(tr.finansAlanTutar, "i")), "100");
  await k.click(screen.getByText(tr.ortakKaydet));

  await waitFor(() =>
    expect(cagrilar.some((c) => c.url === "/api/panel/finans-tahsilat")).toBe(true),
  );
  const post = cagrilar.find((c) => c.url === "/api/panel/finans-tahsilat")!;
  expect(post.govde.user_id).toBe("k-1");
  expect(post.govde.unit_id).toBe("u-1");
});
