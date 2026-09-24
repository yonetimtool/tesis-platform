// @vitest-environment jsdom
// (E2E 2026-09 / GUVENLIK-07) OZET KAMERA SERIDI — YUKLENIYOR / HATA != BOS.
//
// OLCULEN KUSUR (yuk altinda, BFF `/api/cameras?ana_ekranda=true` 503):
// serit yalniz `data`yi aliyordu ve bos listeyi "Ana ekranda gosterilecek
// kamera secilmedi ... isaretleyin" diye anlatiyordu — yonetici zaten
// yaptigi ayari yeniden yapmaya yollaniyordu. Veri gelmeden once de ayni
// cumle yanip sonuyordu. Ayrica kare 502 dondugunde karo KIRIK RESIM
// ikonu ciziyordu (`<img>`de `onError` yoktu); kameralar sayfasi ayni
// durumda "Baglanti yok" der.
import { fireEvent, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { KameraSeridi } from "@/components/KameraSeridi";

import { ciz } from "./yardimci";

const SECILMEDI = /Ana ekranda gösterilecek kamera seçilmedi/;
const YUKLENEMEDI = /Kameralar yüklenemedi/;

const KAMERA = {
  id: "k-1",
  ad: "Ana Kapı",
  konum: null,
  stream_url: "rtsp://10.0.0.4/s",
  restream_url: null,
  snapshot_url: null,
  tur: "rtsp" as const,
  aktif: true,
  sakin_gorebilir: false,
  oynatilabilir: true,
};

function sayim(toplam: number) {
  const adresler: string[] = [];
  globalThis.fetch = (async (g: RequestInfo | URL) => {
    adresler.push(String(g));
    return new Response(JSON.stringify({ meta: { total: toplam }, items: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }) as typeof fetch;
  return adresler;
}

afterEach(() => vi.restoreAllMocks());

describe("GUVENLIK-07 kamera seridi durumlari", () => {
  it("HATA'da 'secilmedi' DENMEZ, hata soylenir ve sayim istenmez", async () => {
    const adresler = sayim(6);
    ciz(() => KameraSeridi({ kameralar: [], rol: "yonetici", hata: true }));
    expect(await screen.findByText(YUKLENEMEDI)).toBeInTheDocument();
    expect(screen.queryByText(SECILMEDI)).toBeNull();
    expect(adresler.some((u) => u.includes("/api/cameras?limit=1"))).toBe(false);
  });

  it("YUKLENIRKEN 'secilmedi' DENMEZ (yanip sonme yok)", async () => {
    sayim(6);
    const { container } = ciz(() =>
      KameraSeridi({ kameralar: [], rol: "yonetici", yukleniyor: true }),
    );
    await waitFor(() =>
      expect(container.querySelector("[aria-busy='true']")).not.toBeNull(),
    );
    expect(screen.queryByText(SECILMEDI)).toBeNull();
  });

  it("GERCEKTEN bos liste + sayim geldikten sonra 'secilmedi' soylenir", async () => {
    sayim(6);
    ciz(() => KameraSeridi({ kameralar: [], rol: "yonetici" }));
    expect(await screen.findByText(SECILMEDI)).toBeInTheDocument();
  });

  it("HATA SAKINE/DENETCIYE gosterilmez (kameralara erisemez; gurultu olurdu)", async () => {
    sayim(6);
    const { container } = ciz(() =>
      KameraSeridi({ kameralar: [], rol: "denetci", hata: true }),
    );
    await waitFor(() => expect(container.textContent).toBe(""));
  });

  it("KARE HATASINDA kirik resim degil 'Baglanti yok'", async () => {
    sayim(6);
    const { container } = ciz(() =>
      KameraSeridi({ kameralar: [KAMERA], rol: "yonetici" }),
    );
    const img = await waitFor(() => {
      const i = container.querySelector("img");
      expect(i).not.toBeNull();
      return i!;
    });
    fireEvent.error(img);
    expect(await screen.findByText("Bağlantı yok")).toBeInTheDocument();
    expect(container.querySelector("img")).toBeNull();
  });
});
