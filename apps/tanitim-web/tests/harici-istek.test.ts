import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * (P177 §0 + §9.15) "Google Fonts'a ağ bağımlılığı KURMA",
 * "Google Maps, Google Analytics, harici izleyici beacon'ı ekleme",
 * "ağ sekmesinde Google veya izleyici alan adlarına giden istek yok".
 *
 * TARAMA, ARAMA DEGIL: kaynak agacinin tamami geziliyor. Bir gun biri
 * "sadece kucuk bir analitik" eklediginde bunu insanin fark etmesini
 * beklemek yerine test dusurur.
 *
 * IZIN VERILEN adresler ACIKCA listelenir; liste kisa ve her biri
 * KULLANICININ TIKLADIGI bir baglantidir (kaynak yuklemesi degil).
 */
const IZINLI = [
  "https://app-test.yonetio.site",
  "https://test.yonetio.site",
  "https://play.google.com/store/apps/details",
  "http://api:8000",
];

const YASAKLI = [
  "fonts.googleapis.com",
  "fonts.gstatic.com",
  "google-analytics.com",
  "googletagmanager.com",
  "maps.googleapis.com",
  "connect.facebook.net",
  "cdn.jsdelivr.net",
  "unpkg.com",
  "cdnjs.cloudflare.com",
  "hotjar",
  "segment.io",
  "sentry.io",
];

function dosyalar(kok: string): string[] {
  const cikti: string[] = [];
  for (const ad of readdirSync(kok)) {
    const yol = join(kok, ad);
    if (statSync(yol).isDirectory()) cikti.push(...dosyalar(yol));
    else if (/\.(ts|tsx|css|mjs|json)$/.test(ad)) cikti.push(yol);
  }
  return cikti;
}

const KOK = new URL("../", import.meta.url).pathname;
const TARANAN = ["app", "components", "lib", "config"].flatMap((d) =>
  dosyalar(join(KOK, d)),
);

describe("dis ag bagimliligi yok", () => {
  it("taranacak dosya bulundu (tarama sessizce bos kalmasin)", () => {
    expect(TARANAN.length).toBeGreaterThan(10);
  });

  it("yasakli alan adlarindan hicbiri gecmiyor", () => {
    for (const yol of TARANAN) {
      const icerik = readFileSync(yol, "utf-8");
      for (const yasak of YASAKLI) {
        expect(
          icerik.includes(yasak),
          `${yol} icinde yasakli alan adi: ${yasak}`,
        ).toBe(false);
      }
    }
  });

  it("gecen her mutlak adres IZINLI listesinde", () => {
    for (const yol of TARANAN) {
      const icerik = readFileSync(yol, "utf-8");
      for (const adres of icerik.match(/https?:\/\/[^\s"'`)]+/g) ?? []) {
        // Yorum satirlarindaki belge adresleri (w3.org vb.) taranmaz:
        // yalniz KOD icindeki adresler onemli. Basit kural — kaynak
        // kodunda adres her zaman tirnak icinde durur ve tarama zaten
        // tirnaga kadar okuyor.
        const izinli = IZINLI.some((i) => adres.startsWith(i));
        expect(izinli, `${yol}: izin verilmeyen adres ${adres}`).toBe(true);
      }
    }
  });

  it("yazi tipi YEREL — @font-face yalniz /fonts/ altini gosterir", () => {
    const css = readFileSync(join(KOK, "app/yazi-tipi.css"), "utf-8");
    const kaynaklar = css.match(/url\(([^)]+)\)/g) ?? [];
    expect(kaynaklar.length).toBeGreaterThan(0);
    for (const k of kaynaklar) expect(k).toMatch(/url\(\/fonts\//);
  });
});
