import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

import {
  CEREZ_BOLUMLERI,
  KULLANICI_SOZLESMESI,
  KVKK_AYDINLATMA,
} from "@/lib/hukuki";

/**
 * (P177 §2) HUKUKI METIN AYRISMA KAPISI.
 *
 * `lib/hukuki.ts` panelin TR bloklarinin BIREBIR kopyasidir (gerekcesi
 * o dosyanin basliginda: iki ayri Docker yapim baglami). Kopya sessizce
 * eskiyebilir — panelde bir madde guncellenir, burasi kalir ve iki
 * yuzey FARKLI bir sozlesme gosterir.
 *
 * Bu test paneldeki kaynak dosyalari OKUYUP karsilastirir. Panel deposu
 * bulunamazsa (orn. yalniz bu paketin kopyalandigi bir ortam) test
 * ATLANIR — kirmizi degil, cunku karsilastiracak sey yoktur.
 */
const PANEL = new URL("../../../admin-web/lib/hukuki/", import.meta.url).pathname;

function trBaslıklari(dosya: string): string[] {
  const s = readFileSync(dosya, "utf-8");
  const i = s.indexOf("  tr: {");
  // TR blogu ilk sirada; sonraki dil anahtarina kadar okunur.
  const sonrasi = s.slice(i);
  const son = sonrasi.search(/\n {2}(en|ar|ru|de|fr|es): \{/);
  const blok = son > 0 ? sonrasi.slice(0, son) : sonrasi;
  return [...blok.matchAll(/baslik: "([^"]+)"/g)].map((m) => m[1]);
}

describe("hukuki metinler panelle ayrismamis", () => {
  const varMi = existsSync(`${PANEL}kosullar.ts`);

  it.skipIf(!varMi)("Kullanici Sozlesmesi bolum basliklari AYNI", () => {
    const panel = trBaslıklari(`${PANEL}kosullar.ts`);
    const bizim = [
      KULLANICI_SOZLESMESI.baslik,
      ...KULLANICI_SOZLESMESI.bolumler.map((b) => b.baslik),
    ];
    expect(bizim).toEqual(panel);
  });

  it.skipIf(!varMi)("KVKK Aydinlatma bolum basliklari AYNI", () => {
    const panel = trBaslıklari(`${PANEL}gizlilik.ts`);
    const bizim = [
      KVKK_AYDINLATMA.baslik,
      ...KVKK_AYDINLATMA.bolumler.map((b) => b.baslik),
    ];
    expect(bizim).toEqual(panel);
  });

  it("belgeler bos degil", () => {
    expect(KULLANICI_SOZLESMESI.bolumler.length).toBeGreaterThan(5);
    expect(KVKK_AYDINLATMA.bolumler.length).toBeGreaterThan(5);
  });

  it("cerez bolumu KVKK metninden turetiliyor ve bulunuyor", () => {
    // Bulunamazsa sayfa yalniz eksiklik notunu gosterirdi; sessizce bos
    // kalmasin diye burada zorlaniyor.
    expect(CEREZ_BOLUMLERI.length).toBe(1);
    expect(CEREZ_BOLUMLERI[0].baslik).toContain("Çerez");
  });
});
