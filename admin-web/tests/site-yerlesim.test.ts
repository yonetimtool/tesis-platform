// (P161) SITE YERLESIMI — sahnenin GEOMETRI KURALLARI.
//
// Sahne dosyasi jsdom'da calismaz (WebGL yok). Bu yuzden olcek, yerlesim
// ve "veri yoksa ne olur" kurallari `three`den bagimsiz bir modulde
// duruyor ve BURADA olculuyor. Brief'in dogrulanabilir maddeleri:
//
//   * "Olcek gercekci olacak, veriden gelecek — model sabit yazilmayacak"
//   * "Veri yoksa makul bir varsayilan site goster, asla bos ekran"
//   * "Yuzlerce daire ayri mesh olmamali" -> her daire TEK bir ornek
//     konumu alir; sayim veriden turer (cizim tarafi `instancedMesh`).
import { describe, expect, it } from "vitest";

import {
  BLOK_ARALIGI,
  KAT_YUKSEKLIGI,
  ORNEK_ONEK,
  blokOlcusu,
  cepheNoktalari,
  katBasinaDaire,
  katSayisi,
  ornekSite,
  siteYerlesimi,
  type SahneBlogu,
  type SahneDairesi,
} from "@/components/3d/site-yerlesim";

const NORMAL = "normal" as const;

function daireler(kat: number, katBasi: number): SahneDairesi[] {
  return Array.from({ length: kat * katBasi }, (_, i) => ({
    id: `d${i}`,
    no: String(i + 1),
    kat: Math.floor(i / katBasi),
    sira: i % katBasi,
    durum: NORMAL,
  }));
}

function blok(ad: string, kat: number, katBasi: number): SahneBlogu {
  return { id: ad, ad, daireler: daireler(kat, katBasi) };
}

describe("cepheNoktalari", () => {
  it("istenen SAYIDA nokta uretir", () => {
    expect(cepheNoktalari(0, 2, 2)).toEqual([]);
    expect(cepheNoktalari(1, 2, 2)).toHaveLength(1);
    expect(cepheNoktalari(37, 2, 1.4)).toHaveLength(37);
  });

  it("noktalarin HEPSI cephenin uzerinde kalir", () => {
    const g = 2.4;
    const d = 1.6;
    for (const p of cepheNoktalari(50, g, d)) {
      // Dikdortgen cevresi: en az bir eksende tam kenarda olmali.
      const kenarda =
        Math.abs(Math.abs(p.x) - g / 2) < 1e-9 || Math.abs(Math.abs(p.z) - d / 2) < 1e-9;
      expect(kenarda).toBe(true);
      expect(Math.abs(p.x)).toBeLessThanOrEqual(g / 2 + 1e-9);
      expect(Math.abs(p.z)).toBeLessThanOrEqual(d / 2 + 1e-9);
    }
  });

  it("HICBIR IKI DAIRE ust uste binmez", () => {
    const noktalar = cepheNoktalari(24, 2.4, 1.6);
    for (let i = 0; i < noktalar.length; i++) {
      for (let j = i + 1; j < noktalar.length; j++) {
        const uzaklik = Math.hypot(noktalar[i].x - noktalar[j].x, noktalar[i].z - noktalar[j].z);
        expect(uzaklik).toBeGreaterThan(0.05);
      }
    }
  });
});

