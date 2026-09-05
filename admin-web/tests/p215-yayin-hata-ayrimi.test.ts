// @vitest-environment jsdom
// (P215) YAYIN HATASI: KAMERA SORUNU MU, SUNUCU YAPILANDIRMASI MI?
//
// ===========================================================================
// OLCULEN KUSUR (sahadan)
// ===========================================================================
// Prod'da `mediamtx` ile `api` FARKLI docker aglarindaydi; her canli yayin
// istegi 502 donuyordu. Kullanicinin gordugu tek metin su idi:
//     "Yayin acilamadi. Adresi ve ag erisimini kontrol edin."
// Yonetici, HICBIR SORUNU OLMAYAN kamerayi duzeltmeye calisti. Sunucu
// tanili bir mesaj DONDURUYORDU ama oynatici onu HIC OKUMUYORDU.
//
// Bu dosya iki seyi kilitler:
//   1. Sinif AYRIMI `code` uzerinden yapilir (metin uzerinden DEGIL —
//      metne bakan bir kural dil degisince sessizce kirilir),
//   2. Oynatici sunucunun TANILI mesajini gercekten gosterir ve sunucu
//      kaynakliysa "kamerayi kurcalama" cumlesini EKLER.
import { screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { hataSinifi, yayinHatasiniCoz } from "@/lib/kamera-hata";

import { ciz } from "./yardimci";

// Backend ile istemci AYNI kod dizesini bilmek zorunda; ayrismalari
// SESSIZDIR (hicbir sey patlamaz, yalnizca ayrim calismaz olur ve
// kullanici yine yanlis yere bakar). Tek kaynak: backend sabiti.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

afterEach(() => vi.restoreAllMocks());

describe("(P215) backend ile istemci AYNI kodu biliyor", () => {
  it("`SUNUCU_YAPILANDIRMA` sabiti istemcideki kumeyle ORTUSUYOR", () => {
    const backend = readFileSync(
      resolve(__dirname, "../../backend/app/routers/cameras.py"), "utf8");
    const m = backend.match(/^SUNUCU_YAPILANDIRMA = "([a-z_]+)"$/m);
    expect(m, "backend sabiti bulunamadi — ad degistiyse burasi da degismeli")
      .not.toBeNull();
    const kod = m![1];
    // Istemci TAM BU kodu sunucu sinifina koymali.
    expect(hataSinifi(kod)).toBe("sunucu");
    // Ve backend'in gecit hatalarinda gercekten BU sabiti kullandigini
    // dogrula: sabit tanimlanip kullanilmazsa ayrim yine calismazdi.
    expect(backend).toContain("APIError(502, SUNUCU_YAPILANDIRMA");
  });
});

describe("(P215) hata sinifi KODDAN turer", () => {
  it("`server_config` SUNUCU, digerleri KAMERA", () => {
    expect(hataSinifi("server_config")).toBe("sunucu");
    expect(hataSinifi("bad_gateway")).toBe("kamera");
    expect(hataSinifi("not_found")).toBe("kamera");
    // Bilinmeyen/eksik kodda KAMERA'ya dusmek bilincli: "sunucu sorunu"
    // demek, gercekten kamerasi bozuk olan kullaniciyi beklemeye iterdi.
    expect(hataSinifi(null)).toBe("kamera");
    expect(hataSinifi(undefined)).toBe("kamera");
  });

  it("SUNUCUNUN TANILI mesajini govdeden OKUR", async () => {
    globalThis.fetch = (async () =>
      new Response(
        JSON.stringify({
          error: { code: "server_config", message: "Yayın geçidine ulaşılamıyor." },
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      )) as typeof fetch;
    expect(await yayinHatasiniCoz("/api/cameras/x/canli/index.m3u8")).toEqual({
      sinif: "sunucu",
      mesaj: "Yayın geçidine ulaşılamıyor.",
    });
  });

  it("YANIT BASARILIYSA susar (gecici hata oynatmayi bozmasin)", async () => {
    globalThis.fetch = (async () => new Response("#EXTM3U", { status: 200 })) as typeof fetch;
    expect(await yayinHatasiniCoz("/x")).toBeNull();
  });

  it("TESHIS DENEMESI COKERSE oynatmayi bozmaz", async () => {
    globalThis.fetch = (async () => {
      throw new Error("ağ yok");
    }) as typeof fetch;
    expect(await yayinHatasiniCoz("/x")).toBeNull();
  });
});

describe("(P215) oynatici — kullanicinin GORDUGU sey", () => {
  async function hlsHatasiUret(kod: string, mesaj: string) {
    // hls.js TAKLIT EDILIR ama SINIRINDA: gercek bilesen gercek `fetch`
    // ile sunucuya sorar. Olculen sey tam olarak o adim.
    vi.doMock("hls.js", () => {
      class SahteHls {
        static isSupported() { return true; }
        static Events = { ERROR: "hlsError" };
        private isleyici: ((o: string, v: { fatal: boolean }) => void) | null = null;
        loadSource() {}
        attachMedia() {}
        destroy() {}
        on(_olay: string, f: (o: string, v: { fatal: boolean }) => void) {
          this.isleyici = f;
          // Yukleme biter bitmez OLUMCUL hata: sahadaki 502 senaryosu.
          setTimeout(() => this.isleyici?.("hlsError", { fatal: true }), 0);
        }
      }
      return { default: SahteHls };
    });
    globalThis.fetch = (async () =>
      new Response(JSON.stringify({ error: { code: kod, message: mesaj } }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      })) as typeof fetch;
    const { KameraOynatici: Bilesen } = await import("@/components/KameraOynatici");
    ciz(() => Bilesen({ url: "/api/cameras/x/canli/index.m3u8", mp4: false }));
  }

  it("SUNUCU hatasinda tanili mesaj + 'kamerayi kurcalama' cumlesi", async () => {
    await hlsHatasiUret("server_config", "Yayın geçidine ulaşılamıyor.");
    const uyari = await screen.findByRole("alert");
    await waitFor(() =>
      expect(uyari.textContent).toContain("Yayın geçidine ulaşılamıyor."),
    );
    expect(uyari.getAttribute("data-hata-sinifi")).toBe("sunucu");
    expect(uyari.textContent).toMatch(/sunucu yapılandırma/i);
    expect(uyari.textContent).toMatch(/değiştirmeyin/i);
  });

  it("KAMERA hatasinda o cumle CIKMAZ (yoksa her hatada cikardi)", async () => {
    await hlsHatasiUret("bad_gateway", "Kameraya ulaşılamıyor.");
    const uyari = await screen.findByRole("alert");
    await waitFor(() =>
      expect(uyari.textContent).toContain("Kameraya ulaşılamıyor."),
    );
    expect(uyari.getAttribute("data-hata-sinifi")).toBe("kamera");
    expect(uyari.textContent).not.toMatch(/sunucu yapılandırma/i);
  });
});
