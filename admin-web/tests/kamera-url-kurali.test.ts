// (P131) KAMERA ADRESI KURALI — SOZLESME VAKALARIYLA olculur.
//
// `contracts/kamera-url-kurali.json` mobil ve web icin ORTAK vaka
// dosyasidir. Ayni dosyayi `mobile/test/features/cameras/
// url_kurali_sozlesme_test.dart` de okur; iki uygulamadan biri ayrisirsa
// KENDI testi duser. Kural kopyalaniyor (iki dil), BEKLENTI kopyalanmiyor.
//
// P126.5'te web'de kamera YONETIMI "ikinci kopya ayrisir" gerekcesiyle
// acilmamisti. Dogru cozum kopyayi engellemek degil — cunku iki dil var —
// AYRISMAYI OLCMEKMIS.
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  adrestenTur,
  KAMERA_URL_UST_SINIR,
  anlikKareHatasi,
  oynatilabilirMi,
  restreamHatasi,
  webSayfasiMi,
  yayinUrlHatasi,
} from "@/lib/kamera-url";
import type { CameraTur } from "@/lib/types";

const KOK = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const VAKALAR = JSON.parse(
  readFileSync(resolve(KOK, "contracts/kamera-url-kurali.json"), "utf8"),
) as {
  ust_sinir: number;
  kararlar: string[];
  yayin: { url?: string; ozel?: string; tur: CameraTur; beklenen: string }[];
  anlik_kare: { url?: string; ozel?: string; beklenen: string }[];
  restream: { url?: string; ozel?: string; beklenen: string }[];
};

/** `ozel: cokUzunUret` vakasinin adresi calisma aninda uretilir — 2100
 *  karakterlik bir dizeyi JSON'a gomulemek dosyayi okunamaz yapardi. */
function adres(v: { url?: string; ozel?: string }): string {
  if (v.ozel === "cokUzunUret") return "https://e.example/" + "a".repeat(2100);
  return v.url ?? "";
}

/** `null` (hata yok) -> "gecerli"; kural cikti sozlugu ile hizalanir. */
function karar(h: string | null): string {
  return h ?? "gecerli";
}

describe("(P131) sozlesme vakalari — YAYIN adresi", () => {
  it("ust sinir sozlesmeyle AYNI", () => {
    expect(KAMERA_URL_UST_SINIR).toBe(VAKALAR.ust_sinir);
  });

  it("vaka dosyasi BOS DEGIL (olcum bosa dusmesin)", () => {
    // Dosya bir gun yanlislikla bosalirsa butun testler "gecer" ve hicbir
    // sey olculmemis olurdu.
    expect(VAKALAR.yayin.length).toBeGreaterThanOrEqual(10);
    expect(VAKALAR.anlik_kare.length).toBeGreaterThanOrEqual(4);
    expect(VAKALAR.restream.length).toBeGreaterThanOrEqual(4);
  });

  it("her vakanin beklenen karari TANIMLI bir karardir", () => {
    const hepsi = [...VAKALAR.yayin, ...VAKALAR.anlik_kare, ...VAKALAR.restream];
    for (const v of hepsi) {
      expect(VAKALAR.kararlar, JSON.stringify(v)).toContain(v.beklenen);
    }
  });

  for (const v of VAKALAR.yayin) {
    it(`${v.ozel ?? v.url} (${v.tur}) -> ${v.beklenen}`, () => {
      expect(karar(yayinUrlHatasi(adres(v), v.tur))).toBe(v.beklenen);
    });
  }
});

describe("(P131) sozlesme vakalari — ANLIK KARE", () => {
  for (const v of VAKALAR.anlik_kare) {
    it(`${v.ozel ?? (v.url || "(bos)")} -> ${v.beklenen}`, () => {
      expect(karar(anlikKareHatasi(adres(v)))).toBe(v.beklenen);
    });
  }
});

describe("(P131) sozlesme vakalari — RESTREAM", () => {
  for (const v of VAKALAR.restream) {
    it(`${v.ozel ?? (v.url || "(bos)")} -> ${v.beklenen}`, () => {
      expect(karar(restreamHatasi(adres(v)))).toBe(v.beklenen);
    });
  }
});

// (P191-ek §3) TUR ADRESTEN TURETILIR — yoneticiye "yayin turu" sorulmaz.
describe("(P191-ek) adrestenTur", () => {
  it("sema ve uzanti kurala gore cozulur", () => {
    expect(adrestenTur("rtsp://10.0.0.5:554/Streaming/Channels/101")).toBe("rtsp");
    expect(adrestenTur("RTSP://BUYUK/HARF")).toBe("rtsp");
    expect(adrestenTur("https://ornek/yayin.m3u8")).toBe("hls");
    expect(adrestenTur("https://ornek/kayit.mp4")).toBe("mp4");
    // Sorgu dizesi uzantiyi bozmaz.
    expect(adrestenTur("https://ornek/kayit.mp4?token=abc")).toBe("mp4");
    // Belirsiz http(s) -> hls (sahadaki en yaygin durum; gelismis ayardan
    // degistirilebilir).
    expect(adrestenTur("https://ornek/canli")).toBe("hls");
  });

  it("BOS ya da TANINMAYAN girdide null (mevcut secim KORUNUR)", () => {
    // Her tus vurusunda turu sifirlamak, kullanicinin yazdigi seyi
    // altindan cekmek olurdu.
    expect(adrestenTur("")).toBeNull();
    expect(adrestenTur("   ")).toBeNull();
    expect(adrestenTur("rts")).toBeNull();
    expect(adrestenTur("10.0.0.5")).toBeNull();
  });
});

describe("(P131) tekil kurallar", () => {
  it("medya uzantisi barindirici listesini YENER", () => {
    expect(webSayfasiMi("https://player.vimeo.com/a/master.m3u8")).toBe(false);
    expect(webSayfasiMi("https://player.vimeo.com/video/1")).toBe(true);
  });

  it("bozuk adres COKMEZ (web sayfasi sayilmaz)", () => {
    expect(webSayfasiMi("https://")).toBe(false);
    expect(webSayfasiMi("saçma")).toBe(false);
  });

  it("oynatilabilirlik: rtsp YALNIZ restream ile oynar (P17)", () => {
    expect(oynatilabilirMi("hls")).toBe(true);
    expect(oynatilabilirMi("mp4")).toBe(true);
    expect(oynatilabilirMi("rtsp")).toBe(false);
    expect(oynatilabilirMi("rtsp", "https://gecit/hls.m3u8")).toBe(true);
    // Bosluk dolu sayilmaz — yoksa " " bir kamerayi oynatilabilir yapardi.
    expect(oynatilabilirMi("rtsp", "   ")).toBe(false);
  });
});
