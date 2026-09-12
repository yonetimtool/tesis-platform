// @vitest-environment jsdom
// (P223 §1) ANA EKRANDA KAMERA YOKSA SEBEBI SOYLENIR.
//
// =========================================================================
// OLCULEN KUSUR
// =========================================================================
// Backend uctan uca CALISIYORDU — dev'de surulen akis:
//   PATCH /cameras/{id} {"ana_ekranda": true}  -> 200
//   GET /cameras?ana_ekranda=true              -> meta.total 1
//   GET /cameras/{id}/kare                     -> 200 image/jpeg 12 461 bayt
// Veritabani sayimi ise: 6 kamera, ana_ekranda = 0.
//
// Serit `if (gorunen.length === 0) return null` diyordu: isaretli kamera
// yokken bolum HIC cizilmiyordu. Kullanici Kameralar sekmesinde kareleri
// goruyor (o sayfa TUM kameralari ceker), ana sayfada hicbir sey
// gormuyor ve NEDENINI soyleyen tek satir bile yok — P217'nin "sifir
// sonucu sessizce yutma" dersinin tekrari.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { KameraSeridi } from "@/components/KameraSeridi";

import { ciz } from "./yardimci";

const json = (govde: unknown) =>
  new Response(JSON.stringify(govde), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });

function sahtele(toplam: number) {
  globalThis.fetch = (async () => json({ meta: { total: toplam }, items: [] })) as typeof fetch;
}

const KAMERA = {
  id: "k-1",
  ad: "Ana Kapı",
  konum: null,
  stream_url: "https://a.test/x.m3u8",
  restream_url: null,
  snapshot_url: null,
  tur: "hls" as const,
  aktif: true,
  sakin_gorebilir: true,
  oynatilabilir: true,
};

afterEach(() => vi.restoreAllMocks());

const SECILMEDI = /Ana ekranda gösterilecek kamera seçilmedi/;
const HIC_YOK = /Henüz kamera eklenmemiş/;

describe("P223 ana ekran kamera bos hali", () => {
  it("ISARETLI KAMERA YOKKEN yoneticiye SEBEP soylenir", async () => {
    sahtele(6); // tesiste kamera VAR, isaretli olan yok
    ciz(() => KameraSeridi({ kameralar: [], rol: "yonetici" }));
    expect(await screen.findByText(SECILMEDI)).toBeInTheDocument();
  });

  it("TESISTE HIC KAMERA YOKSA mesaj FARKLI", async () => {
    // "Secilmedi" demek yanlis yonlendirme olurdu: isaretlenecek kamera
    // yok ki.
    sahtele(0);
    ciz(() => KameraSeridi({ kameralar: [], rol: "yonetici" }));
    expect(await screen.findByText(HIC_YOK)).toBeInTheDocument();
  });

  it("SAKINE gosterilmez — isareti koyamaz, gurultu olurdu", async () => {
    sahtele(6);
    const { container } = ciz(() =>
      KameraSeridi({ kameralar: [], rol: "resident" }),
    );
    await waitFor(() => expect(container.textContent).toBe(""));
  });

  it("KAMERA VARSA serit cizilir, bos hal mesaji YOK", async () => {
    sahtele(6);
    ciz(() => KameraSeridi({ kameralar: [KAMERA], rol: "yonetici" }));
    expect(await screen.findByText("Ana Kapı")).toBeInTheDocument();
    expect(screen.queryByText(SECILMEDI)).toBeNull();
  });

  it("bos halde TESIS KAMERA SAYISI sorulur, dolu halde SORULMAZ", async () => {
    // Ek istek YALNIZ bos halde atilmali: her pano acilisinda fazladan
    // bir istek, gorunmeyen bir maliyet olurdu.
    const adresler: string[] = [];
    globalThis.fetch = (async (g: RequestInfo | URL) => {
      adresler.push(String(g));
      return json({ meta: { total: 6 }, items: [] });
    }) as typeof fetch;

    ciz(() => KameraSeridi({ kameralar: [KAMERA], rol: "yonetici" }));
    await waitFor(() => expect(screen.getByText("Ana Kapı")).toBeInTheDocument());
    expect(adresler.some((u) => u.includes("/api/cameras?limit=1"))).toBe(false);
  });
});