describe("olcek VERIDEN turer (brief)", () => {
  it("kat sayisi ve kat basina daire veriden okunur", () => {
    expect(katSayisi(daireler(9, 4))).toBe(9);
    expect(katBasinaDaire(daireler(9, 4))).toBe(4);
    // Daire yoksa bina yine de TEK KATLI cizilir (sifir yukseklik olmaz).
    expect(katSayisi([])).toBe(1);
  });

  it("DAHA COK KAT = DAHA YUKSEK kutle", () => {
    const alcak = blokOlcusu(blok("A", 3, 4), 0, 0);
    const yuksek = blokOlcusu(blok("B", 12, 4), 0, 0);
    expect(yuksek.yukseklik).toBeGreaterThan(alcak.yukseklik);
    expect(yuksek.yukseklik - alcak.yukseklik).toBeCloseTo(9 * KAT_YUKSEKLIGI, 6);
  });

  it("DAHA COK DAIRE = DAHA GENIS taban", () => {
    const dar = blokOlcusu(blok("A", 4, 4), 0, 0);
    const genis = blokOlcusu(blok("B", 4, 16), 0, 0);
    expect(genis.genislik).toBeGreaterThan(dar.genislik);
  });

  it("HER DAIRE TAM BIR yer alir — eksik ya da fazla yok", () => {
    const b = blok("A", 7, 5);
    const o = blokOlcusu(b, 0, 0);
    expect(o.daireYerleri).toHaveLength(35);
    const kimlikler = new Set(o.daireYerleri.map((y) => y.daire.id));
    expect(kimlikler.size).toBe(35);
  });

  it("KARARLI: ayni girdi ayni sahneyi verir", () => {
    const a = blokOlcusu(blok("A", 5, 6), 0, 0);
    const b = blokOlcusu(blok("A", 5, 6), 0, 0);
    expect(a.daireYerleri.map((y) => [y.x, y.y, y.z])).toEqual(
      b.daireYerleri.map((y) => [y.x, y.y, y.z]),
    );
  });

  it("her kat KENDI yuksekliginde durur", () => {
    const o = blokOlcusu(blok("A", 4, 3), 0, 0);
    const katlar = new Map<number, number>();
    for (const y of o.daireYerleri) katlar.set(y.daire.kat, y.y);
    const sirali = [...katlar.entries()].sort((x, z) => x[0] - z[0]);
    for (let i = 1; i < sirali.length; i++) {
      expect(sirali[i][1] - sirali[i - 1][1]).toBeCloseTo(KAT_YUKSEKLIGI, 6);
    }
  });
});

describe("siteYerlesimi", () => {
  it("BLOKLAR BIRBIRINE GIRMEZ", () => {
    const y = siteYerlesimi([blok("A", 4, 4), blok("B", 10, 12), blok("C", 6, 8), blok("D", 3, 5)]);
    for (let i = 0; i < y.bloklar.length; i++) {
      for (let j = i + 1; j < y.bloklar.length; j++) {
        const a = y.bloklar[i];
        const b = y.bloklar[j];
        const dx = Math.abs(a.merkezX - b.merkezX);
        const dz = Math.abs(a.merkezZ - b.merkezZ);
        const gerekliX = (a.genislik + b.genislik) / 2;
        const gerekliZ = (a.derinlik + b.derinlik) / 2;
        // Bir eksende yeterli aciklik olmasi yeter (izgara duzeni).
        expect(dx > gerekliX || dz > gerekliZ).toBe(true);
      }
    }
  });

  it("PLATFORM butun bloklari icine alir", () => {
    const y = siteYerlesimi([blok("A", 4, 4), blok("B", 10, 12), blok("C", 6, 8)]);
    for (const b of y.bloklar) {
      const kose = Math.hypot(
        Math.abs(b.merkezX) + b.genislik / 2,
        Math.abs(b.merkezZ) + b.derinlik / 2,
      );
      expect(kose).toBeLessThan(y.yaricap);
    }
  });

  it("tek blokta bile aralik korunur (yaricap kutleden buyuk)", () => {
    const y = siteYerlesimi([blok("A", 8, 6)]);
    expect(y.yaricap).toBeGreaterThan(y.bloklar[0].genislik / 2 + BLOK_ARALIGI / 2);
  });
});

describe("veri yoksa BOS EKRAN YOK (brief)", () => {
  it("bos girdi ornek siteyi kullanabilsin diye ornekSite doludur", () => {
    const o = ornekSite();
    expect(o.length).toBeGreaterThan(1);
    for (const b of o) {
      expect(b.daireler.length).toBeGreaterThan(0);
      // ORNEK OLDUGU KIMLIKTEN ANLASILIR: sahne bunlari tiklanmaz yapar,
      // yoksa kullanici olmayan bir bloga acilim yapardi.
      expect(b.id.startsWith(ORNEK_ONEK)).toBe(true);
    }
  });

  it("bos site yerlesimi CIZILEBILIR bir yaricap verir", () => {
    const y = siteYerlesimi([]);
    expect(y.bloklar).toEqual([]);
    expect(y.yaricap).toBeGreaterThan(0);
  });
});
