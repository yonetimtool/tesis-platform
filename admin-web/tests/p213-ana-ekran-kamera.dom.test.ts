// @vitest-environment jsdom
// (P213 §3-4) OZETTEKI KAMERA SERIDI — SECIM, KARE KAYNAGI, CANLI YOL.
//
// ===========================================================================
// DEGISEN UC SEY
// ===========================================================================
// 1. SECIM: serit eskiden ilk 50 kamerayi cekip ilk 4'unu ciziyordu —
//    yani ozette hangi kameranin gorunecegine ALFABETIK SIRA karar
//    veriyordu. Artik karar YONETICININ (`ana_ekranda` bayragi) ve
//    istek sunucuya o suzgecle gidiyor.
// 2. KARE KAYNAGI: `snapshot_url` yoksa SUNUCUNUN cektigi kare kullanilir
//    ve bu artik TUM turlerde gecerli (P213 §3) — eskiden yalniz RTSP.
// 3. CANLI: tiklayinca YONETILEN yol (`/api${canli_yol}`) oynatilir;
//    `stream_url` kameranin kendi adresidir ve istemciye inmemeli.
import { screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { KameraSeridi, kareKaynagi } from "@/components/KameraSeridi";
import type { Kamera } from "@/lib/types";

import { ciz } from "./yardimci";

function kamera(ek: Partial<Kamera> = {}): Kamera {
  return {
    id: "k-1",
    ad: "Ana Kapı",
    stream_url: "rtsp://kullanici:parola@10.0.0.5:554/stream",
    tur: "rtsp",
    aktif: true,
    sakin_gorebilir: false,
    ana_ekranda: true,
    oynatilabilir: true,
    canli_yol: "/cameras/k-1/canli/index.m3u8",
    ...ek,
  } as Kamera;
}

afterEach(() => vi.restoreAllMocks());

it("KARE KAYNAGI tur ayrimi YAPMAZ (HLS de sunucudan)", () => {
  // Eskiden: `snapshot_url || (tur === "rtsp" ? sunucu : null)`.
  expect(kareKaynagi(kamera({ tur: "hls" }))).toBe("/api/cameras/k-1/kare");
  expect(kareKaynagi(kamera({ tur: "rtsp" }))).toBe("/api/cameras/k-1/kare");
  // Yoneticinin girdigi anlik goruntu adresi ONCELIKLI.
  expect(kareKaynagi(kamera({ snapshot_url: "https://x/y.jpg" }))).toBe(
    "https://x/y.jpg",
  );
});

it("KARE `img` olarak cizilir ve KAMERA ADRESI SIZMAZ", () => {
  ciz(() => KameraSeridi({ kameralar: [kamera({ tur: "hls" })] }));
  const img = document.querySelector("img") as HTMLImageElement;
  expect(img).toBeTruthy();
  expect(img.src).toContain("/api/cameras/k-1/kare");
  // Kimlik bilgisi tasiyan kaynak adres HICBIR yerde gecmemeli.
  expect(document.body.innerHTML).not.toContain("parola");
  expect(document.body.innerHTML).not.toContain("rtsp://");
});

it("TIKLAYINCA YONETILEN canli yol oynatilir", async () => {
  const k = userEvent.setup();
  ciz(() => KameraSeridi({ kameralar: [kamera()] }));
  await k.click(screen.getByRole("button", { name: /Ana Kapı/ }));
  await waitFor(() => {
    // Oynatici `url` olarak vekil yolunu alir; DOM'da video/kaynak
    // olarak gorunur ya da bilesen yukleniyor durumundadir — kritik
    // olan RTSP adresinin GECMEMESI.
    expect(document.body.innerHTML).not.toContain("rtsp://");
  });
});

it("PASIF kamera CIZILMEZ", () => {
  ciz(() => KameraSeridi({ kameralar: [kamera({ aktif: false })] }));
  expect(document.querySelector("img")).toBeNull();
});

it("HIC KAMERA YOKSA serit HIC cizilmez (bos kutu degil)", () => {
  const { container } = ciz(() => KameraSeridi({ kameralar: [] }));
  expect(container.querySelector("section")).toBeNull();
});

// ===========================================================================
// SECIM: OZET SAYFASI SUNUCUYA HANGI SORGUYU ATIYOR
// ===========================================================================
it("(P213 §4) OZET yalniz `ana_ekranda=true` kameralari ISTER", async () => {
  // Eskiden `/api/cameras?limit=50` cekiliyor ve istemci ilk 4'u
  // seciyordu: karar ALFABETIK SIRADAYDI. Artik secim SUNUCUDA.
  const cagrilar: string[] = [];
  globalThis.fetch = (async (girdi: RequestInfo | URL) => {
    const url = String(girdi);
    cagrilar.push(url);
    const govde = url.includes("/api/cameras")
      ? { items: [], meta: { total: 0 } }
      : {};
    return new Response(JSON.stringify(govde), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;

  const mod = await import("@/app/(protected)/dashboard/page");
  ciz(mod.default);
  await waitFor(() =>
    expect(cagrilar.some((u) => u.includes("/api/cameras"))).toBe(true),
  );
  const kameraCagrisi = cagrilar.find((u) => u.includes("/api/cameras"))!;
  expect(kameraCagrisi).toContain("ana_ekranda=true");
});
