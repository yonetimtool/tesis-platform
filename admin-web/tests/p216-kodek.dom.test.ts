// @vitest-environment jsdom
// (P216) KODEK — "yayin uretildi" ile "BU TARAYICI oynatabilir" ayri seyler.
//
// ===========================================================================
// NEDEN KARARI SUNUCU VEREMEZ
// ===========================================================================
// MediaMTX `fmp4` varyantiyla H265'i HLS'e KOYABILIYOR (sunucu tarafinda
// olculdu: playlist 200, CODECS="hvc1.4.10.L63.9e.8"). Ama oynatma
// tarayiciya bagli: Safari donanim destegiyle oynar, Chrome
// platform/donanima gore degisir, Firefox cogu kurulumda oynatmaz.
//
// Sunucunun "H265 gordum, 502 doneyim" demesi Safari kullanicisina ve
// MOBIL uygulamaya da yayini kapatmak olurdu — ikisi de oynatabiliyor.
// Karar istemcide: `MediaSource.isTypeSupported` KENDI tarayicisinin
// gercek yanitini verir, tahmin degil.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  kodekOnKontrolu,
  playlistKodegi,
  tarayiciOynatabilirMi,
} from "@/lib/kamera-hata";

import { ciz } from "./yardimci";

const H265_PLAYLIST = `#EXTM3U
#EXT-X-VERSION:9
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-STREAM-INF:BANDWIDTH=211340,CODECS="hvc1.4.10.L63.9e.8",RESOLUTION=640x360
video1_stream.m3u8`;
const H264_PLAYLIST = H265_PLAYLIST.replace("hvc1.4.10.L63.9e.8", "avc1.f40016");

/** `MediaSource.isTypeSupported`i belirli kodekler icin taklit eder. */
function mseSahtele(destekli: string[]) {
  (globalThis as unknown as { MediaSource: unknown }).MediaSource = {
    isTypeSupported: (tip: string) => destekli.some((k) => tip.includes(k)),
  };
}

afterEach(() => vi.restoreAllMocks());

describe("(P216) playlist kodegi okunur", () => {
  it("CODECS degeri cikarilir", () => {
    expect(playlistKodegi(H265_PLAYLIST)).toBe("hvc1.4.10.L63.9e.8");
    expect(playlistKodegi(H264_PLAYLIST)).toBe("avc1.f40016");
    expect(playlistKodegi("#EXTM3U\n")).toBeNull();
  });
});

describe("(P216) destek kararı TARAYICIYA sorulur", () => {
  it("destekleniyorsa true, desteklenmiyorsa false", () => {
    mseSahtele(["avc1"]);
    expect(tarayiciOynatabilirMi("avc1.f40016")).toBe(true);
    expect(tarayiciOynatabilirMi("hvc1.4.10.L63.9e.8")).toBe(false);
  });

  it("H265'i DESTEKLEYEN tarayicida true (Safari senaryosu)", () => {
    // Kritik: sunucu H265'i topyekun reddetseydi bu kullanici da
    // izleyemezdi. Karar istemcide oldugu icin izleyebiliyor.
    mseSahtele(["avc1", "hvc1"]);
    expect(tarayiciOynatabilirMi("hvc1.4.10.L63.9e.8")).toBe(true);
  });

  it("MSE YOKSA `null` — denemeye izin verir", () => {
    // Safari yerel HLS yolunda MSE kullanilmaz. Burada "oynatamaz"
    // demek, CALISAN bir yayini kapatmak olurdu.
    delete (globalThis as unknown as { MediaSource?: unknown }).MediaSource;
    expect(tarayiciOynatabilirMi("hvc1.4.10.L63.9e.8")).toBeNull();
    expect(tarayiciOynatabilirMi(null)).toBeNull();
  });
});

describe("(P216) on kontrol", () => {
  beforeEach(() => mseSahtele(["avc1"]));

  it("H265 playlist -> oynatilamaz", async () => {
    globalThis.fetch = (async () => new Response(H265_PLAYLIST, { status: 200 })) as typeof fetch;
    expect(await kodekOnKontrolu("/x.m3u8")).toEqual({
      kodek: "hvc1.4.10.L63.9e.8",
      oynatilir: false,
    });
  });

  it("H264 playlist -> oynatilir", async () => {
    globalThis.fetch = (async () => new Response(H264_PLAYLIST, { status: 200 })) as typeof fetch;
    expect(await kodekOnKontrolu("/x.m3u8")).toEqual({
      kodek: "avc1.f40016",
      oynatilir: true,
    });
  });

  it("playlist ALINAMAZSA `null` — oynatmayi engellemez", async () => {
    globalThis.fetch = (async () => new Response("yok", { status: 502 })) as typeof fetch;
    expect(await kodekOnKontrolu("/x.m3u8")).toBeNull();
    globalThis.fetch = (async () => {
      throw new Error("ağ");
    }) as typeof fetch;
    expect(await kodekOnKontrolu("/x.m3u8")).toBeNull();
  });
});

describe("(P216) oynatici — kullanicinin GORDUGU sey", () => {
  it("H265'te NE YAPACAGINI soyler, hls.js'i BOSUNA calistirmaz", async () => {
    mseSahtele(["avc1"]);
    const hlsYuklendi = vi.fn();
    vi.doMock("hls.js", () => {
      hlsYuklendi();
      return { default: class { static isSupported() { return true; } } };
    });
    globalThis.fetch = (async () => new Response(H265_PLAYLIST, { status: 200 })) as typeof fetch;

    const { KameraOynatici } = await import("@/components/KameraOynatici");
    ciz(() => KameraOynatici({ url: "/api/cameras/x/canli/index.m3u8", mp4: false }));

    const uyari = await screen.findByRole("alert");
    await waitFor(() => expect(uyari.textContent).toMatch(/HVC1|H265/i));
    // NE YAPACAGI yazili olmali — "acilamadi" demek yetmez.
    expect(uyari.textContent).toMatch(/mobil/i);
    expect(uyari.textContent).toMatch(/H264/);
    // Desteklenmeyen kodekte kutuphane HIC indirilmemeli.
    expect(hlsYuklendi).not.toHaveBeenCalled();
  });
});
